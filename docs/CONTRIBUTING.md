# Contributing to PlastiScan

Thanks for helping improve the project.

## Workflow

1. Fork the repository.
2. Create a feature branch.
3. Keep commits focused and descriptive.
4. Run analysis and tests before pushing.
5. Open a pull request against `main`.

## Coding Expectations

- Prefer small, readable, feature-specific changes.
- Reuse shared navigation helpers rather than duplicating route logic.
- Keep app flow behavior consistent with the app shell and back-button patterns.
- Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, and `chore:`.

## Validation Checklist

Before opening a PR, run:

```bash
flutter analyze
flutter test
```

## Commit Standards

Write commits that explain the change in plain terms, for example:

- `feat: add profile completion flow`
- `fix: restore manual-entry back navigation`
- `docs: add architecture overview`
- `chore: refresh dependency lockfile`
