function names = select_matcutest_problems(min_dimension, max_dimension)
    arguments
        min_dimension (1, 1) double
        max_dimension (1, 1) double
    end
    names = secup(struct('mindim', min_dimension, 'maxdim', max_dimension, ...
        'is_feasibility', false));
    names = string(names(:));
end
