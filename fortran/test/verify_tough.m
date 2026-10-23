function verify_tough()
% Verify repeatability, callbacks, copied data and all injection branches.
    module = tough_mod();
    base = struct('name', 'QUADRATIC', 'x0', [1; 2], ...
        'lb', [-2; -inf], 'ub', [3; inf], 'Aineq', [1, 2], 'bineq', 4, ...
        'Aeq', [2, 1], 'beq', 5, 'objective', @(x) sum(x.^2), ...
        'nonlcon', @quadratic_constraints);
    rng(7, 'twister');
    state = rng;
    variants = module.transform_problems(base);
    assert_stream_unchanged(state);
    repeated = module.transform_problems(base);
    assert(numel(variants) == 10);
    assert(numel(unique(string({variants.name}))) == 10);
    for i = 1:10
        for field = {'name', 'x0', 'lb', 'ub', 'Aineq', 'bineq', 'Aeq', 'beq'}
            assert(isequaln(variants(i).(field{1}), repeated(i).(field{1})));
        end
        assert(isequal(size(variants(i).x0), [2, 1]));
        assert(isequal(size(variants(i).Aineq), [1, 2]));
        assert(isequal(size(variants(i).Aeq), [1, 2]));
        [cub, ceq] = variants(i).nonlcon([0; 0]);
        assert(isequal(size(cub), [2, 1]) && isequal(size(ceq), [1, 1]));
        first = evaluate(variants(i), [0.5; 1]);
        evaluate(variants(mod(i, 10)+1), [3; 4]);
        assert(isequaln(first, evaluate(variants(i), [0.5; 1])));
        assert(isequaln(first, evaluate(repeated(i), [0.5; 1])));
        assert_stream_unchanged(state);
    end
    assert(isequal(base.x0, [1; 2]));
    assert(isequal(base.Aineq, [1, 2]) && isequal(base.bineq, 4));
    assert(isinf(variants(1).lb(2)) && isinf(variants(1).ub(2)));
    assert(~isequaln(variants(1).Aineq, base.Aineq));
    assert(~isequaln(variants(1).Aeq, base.Aeq));
    empty = module.transform_problems(base([]));
    assert(isempty(empty));
    empty_base = base;
    empty_base.Aineq = zeros(0, 2); empty_base.bineq = zeros(0, 1);
    empty_base.Aeq = zeros(0, 2); empty_base.beq = zeros(0, 1);
    empty_base.nonlcon = [];
    p = module.make_tough_problem(empty_base, 123);
    assert(isequal(size(p.Aineq), [0, 2]) && isequal(size(p.Aeq), [0, 2]));
    assert(isempty(p.nonlcon));
    for bounds = { {'lb'}, {'ub'}, {'lb', 'ub'} }
        unbounded = empty_base;
        for field = bounds{1}
            unbounded.(field{1}) = [];
        end
        p = module.make_tough_problem(unbounded, 123);
        for field = bounds{1}
            assert(isequal(p.(field{1}), []));
        end
        assert(isequal(size(p.x0), size(base.x0)));
    end
    branches = false(1, 5);
    fixed = false; bad_linear = false;
    for seed = 1:200
        p = module.make_tough_problem(base, seed);
        fixed = fixed || p.lb(1) == p.ub(1);
        bad_linear = bad_linear || any(~isfinite([p.Aineq(:); p.bineq(:); p.Aeq(:); p.beq(:)]));
        result = evaluate(p, [1; 2]);
        if result.failed
            branches(1) = true;
        elseif isnan(result.value)
            branches(2) = true;
        elseif isinf(result.value)
            branches(3) = true;
        elseif result.value == -1e30
            branches(4) = true;
        else
            branches(5) = true;
        end
        assert_stream_unchanged(state);
    end
    assert(all(branches) && fixed && bad_linear);
    constant = base;
    constant.objective = @(x) 1;
    p = module.make_tough_problem(constant, 123);
    points = [0, 1, 0, 0.5; 0, 0, 1, -0.25];
    results = cell(1, size(points, 2));
    for i = 1:size(points, 2)
        results{i} = evaluate(p, points(:, i));
    end
    assert(any(cellfun(@(value) ~isequaln(value, results{1}), results(2:end))));
    for i = size(points, 2):-1:1
        assert(isequaln(results{i}, evaluate(p, points(:, i))));
        [cineq, ceq] = p.nonlcon(points(:, i));
        p.nonlcon(points(:, mod(i, size(points, 2)) + 1));
        [repeated_cineq, repeated_ceq] = p.nonlcon(points(:, i));
        assert(isequaln(cineq, repeated_cineq) && isequaln(ceq, repeated_ceq));
    end
    assert_stream_unchanged(state);
    fprintf('Tough repeatability, shapes, callback independence and injection branches passed.\n');
end

function result = evaluate(p, x)
    result = struct('failed', false, 'value', NaN);
    try
        result.value = p.objective(x);
    catch exception
        assert(contains(exception.message, 'Injected tough-problem evaluation failure.'));
        result.failed = true;
    end
end

function assert_stream_unchanged(state)
    current = rng;
    assert(strcmp(state.Type, current.Type) && isequal(state.State, current.State));
end

function [cineq, ceq] = quadratic_constraints(x)
    cineq = [x(1)-1; x(2)-2];
    ceq = x(1)+x(2)-3;
end
