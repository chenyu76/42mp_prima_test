We want to refactor `test_bit_consistency/`.

## Project constraints

- The user owns the framework and decides each implementation step for the rewrite.
- Treat `test_bit_consistency/` as reference-only. Do not modify files in that directory.
- Implement only the details explicitly requested by the user. Do not add unrequested steps, features, abstractions, or behavior.
- Mention missing decisions in the conversation instead of filling them in code. Or ask user to decide.
- Existing MATLAB scripts are reference material, not requirements to reproduce all their behavior.
- Implement only the tough transformation. matching MATLAB's random stream is not required.
- Prefer paths relative to the project directory.
- Use explicit type annotations for implemented interfaces.
- All content written to files must be in English.
