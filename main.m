function [differences, problem_list] = main(prima_dir, matcutest_paths, mindim, maxdim, n_jobs, run_seed, repeat)
    % MAIN Entry point for the rewritten bit-consistency test.
    % Repeats with consecutive run seeds and saves merged results/<timestamp>/.
    arguments (Input)
        prima_dir (1, 1) string = "./prima/"
        matcutest_paths (1, :) string = "~/.local/matcutest/mtools/src/"
        mindim (1, 1) double {mustBeInteger, mustBePositive} = 1
        maxdim (1, 1) double {mustBeInteger, mustBePositive} = 100
        n_jobs (1, 1) double {mustBeInteger, mustBePositive} = 40
        run_seed (1, 1) double {mustBeInteger, mustBeNonnegative, mustBeLessThan(run_seed, 4294967296)} = ...
            mod(floor(posixtime(datetime('now')) * 1000), 2^32)
        % 10 repeat needs ~4000s
        repeat (1, 1) double {mustBeInteger, mustBePositive} = 20
    end
    arguments (Output)
        differences (1, 1) struct
        problem_list (1, :) struct
    end
    assert(run_seed + repeat < 2^32, 'Repeated run seeds must remain below 2^32.');
    start_time = tic;

    prepare_environment(prima_dir, matcutest_paths);

    differences = struct();
    problem_lists = cell(1, repeat);
    for i = 1:repeat

        [run_differences, problem_lists{i}] = test(mindim, maxdim, n_jobs, run_seed + i);

        names = fieldnames(run_differences);
        for j = 1:numel(names)
            differences.(names{j}) = run_differences.(names{j});
        end
    end
    problem_list = [problem_lists{:}];

    have_differences = summarize_differences(differences);
    if have_differences
        save_output({differences, problem_list}, ["differences.json", "problems.json"]);
    else
        save_output({struct()}, ["no_differences.json"]);
    end

    fprintf('Total elapsed time: %.2f seconds.\n', toc(start_time));
end

function have_differences = summarize_differences(differences)
    % SUMMARIZE_DIFFERENCES Print counts of problems and solver pairs with differences.
    arguments
        differences (1, 1) struct
    end

    problems = fieldnames(differences);
    if isempty(problems)
        have_differences = false;
        fprintf('Congratulations! No differences found. :)\n');
    else
        have_differences = true;
        n_pairs = 0;
        for i = 1:numel(problems)
            n_pairs = n_pairs + numel(fieldnames(differences.(problems{i})));
        end
        fprintf('Differences: %d problems, %d problem-solver pairs.\n', numel(problems), n_pairs);
    end
end

function save_output(struct_list, filename_list)
    arguments
        struct_list (1, :) cell
        filename_list (1, :) string
    end
    assert(numel(struct_list) == numel(filename_list), 'Output and filename lists must have equal lengths.');

    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    output_dir = fullfile(fileparts(mfilename('fullpath')), 'results', stamp);
    [created, message] = mkdir(output_dir);
    assert(created, 'Cannot create output directory %s: %s', output_dir, message);
    for i = 1:numel(struct_list)
        write_json(fullfile(output_dir, char(filename_list(i))), struct_list{i});
    end
    fprintf('Output saved in %s\n', output_dir);
end

function write_json(output_file, value)
    arguments
        output_file (1, :) char
        value
    end

    text = jsonencode(prepare_json_value(value), 'PrettyPrint', true);
    file_id = fopen(output_file, 'w');
    assert(file_id >= 0, 'Cannot open output file: %s', output_file);
    cleanup = onCleanup(@() fclose(file_id));
    bytes = unicode2native([text, newline], 'UTF-8');
    written = fwrite(file_id, bytes, 'uint8');
    assert(written == numel(bytes), 'Incomplete write of test output: %s', output_file);
end

function encoded = prepare_json_value(value)
    % Convert only the exported copy; keep the returned difference tree intact.
    arguments (Input)
        value
    end
    arguments (Output)
        encoded
    end

    % MatCUTEst linear constraints can be sparse; JSON needs dense array values.
    if issparse(value)
        value = full(value);
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
            encoded = prepare_json_value(num2cell(value));
        end
    elseif isa(value, 'function_handle')
        encoded = func2str(value);
    end
end
