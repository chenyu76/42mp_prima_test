function verify_tough_matcutest()
% Verify every selected problem's variants and retained MatCUTEst callbacks.
    library = matcutest_mod();
    problems = library.get_matcutest_problems(1, 5);
    module = tough_mod();
    transformed = module.transform_problems(problems);
    assert(numel(transformed) == 10 * numel(problems));
    for i = 1:numel(transformed)
        p = transformed(i);
        base = problems(ceil(i / 10));
        for field = {'x0', 'lb', 'ub', 'Aineq', 'Aeq', 'bineq', 'beq'}
            assert(isequal(size(p.(field{1})), size(base.(field{1}))));
        end
    end
    for i = 1:numel(problems)
        p = transformed(10 * (i - 1) + 1);
        x = problems(i).x0;
        first = evaluate(p, x);
        if isempty(problems(i).nonlcon)
            assert(isempty(p.nonlcon));
        else
            [cub, ceq] = p.nonlcon(x);
            [base_cub, base_ceq] = problems(i).nonlcon(x);
            assert(isequal(size(cub), size(base_cub)));
            assert(isequal(size(ceq), size(base_ceq)));
        end
        assert(isequaln(first, evaluate(p, x)));
    end
    fprintf('Verified %d variants of %d MatCUTEst problems.\n', numel(transformed), numel(problems));
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
