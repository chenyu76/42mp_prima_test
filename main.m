function problems = main(matcutest_paths, mindim, maxdim)
    % MAIN Entry point for the rewritten bit-consistency test.
    % Returns a row struct array of tough problems in PRIMA input format.
    arguments (Input)
        matcutest_paths (1, :) string
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        problems (1, :) struct
    end

    prepare_environment(matcutest_paths);
    problems = load_matcutest_problems(mindim, maxdim);
    problems = tough_problems(problems);
end
