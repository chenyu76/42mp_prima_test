function count = verify_matcutest_runtime(min_dimension, max_dimension)
% Inputs: inclusive dimension bounds. Output: number of verified problems.
    started = tic;
    names = secup(struct('mindim', min_dimension, 'maxdim', max_dimension, ...
        'is_feasibility', false));
    fprintf('Selected %d problems in %.3f s.\n', numel(names), toc(started));
    failures = {};
    problems = cell(size(names));
    for i = 1:numel(names)
        try
            p = macup(names{i});
            n = numel(p.x0);
            assert(min_dimension <= n && n <= max_dimension, ...
                'Selected dimension differs from loaded dimension: %d.', n);
            value = p.objective(p.x0);
            if strcmp(p.name, 'LIN')
                fprintf('LIN: known nonfinite objective at x0 = %g.\n', value);
            else
                assert(isfinite(value), 'Nonfinite objective at x0.');
            end
            assert(isempty(p.lb) || numel(p.lb) == n);
            assert(isempty(p.ub) || numel(p.ub) == n);
            assert(isempty(p.Aineq) || size(p.Aineq, 2) == n);
            assert(isempty(p.Aeq) || size(p.Aeq, 2) == n);
            if ~isempty(p.nonlcon)
                [cub, ceq] = p.nonlcon(p.x0);
                assert(all(isfinite([cub(:); ceq(:)])), ...
                    'Nonfinite nonlinear constraints at x0.');
            end
            problems{i} = p;
        catch exception
            failures{end + 1} = names{i}; %#ok<AGROW>
            fprintf(2, '%s: %s\n', names{i}, getReport(exception, 'basic'));
        end
    end
    % Revisit stored handles after every problem has been loaded.
    for i = 1:numel(problems)
        p = problems{i};
        if isempty(p)
            continue;
        end
        original_directory = pwd;
        cd(p.mexdir);
        value = p.objective(p.x0);
        cd(original_directory);
        assert(isequaln(value, p.f0), 'Stored objective uses the wrong problem.');
        decup(p);
    end
    count = numel(problems);
    assert(isempty(failures), 'Some MatCUTEst problems failed verification.');
end
