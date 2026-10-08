# Project constraints

- The user owns the framework and decides each implementation step for the Python rewrite.
- Keep new implementation files, including `main.py` and `.venv/`, in the project root.
- Put all verification and test code in `test/`.
- Treat `test_bit_consistency/` as reference-only. Do not modify files in that directory.
- Implement only the details explicitly requested by the user. Do not add unrequested steps, features, abstractions, or behavior.
- Leave unspecified implementation steps as `pass` when a placeholder is needed. Mention missing decisions in the conversation instead of filling them in code.
- Existing MATLAB scripts are reference material, not requirements to reproduce all their behavior.
- Use Python and PyCUTEst for the current implementation.
- Use the custom derivative-free `Problem` structure: `name`, `n`, `x0`, `xl`, `xu`, `aub`, `bub`, `aeq`, `beq`, `fun`, `cub`, and `ceq`.
- Represent linear constraints as `aub @ x <= bub` and `aeq @ x == beq`; nonlinear constraints as `cub(x) <= 0` and `ceq(x) == 0`.
- Implement only the tough transformation, using the agreed legacy parameters. Randomness must be reproducible within Python; matching MATLAB's random stream is not required.
- Prefer paths relative to the project directory. Keep machine-specific paths in `config.py`.
- Create `.venv/` with Python's `venv` module. Install dependencies with pip and declare them in `requirements.txt`. Do not use uv.
- Ask the user for approval before executing Git commands.
- Use explicit Python type annotations for implemented interfaces. A `pass` placeholder may temporarily leave its declared return type unfulfilled.
- All content written to files must be in English.
