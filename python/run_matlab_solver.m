function [x, fx, exitflag, output] = run_matlab_solver(name, problem, options, address)
% Adapt the Python problem to the legacy PRIMA solver signatures.
project_dir = fileparts(mfilename('fullpath'));
python_path = py.sys.path;
if int64(python_path.count(project_dir)) == 0
    python_path.insert(int32(0), project_dir);
end
callbacks = py.importlib.import_module('matlab_callback');
fun = @(x) double(callbacks.evaluate(address, 'fun', x));

switch lower(name)
    case {'uobyqa', 'newuoa'}
        [x, fx, exitflag, output] = feval(name, fun, problem.x0, options);
    case 'bobyqa'
        [x, fx, exitflag, output] = feval(name, fun, problem.x0, ...
            problem.xl, problem.xu, options);
    case 'lincoa'
        [x, fx, exitflag, output] = feval(name, fun, problem.x0, ...
            problem.aub, problem.bub, problem.aeq, problem.beq, ...
            problem.xl, problem.xu, options);
    case 'cobyla'
        nonlcon = @(x) nonlinear_constraints(callbacks, address, x);
        [x, fx, exitflag, output] = feval(name, fun, problem.x0, ...
            problem.aub, problem.bub, problem.aeq, problem.beq, ...
            problem.xl, problem.xu, nonlcon, options);
    otherwise
        error('matlab_solver:UnknownSolver', 'Unsupported solver: %s.', name);
end
end

function [cub, ceq] = nonlinear_constraints(callbacks, address, x)
cub = double(callbacks.evaluate(address, 'cub', x));
ceq = double(callbacks.evaluate(address, 'ceq', x));
end
