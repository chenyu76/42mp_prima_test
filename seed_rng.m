function cleanup = seed_rng(seed)
    %SEED_RNG Seed a temporary random stream; retain cleanup until work finishes.
    arguments (Input)
        seed (1, 1) double {mustBeInteger, mustBeNonnegative, mustBeLessThan(seed, 4294967296)}
    end
    arguments (Output)
        cleanup (1, 1) onCleanup
    end

    original_rng = rng();
    cleanup = onCleanup(@() rng(original_rng));
    rng(seed, 'twister');
end
