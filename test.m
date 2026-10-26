function [differences, problem_list] = test(mindim, maxdim, n_jobs, run_seed)
    % TEST Compare PRIMA's Fortran and MATLAB backends on tough problems.
    % Requires MatCUTEst, PRIMA, and Parallel Computing Toolbox.
    % Returns differing branches organized by problem name and solver name.
    % problem_list retains each problem, per-solver options, and replay seeds.
    arguments (Input)
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
        n_jobs (1, 1) double {mustBeInteger, mustBePositive}
        run_seed (1, 1) double {mustBeInteger, mustBeNonnegative, mustBeLessThan(run_seed, 4294967296)} = 0
    end
    arguments (Output)
        differences (1, 1) struct
        problem_list (1, :) struct
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
    tough_seeds = zeros(1, numel(problems));
    for i = 1:numel(problems)
        tough_seeds(i) = derive_seed(run_seed, string(base_names{i}) + ":tough");
    end
    problems = tough_problems(problems, tough_seeds);
    % Decimal points and other punctuation cannot occur in struct field names.
    names = matlab.lang.makeValidName({problems.name});
    names = matlab.lang.makeUniqueStrings(names, {}, namelengthmax);
    differences = struct();
    problem_entries = cell(1, numel(problems));

    problem_results = cell(1, numel(problems));
    parfor (i = 1:numel(problems), n_jobs)
        % MEX function handles do not transfer initialized CUTEst state to workers.
        macup(base_names{i});
        % Use the same seed to generate solver-specific options on this problem.
        options_seed = derive_seed(run_seed, string(base_names{i}) + ":options");
        n = numel(problems(i).x0);
        solvers = applicable_solvers(problems(i));
        solver_seeds = struct();
        solver_options = struct();
        solver_scenarios = struct();
        problem_differences = struct();
        for solver = solvers

            [options, scenario] = random_prima_options(n, solver, options_seed, problems(i).f0);
            solver_scenarios.(solver) = scenario;

            solver_seed = derive_seed(run_seed, string(base_names{i}) + ":solver:" + solver);
            solver_seeds.(solver) = solver_seed;
            solver_options.(solver) = options;

            % run problem
            fortran_record = run_problem(problems(i), options, true, solver_seed);
            matlab_record = run_problem(problems(i), options, false, solver_seed);

            child = compare_struct_trees(fortran_record, matlab_record, "Fortran", "MATLAB");
            if ~isempty(fieldnames(child))
                problem_differences.(solver) = child;
            end
        end
        % Keep actual inputs for inspection, and seeds for replaying each stage.
        problem_entries{i} = struct('name', problems(i).name, 'base_name', base_names{i}, ...
                                    'problem', problems(i), 'run_seed', run_seed, 'tough_seed', tough_seeds(i), ...
                                    'options_seed', options_seed, 'scenario', solver_scenarios, ...
                                    'options', solver_options, 'solver_seeds', solver_seeds);
        problem_results{i} = problem_differences;
        fprintf('\nCompleted problem %d/%d: %s\n', i, numel(problems), base_names{i});
    end
    % Merge sliced results in input order, independent of worker completion order.
    if isempty(problem_entries)
        % Empty cell concatenation produces double []; the output must be a struct row.
        problem_list = repmat(struct(), 1, 0);
    else
        problem_list = [problem_entries{:}];
    end
    for i = 1:numel(problems)
        if ~isempty(fieldnames(problem_results{i}))
            differences.(names{i}) = problem_results{i};
        end
    end
end

function seed = derive_seed(run_seed, key)
    arguments (Input)
        run_seed (1, 1) double
        key (1, 1) string
    end
    arguments (Output)
        seed (1, 1) double
    end

    % Stable text-based seeds do not depend on worker count or problem order.
    seed = run_seed;
    bytes = unicode2native(key, 'UTF-8');
    for value = bytes
        % Products remain below 2^53, preserving exact integer arithmetic in double.
        seed = mod(1664525 * seed + double(value) + 1013904223, 2^32);
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

function record = run_problem(source, options, use_fortran, solver_seed)
    arguments (Input)
        source (1, 1) struct
        options (1, 1) struct
        use_fortran (1, 1) logical
        solver_seed (1, 1) double
    end
    arguments (Output)
        record (1, 1) struct
    end

    % Give both backends identical randomness and isolate later solver runs.
    rng_cleanup = seed_rng(solver_seed); %#ok<NASGU>
    wrapped = RecordedProblem(source);
    problem = wrapped.get_problem();
    % Keep metadata in the record, but pass only PRIMA's recognized fields.
    problem = rmfield(problem, {'name', 'f0'});
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
