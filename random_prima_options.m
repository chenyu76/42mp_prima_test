function options = random_prima_options(n)
    %RANDOM_PRIMA_OPTIONS Generate random PRIMA options, including invalid values.
    % Uses the current random stream without evaluating a problem.
    % Solver and backend selection are left to the caller.
    arguments (Input)
        n (1, 1) double {mustBeInteger, mustBePositive}
    end
    arguments (Output)
        options (1, 1) struct
    end

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
    options.npt = floor(10 * randn() * n);
    options.maxfun = floor(10 * randn() * n);
    options.ftarget = 10 * randn();
end
