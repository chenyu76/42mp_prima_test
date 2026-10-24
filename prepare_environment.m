function prepare_environment(prima_dir, matcutest_paths)
    % PREPARE_ENVIRONMENT Prepare MatCUTEst and rebuild a patched PRIMA copy.
    % Paths may be relative to the current project directory.
    arguments
        prima_dir (1, 1) string
        matcutest_paths (1, :) string
    end

    prima_dir = resolve_prima_directory(prima_dir);
    prima_dir = copy_prima(prima_dir);
    patch_prima_constants(prima_dir);
    add_environment_paths(prima_dir, matcutest_paths);
    check_dependencies(prima_dir);
    initialize_prima(prima_dir);
    setup_prima_mex(prima_dir);
    compile_prima(prima_dir);
    check_runtime(prima_dir);
end

function copy_dir = copy_prima(source_dir)
    arguments (Input)
        source_dir (1, 1) string
    end
    arguments (Output)
        copy_dir (1, 1) string
    end

    copy_dir = string(tempname(tempdir())) + "_prima";
    [copied, message] = copyfile(source_dir, copy_dir);
    assert(copied, 'Cannot copy PRIMA to %s: %s', copy_dir, message);
end

function patch_prima_constants(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    consts_file = fullfile(prima_dir, 'fortran', 'common', 'consts.F90');
    source = fileread(consts_file);
    old_block = sprintf([ ...
                         '#if (defined __flang__ && __flang_major__ <= 19)\n', ...
                         'real(RP), parameter :: TINYCV = TEN**max(-60.0, -real(MAXPOW10))\n', ...
                         '#else\n', ...
                         'real(RP), parameter :: TINYCV = TEN**max(-60, -MAXPOW10)\n', ...
                         '#endif']);
    % Match the MATLAB translation's double-precision runtime power result.
    new_block = sprintf([ ...
                         '#if PRIMA_REAL_PRECISION == 64\n', ...
                         '! Match the double-precision value used by the MATLAB translation.\n', ...
                         'real(RP), parameter :: TINYCV = 1.0000000000000001E-60_RP\n', ...
                         '#elif (defined __flang__ && __flang_major__ <= 19)\n', ...
                         'real(RP), parameter :: TINYCV = TEN**max(-60.0, -real(MAXPOW10))\n', ...
                         '#else\n', ...
                         'real(RP), parameter :: TINYCV = TEN**max(-60, -MAXPOW10)\n', ...
                         '#endif']);
    assert(count(source, old_block) == 1, ...
           'Expected exactly one TINYCV declaration block in %s.', consts_file);
    source = strrep(source, old_block, new_block);
    file_id = fopen(consts_file, 'w');
    assert(file_id >= 0, 'Cannot write PRIMA constants: %s', consts_file);
    cleanup = onCleanup(@() fclose(file_id));
    written = fwrite(file_id, source, 'char');
    assert(written == numel(source), 'Incomplete write of PRIMA constants: %s', consts_file);
end

function prima_dir = resolve_prima_directory(prima_dir)
    arguments (Input)
        prima_dir (1, 1) string
    end
    arguments (Output)
        prima_dir (1, 1) string
    end

    assert(isfolder(prima_dir), 'PRIMA directory does not exist: %s', prima_dir);
    original_directory = pwd();
    cleanup = onCleanup(@() cd(original_directory));
    % Resolve before later helpers change directory so relative inputs remain usable.
    cd(prima_dir);
    prima_dir = string(pwd());
end

function add_environment_paths(prima_dir, matcutest_paths)
    arguments
        prima_dir (1, 1) string
        matcutest_paths (1, :) string
    end

    for directory = matcutest_paths
        assert(isfolder(directory), 'MatCUTEst directory does not exist: %s', directory);
        addpath(char(directory));
    end
    interfaces = fullfile(prima_dir, 'matlab', 'interfaces');
    tools = fullfile(prima_dir, 'matlab', 'setup_tools');
    assert(isfolder(interfaces), 'PRIMA interfaces directory is missing.');
    assert(isfolder(tools), 'PRIMA setup tools directory is missing.');
    addpath(char(interfaces), char(tools));
end

function check_dependencies(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    assert(isfile(fullfile(prima_dir, 'setup.m')), 'PRIMA setup.m is missing.');
    for name = ["macup", "secup", "prima"]
        assert(exist(char(name), 'file') == 2, 'Required function is missing: %s', name);
    end
    assert(strcmp(which('prima'), fullfile(prima_dir, 'matlab', 'interfaces', 'prima.m')), ...
           'Another PRIMA installation takes precedence on the MATLAB path.');
end

function initialize_prima(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    original_directory = pwd();
    cleanup = onCleanup(@() cd(original_directory));
    cd(prima_dir);
    % Generate precision/variant lists and install the shared runtime helpers.
    setup('path');
end

function setup_prima_mex(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    script_file = fullfile(prima_dir, 'matlab', 'interfaces', 'setup_mex.m');
    % Translated distributions use this script for Fortran math helpers;
    % distributions without it are allowed and reported, as requested.
    if ~isfile(script_file)
        fprintf('Warning: setup_mex.m not found at %s; skipping.\n', script_file);
        return
    end

    original_directory = pwd();
    % The script can change directory before a compiler error interrupts it.
    cleanup = onCleanup(@() cd(original_directory));
    run(script_file);
end

function compile_prima(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    original_directory = pwd();
    cleanup = onCleanup(@() cd(original_directory));
    cd(prima_dir);
    % Random options toggle debug; both modern double-precision builds are needed.
    setup(struct('debug', true, 'single', false, 'classical', false));
end

function check_runtime(prima_dir)
    arguments
        prima_dir (1, 1) string
    end

    runtime_dir = fullfile(prima_dir, 'matlab', 'interfaces', 'private');
    for name = ["all_solvers", "all_precisions", "all_variants", ...
                "dbgstr", "get_mexname", "package_info"]
        assert(isfile(fullfile(runtime_dir, name + ".m")), ...
               'PRIMA runtime helper is missing: %s', name);
    end

    original_directory = pwd();
    cleanup = onCleanup(@() cd(original_directory));
    cd(fullfile(prima_dir, 'matlab', 'setup_tools'));
    for solver = ["uobyqa", "newuoa", "bobyqa", "lincoa", "cobyla"]
        for debug = [false, true]
            % Four inputs avoid get_mexname's runtime fallback to a non-debug MEX.
            name = get_mexname(char(solver), 'double', debug, 'modern');
            mex_file = fullfile(runtime_dir, [name, '.', mexext()]);
            assert(exist(mex_file, 'file') == 3, 'Required PRIMA MEX is missing: %s', mex_file);
        end
    end
end
