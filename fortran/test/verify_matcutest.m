function verify_matcutest()
% Verify that stored callbacks still select their problem after all loads.
    library = matcutest_mod();
    problems = library.get_matcutest_problems(1, 5);
    assert(~isempty(problems));
    expected_fields = {'name', 'objective', 'x0', 'lb', 'ub', ...
        'Aineq', 'bineq', 'Aeq', 'beq', 'nonlcon'};
    assert(isequal(sort(fieldnames(problems)), sort(expected_fields(:))));
    directory = pwd;
    for i = 1:numel(problems)
        p = problems(i);
        n = numel(p.x0);
        assert(1 <= n && n <= 5);
        assert(isequal(size(p.x0), [n, 1]));
        assert(isempty(p.lb) || isequal(size(p.lb), [n, 1]));
        assert(isempty(p.ub) || isequal(size(p.ub), [n, 1]));
        assert(isempty(p.Aineq) || isequal(size(p.Aineq), [numel(p.bineq), n]));
        assert(isempty(p.Aeq) || isequal(size(p.Aeq), [numel(p.beq), n]));
        value = p.objective(p.x0);
        if strcmp(p.name, 'LIN')
            assert(isnan(value));
        else
            assert(isscalar(value) && isfinite(value));
        end
        if ~isempty(p.nonlcon)
            [cub, ceq] = p.nonlcon(p.x0);
            assert((isempty(cub) || size(cub, 2) == 1) && all(isfinite(cub)));
            assert((isempty(ceq) || size(ceq, 2) == 1) && all(isfinite(ceq)));
        end
        assert(strcmp(pwd, directory));
    end
    p = problems(strcmp({problems.name}, 'ROSENBR'));
    assert(numel(p) == 1);
    assert(abs(p.objective([-1.2; 1]) - 24.2) < 1e-10);
    assert(p.objective([1; 1]) == 0);
    assert(isempty(p.nonlcon));
    fprintf('Verified %d MatCUTEst problems and stored callbacks.\n', numel(problems));
end
