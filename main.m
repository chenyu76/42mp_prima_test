function differences = main(prima_dir, matcutest_paths, mindim, maxdim, n_jobs)
    % MAIN Entry point for the rewritten bit-consistency test.
    % Returns the difference tree and saves results/<timestamp>/differences.json.
    arguments (Input)
        prima_dir (1, 1) string
        matcutest_paths (1, :) string
        mindim (1, 1) double {mustBeInteger, mustBePositive}
        maxdim (1, 1) double {mustBeInteger, mustBePositive}
        n_jobs (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        differences (1, 1) struct
    end

    prepare_environment(prima_dir, matcutest_paths);
    differences = test(mindim, maxdim, n_jobs);
    save_test_output(differences);
end

function save_test_output(differences)
    arguments
        differences (1, 1) struct
    end

    text = jsonencode(prepare_json_value(differences), 'PrettyPrint', true);
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    output_dir = fullfile(fileparts(mfilename('fullpath')), 'results', stamp);
    [created, message] = mkdir(output_dir);
    assert(created, 'Cannot create output directory %s: %s', output_dir, message);
    output_file = fullfile(output_dir, 'differences.json');
    file_id = fopen(output_file, 'w');
    assert(file_id >= 0, 'Cannot open output file: %s', output_file);
    cleanup = onCleanup(@() fclose(file_id));
    bytes = unicode2native([text, newline], 'UTF-8');
    written = fwrite(file_id, bytes, 'uint8');
    assert(written == numel(bytes), 'Incomplete write of test output: %s', output_file);
    fprintf('Test output saved in %s\n', output_file);
end

function encoded = prepare_json_value(value)
    % Convert only the exported copy; keep the returned difference tree intact.
    arguments (Input)
        value
    end
    arguments (Output)
        encoded
    end

    encoded = value;
    if isstruct(value)
        fields = fieldnames(value);
        for i = 1:numel(value)
            for j = 1:numel(fields)
                encoded(i).(fields{j}) = prepare_json_value(value(i).(fields{j}));
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            encoded{i} = prepare_json_value(value{i});
        end
    elseif isfloat(value) && isreal(value)
        % JSON numbers cannot represent nonfinite values or reliably retain -0.
        negative_zero = value == 0 & (1 ./ value < 0);
        if isscalar(value)
            if isnan(value)
                encoded = "NaN";
            elseif isinf(value) && value > 0
                encoded = "Inf";
            elseif isinf(value)
                encoded = "-Inf";
            elseif negative_zero
                encoded = "-0";
            end
        elseif any(~isfinite(value) | negative_zero, 'all')
            % Mixed numeric/string arrays need cells, retaining element positions.
            encoded = prepare_json_value(num2cell(full(value)));
        end
    elseif isa(value, 'function_handle')
        encoded = func2str(value);
    end
end
