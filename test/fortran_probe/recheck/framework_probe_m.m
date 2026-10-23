classdef framework_probe_m

    methods
        function f = quadratic(~, x)

            f = sum(x .* x, 'all');
        end
        function h = record_step(~, h, x, f)

            h.count = h.count + 1;
            h.x(:, h.count) = x;
            h.f(h.count) = f;
        end
        function run_probe(obj)
            p = obj.problem_default();
            h = obj.history_default();

            p.n = 2;
            p.x0 = NaN(p.n, 1); h.x = NaN(p.n, 3); h.f = NaN(3, 1);
            p.x0 = [1.0, 2.0].';
            p.fun = @(varargin) obj.quadratic(varargin{:});
            x = p.x0;
            for i = 1:3
                f = p.fun(x);
                h = obj.record_step(h, x, f);
                x = x ./ 2.0;
            end
            if h.count ~= 3
                error("Incorrect history count");
            end
            if any(h.f ~= [5.0, 1.25, 0.3125].', 'all')
                error("Incorrect values");
            end
            if any(h.x(:, 3) ~= [0.25, 0.5].', 'all')
                error("Incorrect shape or state");
            end
            disp("FRAMEWORK_PROBE_PASS");
        end
        function value = history_default(~)
            value = struct();
            value.count = 0;
            value.f = [];
            value.x = [];
        end
        function value = problem_default(~)
            value = struct();
            value.fun = [];
            value.n = NaN;
            value.x0 = [];
        end

    end
end