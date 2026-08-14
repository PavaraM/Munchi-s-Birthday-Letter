# Contributing

This is a personal birthday project, but contributions to the *DevOps tooling*
are welcome.

## Workflow

1. Branch from `dev`: `git checkout dev && git checkout -b feat/your-thing`
2. Make changes, run `make lint` and `make test` locally
3. Commit with a conventional message (`feat:`, `fix:`, `ci:`, `docs:`…)
4. Open a Pull Request against `dev` (PRs straight to `main` are rejected by
   branch protection)

## Constraints

- **`index.html` is sacred.** The letter, animations, and countdown must keep
  working. Functional changes to the site go through explicit review.
- `.env` files are never committed; use `.env.example` as the template.
- CI must pass (lint → secret-scan → build → test → image scan) before merge.

## Local quickstart

```bash
make setup        # install dev deps (node)
make lint         # html-validate
make build        # minify + precompress into dist/
make test         # local smoke test against dist/
make docker-run   # build + run the production container locally
```
