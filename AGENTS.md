# Project constraints

- The user owns the framework and decides each implementation step for the Python rewrite.
- Keep new implementation files, including `main.py` and `.venv/`, in the project root.
- Treat `test_bit_consistency/` as reference-only. Do not modify files in that directory.
- Implement only the details explicitly requested by the user. Do not add unrequested steps, features, abstractions, or behavior.
- Leave unspecified implementation steps as `pass` when a placeholder is needed. Mention missing decisions in the conversation instead of filling them in code.
- Existing MATLAB scripts are reference material, not requirements to reproduce all their behavior.
- Start with Python and `matlab.engine`. If a step becomes awkward to implement, discuss switching to MATLAB with the user before changing languages.
- Use explicit Python type annotations for implemented interfaces. A `pass` placeholder may temporarily leave its declared return type unfulfilled.
- All content written to files must be in English.
