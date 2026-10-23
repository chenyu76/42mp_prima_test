function verify_prima_arguments(cobyla_problem)
% Check the problem fields against PRIMA's positional solver interfaces.
    arguments
        cobyla_problem (1, 1) string = "HS10"
    end
    library = matcutest_mod();
    problems = library.get_matcutest_problems(1, 5);
    options = struct('fortran', false, 'quiet', true, 'maxfun', 300);
    p = select_problem(problems, 'ROSENBR');
    for solver = {@uobyqa, @newuoa}
        [x, value, status] = solver{1}(p.objective, p.x0, options);
        assert(numel(x) == numel(p.x0) && isfinite(value) && isscalar(status));
        assert(abs(value - p.objective(x)) < 1e-10 && value < 1e-6);
    end
    p = select_problem(problems, 'HS1');
    [x, value, status] = bobyqa(p.objective, p.x0, p.lb, p.ub, options);
    assert(isfinite(value) && isscalar(status));
    assert(abs(value - p.objective(x)) < 1e-10);
    assert(all(x >= p.lb - 1e-6) && all(x <= p.ub + 1e-6));
    p = select_problem(problems, 'HS21');
    [x, value, status] = lincoa(p.objective, p.x0, p.Aineq, p.bineq, ...
        p.Aeq, p.beq, p.lb, p.ub, options);
    assert(isfinite(value) && isscalar(status));
    assert(abs(value - p.objective(x)) < 1e-10);
    assert(all(p.Aineq * x <= p.bineq + 1e-5));
    assert(all(abs(p.Aeq * x - p.beq) <= 1e-5));
    p = select_problem(problems, cobyla_problem);
    [x, value, status] = cobyla(p.objective, p.x0, p.Aineq, p.bineq, ...
        p.Aeq, p.beq, p.lb, p.ub, p.nonlcon, options);
    assert(isfinite(value) && isscalar(status));
    assert(abs(value - p.objective(x)) < 1e-10);
    [cineq, ceq] = p.nonlcon(x);
    assert(all(isfinite([cineq; ceq])));
    fprintf('All five PRIMA positional solver interfaces passed.\n');
end

function p = select_problem(problems, name)
    p = problems(strcmp({problems.name}, name));
    assert(isscalar(p));
end
