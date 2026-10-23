function values = seed_probe(seed, values)

    random_seed('put', seed);
    values = rand(size(values));
end
