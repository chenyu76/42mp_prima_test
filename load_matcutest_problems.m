function problems = load_matcutest_problems(mindim, maxdim)
    % LOAD_MATCUTEST_PROBLEMS Load all constraint types in PRIMA struct format.
    % Requires the environment to have been prepared before calling.
    arguments (Input)
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        problems (1, :) struct
    end

    assert(mindim <= maxdim, 'mindim must not exceed maxdim.');
    names = secup(struct('mindim', mindim, 'maxdim', maxdim, 'type', 'ubln'));
    template = struct('objective', [], 'x0', [], 'Aineq', [], 'bineq', [], ...
                      'Aeq', [], 'beq', [], 'lb', [], 'ub', [], 'nonlcon', []);
    problems = repmat(template, 1, numel(names));

    for i = 1:numel(names)
        source = macup(names{i});
        % Bind the objective to this problem's MEX before another load.
        entry = str2func('mcutest');
        problems(i).objective = @(x) entry('obj', x(:));
        problems(i).x0 = source.x0;
        problems(i).Aineq = source.Aineq;
        problems(i).bineq = source.bineq;
        problems(i).Aeq = source.Aeq;
        problems(i).beq = source.beq;
        problems(i).lb = source.lb;
        problems(i).ub = source.ub;
        if ~isempty(source.nonlcon)
            nonlcon = source.nonlcon;
            mex_directory = source.mexdir;
            problems(i).nonlcon = @(x) evaluate_constraints(nonlcon, entry, mex_directory, x);
        end
    end
end

function [cineq, ceq] = evaluate_constraints(nonlcon, entry, mex_directory, x)
    arguments (Input)
        nonlcon (1, 1) function_handle
        entry (1, 1) function_handle
        mex_directory (1, :) char
        x double
    end
    arguments (Output)
        cineq double
        ceq double
    end

    % MatCUTEst's constraint callback resolves the shared MEX name at runtime.
    if ~isequal(str2func('mcutest'), entry)
        addpath(mex_directory);
    end
    [cineq, ceq] = nonlcon(x(:));
end
