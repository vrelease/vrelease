# Repository Guidelines

## Project Structure & Module Organization
- `src/vrelease.nim` is the main entry point; shared logic lives in `src/mainimpl.nim` and submodules under `src/vr/`.
- `tests/` contains the Nim test runner (`tests/main.nim`) plus `tests/nim.cfg` for test compilation settings.
- `.docs/` stores documentation assets used in the README.
- `writemeta.nim` and `writemeta/` generate build metadata used during the build step.

## Build, Test, and Development Commands
- `make build` cleans, regenerates metadata, and compiles the binary via `nimble build`.
- `make tests` runs the Nim test task defined in `vrelease.nimble`.
- `make release` builds a release binary, strips it, and compresses it with `upx`.
- `nimble tests` is the direct equivalent of `make tests`.

## Coding Style & Naming Conventions
- Indentation is 2 spaces; follow existing Nim formatting and module layout.
- Keep module names lowercase; add new modules under `src/vr/` when extending functionality.
- Prefer descriptive procedure names in lowerCamelCase and group related helpers into a single module.

## Testing Guidelines
- Tests are orchestrated from `tests/main.nim`; add new test files in `tests/` and register them in the runner.
- Run `make tests` locally before opening a PR.

## Commit & Pull Request Guidelines
- Commit messages follow a simple type prefix, e.g. `fix: ...`, `ci: ...`, `test: ...`.
- PRs should describe the change, note any new flags or behavior, and include test output or steps to validate.
- If the change affects release output or CLI behavior, add an example invocation in the PR description.

## Security & Configuration Tips
- API authentication is provided via `VRELEASE_AUTH_TOKEN`; do not commit tokens or secrets.
- Keep Git remotes configured, as release generation relies on remote metadata.
