classdef RecordedProblem < handle
    % RECORDEDPROBLEM Record PRIMA objective and nonlinear constraint calls.
    % Construct a separate instance for each solver run.
    properties (Access = private)
        source (1, 1) struct
        evaluations (1, :) struct = struct('function', {}, 'x', {}, ...
                                           'f', {}, 'cineq', {}, 'ceq', {}, 'error_identifier', {})
    end

    methods

        function obj = RecordedProblem(problem)
            arguments
                problem (1, 1) struct
            end
            obj.source = problem;
        end

        function problem = get_problem(obj)
            % GET_PROBLEM Return PRIMA inputs with recording callbacks.
            arguments (Input)
                obj (1, 1) RecordedProblem
            end
            arguments (Output)
                problem (1, 1) struct
            end
            problem = obj.source;
            if ~isempty(problem.objective)
                problem.objective = @(x) obj.evaluate_objective(x);
            end
            if ~isempty(problem.nonlcon)
                problem.nonlcon = @(x) obj.evaluate_nonlcon(x);
            end
        end

        function record = get_record(obj)
            % GET_RECORD Return the source problem and evaluations in call order.
            arguments (Input)
                obj (1, 1) RecordedProblem
            end
            arguments (Output)
                record (1, 1) struct
            end
            record = struct('problem', obj.source, 'evaluations', obj.evaluations);
        end

    end

    methods (Access = private)

        function index = begin_evaluation(obj, function_name, x)
            arguments (Input)
                obj (1, 1) RecordedProblem
                function_name (1, 1) string
                x double
            end
            arguments (Output)
                index (1, 1) double
            end
            % Reserve the entry before evaluation so failures retain their input.
            index = numel(obj.evaluations) + 1;
            obj.evaluations(index) = struct('function', function_name, ...
                                            'x', x, 'f', [], 'cineq', [], 'ceq', [], 'error_identifier', "");
        end

        function f = evaluate_objective(obj, x)
            arguments (Input)
                obj (1, 1) RecordedProblem
                x double
            end
            arguments (Output)
                f double
            end
            index = obj.begin_evaluation("objective", x);
            try
                f = obj.source.objective(x);
            catch exception
                obj.evaluations(index).error_identifier = string(exception.identifier);
                rethrow(exception);
            end
            obj.evaluations(index).f = f;
        end

        function [cineq, ceq] = evaluate_nonlcon(obj, x)
            arguments (Input)
                obj (1, 1) RecordedProblem
                x double
            end
            arguments (Output)
                cineq double
                ceq double
            end
            index = obj.begin_evaluation("nonlcon", x);
            try
                [cineq, ceq] = obj.source.nonlcon(x);
            catch exception
                obj.evaluations(index).error_identifier = string(exception.identifier);
                rethrow(exception);
            end
            obj.evaluations(index).cineq = cineq;
            obj.evaluations(index).ceq = ceq;
        end

    end
end
