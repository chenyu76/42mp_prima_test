function problems = get_matcutest_problems(min_dimension, max_dimension)
    % Inputs: inclusive dimension bounds. 
    % Output: a column array of Problem structs.
    arguments
        min_dimension (1, 1) double {mustBeInteger, mustBePositive}
        max_dimension (1, 1) double {mustBeInteger, mustBePositive}
    end
    assert(min_dimension <= max_dimension, 'Invalid dimension interval.');

    project_dir = fileparts(fileparts(mfilename('fullpath')));
    runtime_dir = fullfile(project_dir, 'python', '.venv', 'matcutest');
    addpath(fullfile(runtime_dir, 'mtools', 'src'));
    names = secup(struct('mindim', min_dimension, 'maxdim', max_dimension, ...
                         'is_feasibility', false));

    template = struct('name', '', 'n', 0, 'x0', [], 'xl', [], 'xu', [], ...
                      'aub', [], 'bub', [], 'aeq', [], 'beq', [], ...
                      'fun', [], 'cub', [], 'ceq', []);
    problems = repmat(template, numel(names), 1);
    for i = 1:numel(names)
        source = macup(names{i});
        n = numel(source.x0);
        assert(min_dimension <= n && n <= max_dimension, ...
               'Loaded dimension of %s differs from the selection.', names{i});
        p = template;
        p.name = names{i};
        p.n = n;
        p.x0 = source.x0(:);
        p.xl = source.lb(:);
        p.xu = source.ub(:);
        if isempty(p.xl)
            p.xl = -inf(n, 1);
        end
        if isempty(p.xu)
            p.xu = inf(n, 1);
        end
        p.bub = source.bineq(:);
        p.beq = source.beq(:);
        p.aub = reshape(full(source.Aineq), numel(p.bub), n);
        p.aeq = reshape(full(source.Aeq), numel(p.beq), n);
        p.fun = @(x) evaluate(source, x, 'fun');
        p.cub = @(x) evaluate(source, x, 'cub');
        p.ceq = @(x) evaluate(source, x, 'ceq');
        problems(i) = p;
    end
end

function values = evaluate(source, x, field)
    % Bind the shared CUTEst entry points to this problem for each evaluation.
    previous_dir = pwd;
    restore_directory = onCleanup(@() cd(previous_dir)); %#ok<NASGU>
    cd(source.mexdir);
    x = x(:);
    if strcmp(field, 'fun')
        values = source.objective(x);
    elseif isempty(source.nonlcon)
        values = zeros(0, 1);
    else
        [cub, ceq] = source.nonlcon(x);
        if strcmp(field, 'cub')
            values = full(cub(:));
        else
            values = full(ceq(:));
        end
    end
end
