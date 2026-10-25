function problems = tough_problems(base_problems, seeds)
    % TOUGH_PROBLEMS Make one tough PRIMA problem per input problem.
    % Uses noise level 0.2, fixed variables, invalid linear data, and evaluation
    % failures. Each callback repeats its perturbation at the same input point.
    % Optional seeds give one seed per problem; omitted seeds are drawn from
    % the caller's stream. Each seed controls all data and evaluation changes.
    arguments (Input)
        base_problems (1, :) struct
        seeds (1, :) double {mustBeInteger, mustBeNonnegative, mustBeLessThan(seeds, 4294967296)} = []
    end
    arguments (Output)
        problems (1, :) struct
    end

    if isempty(seeds)
        seeds = randi(2^32 - 1, 1, numel(base_problems));
    end
    assert(numel(seeds) == numel(base_problems), 'Provide one seed per problem.');
    problems = base_problems;
    for i = 1:numel(base_problems)
        problems(i) = perturb_problem(base_problems(i), seeds(i));
    end
end

function problem = perturb_problem(base, seed)
    arguments (Input)
        base (1, 1) struct
        seed (1, 1) double
    end
    arguments (Output)
        problem (1, 1) struct
    end
    rng_cleanup = seed_rng(seed); %#ok<NASGU>
    problem = base;
    noise_level = 0.2;
    problem.name = sprintf('%s_tough_noise%g_fail1_invalid1_fixed1_seed%010u', ...
                           base.name, noise_level, uint32(seed));
    problem.x0 = base.x0 + noise_level * max(1, abs(base.x0)) .* randn(size(base.x0));

    % Empty PRIMA bounds mean that every variable is unbounded on that side.
    lb = base.lb;
    ub = base.ub;
    if isempty(lb)
        lb = -Inf(size(base.x0));
    end
    if isempty(ub)
        ub = Inf(size(base.x0));
    end
    % Clip working bounds; the masks below leave infinite bounds unchanged.
    lb_work = max(-1.0e10, lb);
    ub_work = min(1.0e10, ub);
    scale = noise_level * 0.9 * min(1, max(0, ub_work - lb_work));
    finite_lb = isfinite(lb);
    finite_ub = isfinite(ub);
    lb(finite_lb) = lb_work(finite_lb) + scale(finite_lb) .* ...
        (rand(size(lb(finite_lb))) - 1);
    ub(finite_ub) = ub_work(finite_ub) + scale(finite_ub) .* ...
        (rand(size(ub(finite_ub))) - 1);
    % Fix selected variables by making their lower and upper bounds equal.
    candidates = find(isfinite(lb) & isfinite(ub));
    fixed = candidates(rand(numel(candidates), 1) < 0.2);
    choose_lower = rand(numel(fixed), 1) < 0.5;
    ub(fixed(choose_lower)) = lb(fixed(choose_lower));
    lb(fixed(~choose_lower)) = ub(fixed(~choose_lower));
    problem.lb = lb;
    problem.ub = ub;

    [problem.Aineq, problem.bineq] = perturb_linear(base.Aineq, base.bineq);
    [problem.Aeq, problem.beq] = perturb_linear(base.Aeq, base.beq);
    if ~isempty(base.objective)
        problem.objective = @(x) perturb_objective(base.objective, x, seed);
    end
    if ~isempty(base.nonlcon)
        problem.nonlcon = @(x) perturb_nonlcon(base.nonlcon, x, seed);
    end
end

function [A, b] = perturb_linear(A, b)
    arguments (Input)
        A double
        b double
    end
    arguments (Output)
        A double
        b double
    end
    if isempty(A)
        return
    end
    A = A + 0.2 * max(1, abs(A)) .* randn(size(A));
    b = b + 0.2 * max(1, abs(b)) .* randn(size(b));
    A(rand(size(A)) > 0.97) = Inf;
    A(rand(size(A)) > 0.97) = -Inf;
    A(rand(size(A)) > 0.97) = NaN;
    b(rand(size(b)) > 0.97) = Inf;
    b(rand(size(b)) > 0.97) = -Inf;
    b(rand(size(b)) > 0.97) = NaN;
end

function value = perturb_objective(objective, x, seed)
    arguments (Input)
        objective (1, 1) function_handle
        x double
        seed (1, 1) double
    end
    arguments (Output)
        value (1, 1) double
    end
    value = contaminate(objective(x), x, seed, 0);
end

function [cineq, ceq] = perturb_nonlcon(nonlcon, x, seed)
    arguments (Input)
        nonlcon (1, 1) function_handle
        x double
        seed (1, 1) double
    end
    arguments (Output)
        cineq double
        ceq double
    end
    [cineq, ceq] = nonlcon(x);
    for i = 1:numel(cineq)
        cineq(i) = contaminate(cineq(i), x, seed, 100000 + i);
    end
    for i = 1:numel(ceq)
        ceq(i) = contaminate(ceq(i), x, seed, 200000 + i);
    end
end

function value = contaminate(value, x, seed, salt)
    arguments (Input)
        value (1, 1) double
        x double
        seed (1, 1) double
        salt (1, 1) double
    end
    arguments (Output)
        value (1, 1) double
    end
    % Derive repeatable noise from the point; salt separates output components.
    point_hex = num2hex(x(:));
    local_seed = mod(seed + salt + sum(double(point_hex(:))), 2^32);
    % Evaluation noise must not consume the solver's random stream, even on errors.
    rng_cleanup = seed_rng(local_seed); %#ok<NASGU>
    value = value * (1 + 0.2 * randn());
    r = 2 * rand() - 1;
    if r > 0.99
        error('bit_consistency:ToughEvaluationFailure', ...
              'Injected tough-problem evaluation failure.');
    elseif r > 0.8
        value = NaN;
    elseif r > 0.7
        value = Inf;
    elseif r < -0.9
        value = -1.0e30;
    end
end
