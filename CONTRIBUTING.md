# Contributing

Thanks for improving Sentinel Vision.

## Development loop

1. Create a branch from `main`.
2. Configure with `-DBUILD_TESTING=ON`.
3. Keep changes focused and add a regression test for behavior in C++ managers.
4. Run the build and test suite locally.
5. Describe the user-visible behavior and verification steps in the pull request.

## Code conventions

- Use C++17 and Qt value types at the QML boundary.
- Keep camera coordinates normalized to `[0, 1]`.
- Avoid blocking work in QML handlers; native frame processing belongs in `AnalyticsEngine`.
- Keep generated files, build directories, model weights, and captured evidence out of version control.
- Format C++ with the repository `.clang-format` configuration.

## Commit messages

Use an imperative subject that explains the outcome, for example:

```text
Add cooldown to ROI entry events
```
