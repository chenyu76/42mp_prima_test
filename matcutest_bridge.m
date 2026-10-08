function varargout = matcutest_bridge(name, field, varargin)
% Keep native function handles in MATLAB and return metadata to Python.
% MatCUTEst changes the active CUTEst problem when macup is called.
    persistent problem

    if isempty(problem) || ~strcmp(problem.name, name)
        if ~isempty(problem)
            decup(problem);
            problem = [];
        end
        problem = macup(name);
    end

    if nargin == 1
        metadata = problem;
        metadata.objective = true;
        metadata.grad = true;
        metadata.hprod = true;
        metadata.nonlcon = ~isempty(problem.nonlcon);
        names = fieldnames(metadata);
        for i = 1:numel(names)
            value = metadata.(names{i});
            if issparse(value)
                metadata.(names{i}) = full(value);
            end
        end
        varargout{1} = metadata;
    else
        callback = problem.(field);
        [varargout{1:nargout}] = callback(varargin{:});
        for i = 1:nargout
            if issparse(varargout{i})
                varargout{i} = full(varargout{i});
            end
        end
    end
end
