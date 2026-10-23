function values = seed_probe(seed, values)

    fortran.random_seed('put', seed);
    values = rand(size(values));
end
