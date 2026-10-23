function seed = random_seed(operation, value)
    % Adapt Fortran integer seeds to the global MATLAB Twister stream.
    % GET snapshots restore the current position; ordinary PUT seeds restart it.
    stateLength = 625; % Twister's 624 state words plus its position index.
    seedLength = stateLength + 2;
    marker = -1640531527; % Tag for this helper's GET snapshots.

    switch operation
        case 'size'
            seed = seedLength;
        case 'get'
            if value < seedLength
                error('fortran:random_seed:length', 'GET requires at least %d integers.', seedLength);
            end
            settings = rng;
            if ~strcmp(settings.Type, 'twister')
                error('fortran:random_seed:generator', 'GET requires the Twister generator.');
            end
            words = settings.State;
            seed = zeros(value, 1);
            % Reinterpret the bits: numeric uint32-to-int32 conversion saturates.
            seed(1:seedLength) = [marker; signed_words(seed_hash(words)); signed_words(words)];
        case 'put'
            if isempty(value)
                error('fortran:random_seed:length', 'PUT requires a nonempty seed array.');
            end
            words = uint32(mod(double(value(1:min(numel(value), seedLength))), 2^32));
            words = words(:);
            state = words(3:end);
            % Recognize snapshots before mapping ordinary seed arrays.
            if numel(words) == seedLength && value(1) == marker ...
                    && words(2) == seed_hash(state) && state(end) <= stateLength - 1
                rng(struct('Type', 'twister', 'Seed', 0, 'State', state));
            else
                rng(double(seed_hash(words)), 'twister');
            end
    end

    function result = seed_hash(words)
        % Each multiply-add fits within double's exact integer range.
        result = 0;
        for word = reshape(double(words), 1, [])
            result = mod(65599 * result + word, 2^32);
        end
        result = uint32(result);
    end

    function result = signed_words(words)
        result = double(typecast(words(:), 'int32'));
    end

end
