function differences = test(mindim, maxdim)
    %TEST Compare PRIMA's Fortran and MATLAB backends on tough problems.
    % Requires MatCUTEst and PRIMA to be available in the prepared environment.
    % Returns only differing problems, keyed by MATLAB-valid problem names.
    arguments (Input)
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        differences (1, 1) struct
    end

    problems = load_matcutest_problems(mindim, maxdim);
    problems = tough_problems(problems);
    % Decimal points and other punctuation cannot occur in struct field names.
    names = matlab.lang.makeValidName({problems.name});
    names = matlab.lang.makeUniqueStrings(names, {}, namelengthmax);
    differences = struct();
    for i = 1:numel(problems)
        % Generate once so backend choice is the only intentional input difference.
        options = random_prima_options(numel(problems(i).x0));
        fortran_record = run_problem(problems(i), options, true);
        matlab_record = run_problem(problems(i), options, false);
        child = compare_struct_trees(fortran_record, matlab_record, "Fortran", "MATLAB");
        if ~isempty(fieldnames(child))
            differences.(names{i}) = child;
        end
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
        % PRIMA selects a suitable algorithm from the problem's constraint type.
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
