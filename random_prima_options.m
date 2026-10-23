function [options, scenario] = random_prima_options(n, seed, reference_value)
    %RANDOM_PRIMA_OPTIONS Generate random PRIMA options, including invalid values.
    % Without a seed, draws advance the caller's stream. An explicit seed
    % reproduces options without changing that stream.
    % Eight boundary cases each have probability 1/10; random cases have 2/10.
    % Without a reference objective value, ordinary cases use ftarget = -Inf.
    % Solver and backend selection are left to the caller.
    arguments (Input)
        n (1, 1) double {mustBeInteger, mustBePositive}
        seed (1, :) double {mustBeInteger, mustBeNonnegative, mustBeLessThan(seed, 4294967296)} = []
        reference_value (1, 1) double {mustBeReal} = -Inf
    end
    arguments (Output)
        options (1, 1) struct
        scenario (1, 1) string
    end

    assert(isempty(seed) || isscalar(seed), 'Provide a scalar seed or [].');
    if ~isempty(seed)
        rng_cleanup = seed_rng(seed); %#ok<NASGU>
    end
    case_index = randi(10);
    options = struct();
    options.debug = rand() < 0.5;
    options.rhobeg = randn();
    options.rhoend = 1.0e-3 * randn();
    options.eta1 = randn();
    options.eta2 = randn();
    options.gamma1 = randn();
    options.gamma2 = randn();
    options.ctol = 1.0e-3 * randn();
    options.cweight = 1.0e3 * randn();
    % Keep negative and out-of-range counts to exercise PRIMA's input correction.
    options.npt = floor(10 * randn() * n);
    options.maxfun = floor(10 * randn() * n);
    target_offset = 10 * abs(randn());
    if isfinite(reference_value)
        options.ftarget = reference_value - target_offset * max(1, abs(reference_value));
    else
        options.ftarget = -Inf;
    end
    switch case_index
        case 1
            options.npt = (n + 1) * (n + 2) / 2;
            scenario = "npt_full";
        case 2
            options.npt = n + 2;
            scenario = "npt_min";
        case 3
            options.npt = 2 * n;
            scenario = "npt_2n";
        case 4
            options.npt = ceil(rand() * n^2);
            scenario = "npt_random";
        case 5
            options.maxfun = options.npt + 1;
            scenario = "maxfun_npt_plus_one";
        case 6
            options.maxfun = 1000 * n;
            scenario = "maxfun_1000n";
        case 7
            options.ftarget = Inf;
            scenario = "ftarget_inf";
        case 8
            options.rhoend = options.rhobeg;
            scenario = "rhoend_rhobeg";
        case {9, 10}
            scenario = "random";
    end
end
