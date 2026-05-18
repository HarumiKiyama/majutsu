# Repository Guidelines

## Project Structure & Module Organization

Majutsu is an Emacs Lisp package for the Jujutsu VCS. Source modules live at the repository root as `majutsu-*.el`, with `majutsu.el` as the package entry point. Tests are in `test/` and follow the source module names, for example `test/majutsu-log-test.el`. User documentation is in `README.org`, `NEWS.org`, and `docs/`. OpenSpec workflow artifacts are under `openspec/`; keep generated or planning-only changes there.

## Build, Test, and Development Commands

- `eask test ert test/*.el`: run the full ERT suite through Eask.
- `emacs --batch -L . -l ert -l test/majutsu-log-test.el -f ert-run-tests-batch-and-exit`: run one test file when Eask is unavailable; add local package directories to `load-path` if Magit or Transient are not found.
- `emacs -Q -L .`: start a minimal Emacs session for manual package loading and interactive checks.

This project has no compile or asset build step beyond Emacs Lisp loading and tests.

## Coding Style & Naming Conventions

Use Emacs Lisp conventions: two-space indentation, `lexical-binding: t`, descriptive docstrings for public functions, and names prefixed with `majutsu-`. Internal helpers use double hyphens, such as `majutsu-log--wash-status`; private file-local helpers may use a module prefix. Prefer existing Magit section and Transient patterns over new abstractions. Keep comments short and only where they clarify non-obvious behavior.

## Testing Guidelines

Tests use ERT. Add or update focused tests in the matching `test/*-test.el` file for every behavior change. Test names should describe the unit and expected behavior, for example `majutsu-log--wash-status-single-file`. Prefer small fixtures and stub `jj` process calls with `cl-letf` when testing command assembly or buffer washing.

## Commit & Pull Request Guidelines

History uses Conventional Commits: `feat:`, `fix(scope):`, and `chore:`. Keep commits scoped to one behavior or refactor. Pull requests should include a short problem statement, the implementation summary, and the exact test command run. Link issues or OpenSpec changes when applicable, and include screenshots only for visible UI changes.

## Agent-Specific Instructions

Do not revert user changes in a dirty worktree. Before editing shared files, inspect current diffs and make the smallest compatible change. Prefer `rg` for searches and `apply_patch` for manual edits.
