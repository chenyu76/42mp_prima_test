function verify_matcutest_reference()
% Compare stored problems with MatCUTEst at multiple evaluation points.
    started = tic;
    library = matcutest_mod();
    problems = library.get_matcutest_problems(1, 5);
    fprintf('Loaded %d problems in %.3f s.\n', numel(problems), toc(started));
    directory = pwd;
    for i = 1:numel(problems)
        p = problems(i);
        reference = macup(p.name);
        assert(isequaln(p.x0, reference.x0(:)));
        assert(isequaln(p.Aineq, reference.Aineq));
        assert(isequaln(p.Aeq, reference.Aeq));
        assert(isequaln(p.bineq, reference.bineq), 'Linear inequality RHS: %s', p.name);
        assert(isequaln(p.beq, reference.beq), 'Linear equality RHS: %s', p.name);
        assert(isequaln(p.lb, reference.lb));
        assert(isequaln(p.ub, reference.ub));
        for x = [p.x0, p.x0 + 0.01]
            assert(isequaln(p.objective(x), reference.objective(x)));
            if isempty(reference.nonlcon)
                cub = zeros(0, 1); ceq = zeros(0, 1);
            else
                [cub, ceq] = reference.nonlcon(x);
            end
            if isempty(p.nonlcon)
                assert(isempty(cub) && isempty(ceq));
            else
                [actual_cub, actual_ceq] = p.nonlcon(x);
                assert(isequaln(actual_cub, cub));
                assert(isequaln(actual_ceq, ceq));
            end
            assert(strcmp(pwd, directory));
        end
    end
    % Loading again must leave previously returned callbacks usable.
    repeated = library.get_matcutest_problems(2, 2);
    rosen = problems(strcmp({problems.name}, 'ROSENBR'));
    assert(abs(rosen.objective([-1.2; 1]) - 24.2) < 1e-10);
    assert(~isempty(repeated));
    reference = macup('ROSENBR');
    x = [-1.2; 1];
    direct = @() rosen.objective(x);
    switching = @() evaluate_with_cd(reference, x);
    direct_time = timeit(direct);
    switching_time = timeit(switching);
    fprintf('Objective: direct %.3f us, directory switching %.3f us (%.1fx).\n', ...
        1e6 * direct_time, 1e6 * switching_time, switching_time / direct_time);
    fprintf('All %d problems match MatCUTEst at both evaluation points.\n', numel(problems));
end

function value = evaluate_with_cd(source, x)
    directory = pwd;
    cleanup = onCleanup(@() cd(directory)); %#ok<NASGU>
    cd(source.mexdir);
    value = source.objective(x);
end
