function prepare_environment(matcutest_paths)
    % PREPARE_ENVIRONMENT Add the supplied MatCUTEst directories to the path.
    % Paths may be relative to the project directory when called from there.
    arguments
        matcutest_paths (1, :) string
    end

    for directory = matcutest_paths
        addpath(char(directory));
    end
end
