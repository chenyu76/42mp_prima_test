function differences = compare_struct_trees(tree_a, tree_b, label_a, label_b)
    % COMPARE_STRUCT_TREES Return only differing branches of two struct trees.
    % Scalar struct fields retain their paths. Differing leaves use the
    % supplied labels; an absent value has no corresponding label field.
    % Array nodes contain positions (one subscript tuple per row). Leaf arrays
    % use two cell columns of values; struct/cell arrays use an elements cell
    % column containing the recursive difference tree at each position.
    % Leaf arrays with absent coordinates also use elements to omit absent labels.
    % Array size/class differences are recorded under sizes/classes.
    % Floating-point values are compared bitwise, with all NaNs equal.
    arguments (Input)
        tree_a struct
        tree_b struct
        label_a (1, 1) string
        label_b (1, 1) string
    end
    arguments (Output)
        differences (1, 1) struct
    end

    assert(isvarname(label_a) && isvarname(label_b), ...
           'Labels must be valid MATLAB field names.');
    assert(label_a ~= label_b, 'Labels must differ.');
    % Array metadata shares the namespace with the two value labels.
    assert(~any(ismember([label_a, label_b], ["positions", "sizes", "classes"])), ...
           'Labels must not be positions, sizes, or classes.');
    differences = compare_node(tree_a, tree_b, label_a, label_b);
end

function differences = compare_node(a, b, label_a, label_b)
    arguments (Input)
        a
        b
        label_a (1, 1) string
        label_b (1, 1) string
    end
    arguments (Output)
        differences (1, 1) struct
    end

    differences = struct();
    if isstruct(a) && isscalar(a) && isstruct(b) && isscalar(b)
        fields = union(fieldnames(a), fieldnames(b), 'stable');
        for i = 1:numel(fields)
            field = fields{i};
            if ~isfield(a, field)
                child = labeled_values([], b.(field), label_a, label_b, false, true);
            elseif ~isfield(b, field)
                child = labeled_values(a.(field), [], label_a, label_b, true, false);
            else
                child = compare_node(a.(field), b.(field), label_a, label_b);
            end
            if ~isempty(fieldnames(child))
                % An empty scalar struct has no fields, but isempty returns false.
                differences.(field) = child;
            end
        end
    elseif (isstruct(a) && isstruct(b)) || (iscell(a) && iscell(b))
        differences = compare_arrays(a, b, label_a, label_b);
    elseif ~values_equal(a, b)
        if ~isscalar(a) || ~isscalar(b)
            differences = compare_arrays(a, b, label_a, label_b);
        else
            differences = labeled_values(a, b, label_a, label_b);
        end
    end
end

function differences = compare_arrays(a, b, label_a, label_b)
    arguments (Input)
        a
        b
        label_a (1, 1) string
        label_b (1, 1) string
    end
    arguments (Output)
        differences (1, 1) struct
    end

    dimensions = max(ndims(a), ndims(b));
    size_a = size(a);
    size_b = size(b);
    % MATLAB treats dimensions beyond ndims as having length one.
    size_a(end + 1:dimensions) = 1;
    size_b(end + 1:dimensions) = 1;
    positions_a = element_positions(a, dimensions);
    positions_b = element_positions(b, dimensions);
    % Match coordinates, not linear indices, when array shapes differ.
    positions = unique([positions_a; positions_b], 'rows', 'stable');
    changed = false(size(positions, 1), 1);
    values_a = cell(size(changed));
    values_b = cell(size(changed));
    recursive = (isstruct(a) && isstruct(b)) || (iscell(a) && iscell(b));
    has_absent_elements = false;
    elements = cell(size(changed));
    for i = 1:size(positions, 1)
        position = positions(i, :);
        exists_a = all(position <= size_a);
        exists_b = all(position <= size_b);
        % Presence is tracked separately so absent values never masquerade as NaN.
        value_a = [];
        value_b = [];
        subscripts = num2cell(position);
        if exists_a
            value_a = a(subscripts{:});
            if iscell(a)
                value_a = value_a{1};
            end
        end
        if exists_b
            value_b = b(subscripts{:});
            if iscell(b)
                value_b = value_b{1};
            end
        end
        if recursive
            if exists_a && exists_b
                child = compare_node(value_a, value_b, label_a, label_b);
            else
                child = labeled_values(value_a, value_b, label_a, label_b, exists_a, exists_b);
            end
            changed(i) = ~isempty(fieldnames(child));
            elements{i} = child;
        else
            changed(i) = ~exists_a || ~exists_b || ...
                ~strcmp(class(a), class(b)) || ~values_equal(value_a, value_b);
            values_a{i} = value_a;
            values_b{i} = value_b;
            elements{i} = labeled_values(value_a, value_b, label_a, label_b, exists_a, exists_b);
        end
        has_absent_elements = has_absent_elements || ~exists_a || ~exists_b;
    end
    differences = struct();
    if ~any(changed) && isequal(size_a, size_b) && strcmp(class(a), class(b))
        return
    end
    differences.positions = positions(changed, :);
    if recursive || has_absent_elements
        % Keep array coordinates here and preserve field paths inside each child.
        differences.elements = elements(changed);
    else
        differences.(label_a) = values_a(changed);
        differences.(label_b) = values_b(changed);
    end
    if ~isequal(size_a, size_b)
        % Empty arrays can differ in shape without any differing elements.
        differences.sizes = labeled_values(size(a), size(b), label_a, label_b);
    end
    if ~strcmp(class(a), class(b))
        differences.classes = labeled_values(class(a), class(b), label_a, label_b);
    end
end

function positions = element_positions(value, dimensions)
    arguments (Input)
        value
        dimensions (1, 1) double
    end
    arguments (Output)
        positions (:, :) double
    end

    subscripts = cell(1, dimensions);
    [subscripts{:}] = ind2sub(size(value), (1:numel(value)).');
    positions = [subscripts{:}];
end

function result = labeled_values(a, b, label_a, label_b, exists_a, exists_b)
    arguments (Input)
        a
        b
        label_a (1, 1) string
        label_b (1, 1) string
        exists_a (1, 1) logical = true
        exists_b (1, 1) logical = true
    end
    arguments (Output)
        result (1, 1) struct
    end

    result = struct();
    if exists_a
        result.(label_a) = a;
    end
    if exists_b
        result.(label_b) = b;
    end
end

function same = values_equal(a, b)
    arguments (Input)
        a
        b
    end
    arguments (Output)
        same (1, 1) logical
    end

    same = false;
    if ~strcmp(class(a), class(b)) || ~isequal(size(a), size(b))
        return
    end
    if isfloat(a)
        if isreal(a) ~= isreal(b)
            return
        end
        for i = 1:numel(a)
            % Compare both parts: a NaN in one must not hide changes in the other.
            if ~float_equal(real(a(i)), real(b(i))) || ...
                    ~float_equal(imag(a(i)), imag(b(i)))
                return
            end
        end
    else
        same = isequaln(a, b);
        return
    end
    same = true;
end

function same = float_equal(a, b)
    arguments (Input)
        a (1, 1) {mustBeFloat}
        b (1, 1) {mustBeFloat}
    end
    arguments (Output)
        same (1, 1) logical
    end

    % Ignore NaN payloads, but preserve other bit differences such as signed zero.
    % full makes sparse elements dense; typecast reads bytes without conversion.
    same = (isnan(a) && isnan(b)) || ...
        isequal(typecast(full(a), 'uint8'), typecast(full(b), 'uint8'));
end
