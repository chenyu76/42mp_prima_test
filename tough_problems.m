function problems = tough_problems(base_problems)
    % TOUGH_PROBLEMS Make one tough PRIMA problem per input problem.
    % Uses noise level 0.2, fixed variables, invalid linear data, and evaluation
    % failures. Each callback repeats its perturbation at the same input point.
    arguments (Input)
        base_problems (1, :) struct
    end
    arguments (Output)
        problems (1, :) struct
    end

    problems = base_problems;
    for i = 1:numel(base_problems)
        problems(i) = perturb_problem(base_problems(i), randi(2^32 - 1));
    end
end

function problem = perturb_problem(base, seed)
    arguments
        base (1, 1) struct
        seed (1, 1) double
    end
    problem = base;
    noise_level = 0.2;
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
    arguments
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
    arguments
        objective (1, 1) function_handle
        x double
        seed (1, 1) double
    end
    value = contaminate(objective(x), x, seed, 0);
end

function [cineq, ceq] = perturb_nonlcon(nonlcon, x, seed)
    arguments
        nonlcon (1, 1) function_handle
        x double
        seed (1, 1) double
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
    arguments
        value (1, 1) double
        x double
        seed (1, 1) double
        salt (1, 1) double
    end
    % Restore the caller's random stream even when evaluation throws.
    original_rng = rng();
    cleanup = onCleanup(@() rng(original_rng));
    % Derive repeatable noise from the point; salt separates output components.
    point_hex = num2hex(x(:));
    local_seed = mod(seed + salt + sum(double(point_hex(:))), 2^32);
    rng(local_seed, 'twister');
    value = value * (1 + 0.2 * randn());
    r = 2 * rand() - 1;
    if r > 0.9
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
