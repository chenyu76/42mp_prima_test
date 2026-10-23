function differences = test(mindim, maxdim, n_jobs)
    % TEST Compare PRIMA's Fortran and MATLAB backends on tough problems.
    % Requires MatCUTEst, PRIMA, and Parallel Computing Toolbox.
    % Returns differing branches organized by problem name and solver name.
    arguments (Input)
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
        n_jobs (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        differences (1, 1) struct
    end

    % MatCUTEst changes paths and holds MEX state, requiring separate processes.
    pool = gcp('nocreate');
    if ~isempty(pool)
        assert(~isa(pool, 'parallel.ThreadPool'), 'MatCUTEst requires a process-based pool.');
        if pool.NumWorkers ~= n_jobs
            % Recreate an existing pool when the requested worker count changes.
            delete(pool);
            pool = [];
        end
    end
    if isempty(pool)
        parpool('Processes', n_jobs);
    end

    problems = load_matcutest_problems(mindim, maxdim);
    base_names = {problems.name};
    problems = tough_problems(problems);
    % Decimal points and other punctuation cannot occur in struct field names.
    names = matlab.lang.makeValidName({problems.name});
    names = matlab.lang.makeUniqueStrings(names, {}, namelengthmax);
    differences = struct();

    problem_results = cell(1, numel(problems));
    parfor (i = 1:numel(problems), n_jobs)
        % MEX function handles do not transfer initialized CUTEst state to workers.
        macup(base_names{i});
        % Reuse the same random options for all applicable solvers on this problem.
        options = random_prima_options(numel(problems(i).x0));
        problem_differences = struct();
        for solver = applicable_solvers(problems(i))
            options.solver = solver;
            fortran_record = run_problem(problems(i), options, true);
            matlab_record = run_problem(problems(i), options, false);
            child = compare_struct_trees(fortran_record, matlab_record, "Fortran", "MATLAB");
            if ~isempty(fieldnames(child))
                problem_differences.(solver) = child;
            end
        end
        problem_results{i} = problem_differences;
    end
    % Merge sliced results in input order, independent of worker completion order.
    for i = 1:numel(problems)
        if ~isempty(fieldnames(problem_results{i}))
            differences.(names{i}) = problem_results{i};
        end
    end
end

function solvers = applicable_solvers(problem)
    arguments (Input)
        problem (1, 1) struct
    end
    arguments (Output)
        solvers (1, :) string
    end

    % Use the supplied constraints, before PRIMA removes or reduces any of them.
    if ~isempty(problem.nonlcon)
        solvers = "cobyla";
    elseif ~isempty(problem.Aineq) || ~isempty(problem.Aeq)
        solvers = ["lincoa", "cobyla"];
    elseif any(problem.lb ~= -Inf, 'all') || any(problem.ub ~= Inf, 'all')
        solvers = ["bobyqa", "lincoa", "cobyla"];
    else
        solvers = ["uobyqa", "newuoa", "bobyqa", "lincoa", "cobyla"];
    end
end

function record = run_problem(source, options, use_fortran)
    arguments (Input)
        source (1, 1) struct
        options (1, 1) struct
        use_fortran (1, 1) logical
    end
    arguments (Output)
        record (1, 1) struct
    end

    wrapped = RecordedProblem(source);
    problem = wrapped.get_problem();
    % Keep the name in the record, but pass only PRIMA's recognized fields.
    problem = rmfield(problem, 'name');
    problem.options = options;
    problem.options.fortran = use_fortran;
    result = struct('x', [], 'fx', [], 'exitflag', [], 'output', struct());
    failure = struct('identifier', "", 'message', "");
    try
        % Both backends receive the same explicitly selected solver.
        [result.x, result.fx, result.exitflag, result.output] = prima(problem);
    catch exception
        failure.identifier = string(exception.identifier);
        failure.message = string(exception.message);
    end
    % Collect after the call, including evaluations made before an exception.
    record = wrapped.get_record();
    record.options = options;
    record.result = result;
    record.error = failure;
end
