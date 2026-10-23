function p = load_matcutest_problem(names, index)
    arguments
        names (:, 1) string
        index (1, 1) double
    end
    source = macup(names(index));
    schema = problem_mod();
    p = schema.problem_default();
    fields = fieldnames(p);
    for i = 1:numel(fields)
        p.(fields{i}) = source.(fields{i});
    end
    entry = str2func('mcutest');
    p.objective = @(x) entry('obj', x(:));
    if ~isempty(source.nonlcon)
        nonlcon = source.nonlcon;
        mex_directory = source.mexdir;
        p.nonlcon = @(x) evaluate_constraints(nonlcon, entry, mex_directory, x);
    end
end

function [cineq, ceq] = evaluate_constraints(nonlcon, entry, mex_directory, x)
    % MatCUTEst resolves the shared MEX name; select it only when changing problems.
    if ~isequal(str2func('mcutest'), entry)
        addpath(mex_directory);
    end
    [cineq, ceq] = nonlcon(x(:));
end
