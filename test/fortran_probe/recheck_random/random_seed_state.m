
%Error: Interfaces without names cannot be processed.

item = sample_t_default(); boxes = repmat(sample_t_default(), [2, 1]);

first = NaN(6, 1); repeated = NaN(6, 1); matrix = NaN(2, 3); scalar = NaN; buffer = NaN(6, 1);

rng('shuffle', 'twister');
n = fortran.random_seed('size');
if n <= 0
    error("seed size");
end
saved = NaN(n, 1); long_seed = NaN(n + 3, 1); sliced_seed = NaN(n + 2, 1); empty = NaN(0, 1);
seed = reshape(17 - (1:n), [], 1);
long_seed(:) = 0;
long_seed(1:n) = seed;
fortran.random_seed('put', seed);
first = rand(size(first));
fortran.random_seed('put', seed);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("repeated seed");
end
repeated = seed_probe(seed, repeated);
if any(first ~= repeated, 'all')
    error("report probe");
end

saved = fortran.random_seed('get', numel(saved));
first = rand(size(first));
fortran.random_seed('put', saved);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("restore position");
end

fortran.random_seed('put', seed);
first = rand(size(first));
fortran.random_seed('put', long_seed);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("long seed prefix");
end
long_seed = fortran.random_seed('get', numel(long_seed));
first = rand(size(first));
fortran.random_seed('put', long_seed);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("long snapshot");
end

saved = fortran.random_seed('get', numel(saved));
item.count = fortran.random_seed('size');
if item.count ~= n
    error("component size");
end
item.seed = NaN(n, 1);
item.seed = fortran.random_seed('get', numel(item.seed));
first = rand(size(first));
fortran.random_seed('put', saved);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("queries changed state");
end
fortran.random_seed('put', item.seed);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("component restore");
end

sliced_seed(:) = -7;
sliced_seed(2:n + 1) = fortran.random_seed('get', numel(sliced_seed(2:n + 1)));
if sliced_seed(1) ~= -7 || sliced_seed(n + 2) ~= -7
    error("GET slice boundary");
end
first = rand(size(first));
fortran.random_seed('put', sliced_seed(2:n + 1));
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("slice restore");
end

saved = fortran.random_seed('get', numel(saved));
rand(size(empty));
first = rand(size(first));
fortran.random_seed('put', saved);
repeated = rand(size(repeated));
if any(first ~= repeated, 'all')
    error("empty consumed state");
end

scalar = rand(size(scalar));
matrix = rand(size(matrix));
if scalar < 0 || scalar >= 1
    error("scalar range");
end
if any(matrix < 0, 'all') || any(matrix >= 1, 'all')
    error("matrix range");
end
if size(matrix, 1) ~= 2 || size(matrix, 2) ~= 3
    error("matrix shape");
end
if numel(first) ~= 6 || any(first < 0, 'all') || any(first >= 1, 'all')
    error("vector range");
end

item.values(:) = -1;
item.values = rand(size(item.values));
if any(item.values < 0, 'all') || any(item.values >= 1, 'all')
    error("component random");
end
buffer(:) = -1;
buffer(2:2:5) = rand(size(buffer(2:2:5)));
if buffer(1) ~= -1 || buffer(3) ~= -1 || buffer(5) ~= -1 || buffer(6) ~= -1
    error("strided slice boundary");
end
if buffer(2) < 0 || buffer(2) >= 1 || buffer(4) < 0 || buffer(4) >= 1
    error("strided slice range");
end

random_index = 23;
boxes(1).values(:) = -1;
boxes(2).values(:) = -1;
random_index_1 = select_box(); boxes(random_index_1).values(1) = rand(size(boxes(random_index_1).values(1)));
if boxes(1).values(1) < 0
    error("selected box");
end
if any(boxes(2).values ~= -1, 'all')
    error("selector evaluated twice");
end
if select_box() ~= 2
    error("selector count");
end
if random_index ~= 23
    error("temporary collision");
end
buffer(:) = -1;
random_index_1 = select_element(); buffer(random_index_1) = rand(size(buffer(random_index_1)));
if buffer(2) < 0 || any(buffer(3:6) ~= -1, 'all')
    error("element output");
end
if select_element() ~= 3
    error("element selector count");
end
disp("RANDOM_SEED_STATE_PASS");
function select_box = select_box()
    persistent calls
    if isempty(calls)
        calls = 0;
    end
    calls = calls + 1;
    select_box = calls;
end
function select_element = select_element()
    persistent calls
    if isempty(calls)
        calls = 1;
    end
    calls = calls + 1;
    select_element = calls;
end
function value = sample_t_default()
    value = struct();
    value.count = NaN;
    value.seed = [];
    value.values = NaN(4, 1);
end
