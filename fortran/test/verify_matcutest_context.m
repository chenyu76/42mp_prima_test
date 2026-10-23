function verify_matcutest_context()
% Interleaved callbacks must retain their problem after unrelated loads.
    names = ["HS71"; "HS10"];
    problems = [load_matcutest_problem(names, 1); load_matcutest_problem(names, 2)];
    expected = cell(2, 2);
    for i = 1:2
        reference = macup(names(i));
        [expected{i, 1}, expected{i, 2}] = reference.nonlcon(reference.x0);
    end
    directory = pwd;
    for run = 1:3
        macup('ROSENBR');
        for i = 1:2
            p = problems(i);
            [cineq, ceq] = p.nonlcon(p.x0);
            assert(isequaln(cineq, expected{i, 1}));
            assert(isequaln(ceq, expected{i, 2}));
        end
    end
    assert(strcmp(pwd, directory));
    library = matcutest_mod();
    assert(isempty(library.get_matcutest_problems(1000000000, 1000000000)));
    fprintf('Interleaved nonlinear callbacks and empty selection passed.\n');
end
