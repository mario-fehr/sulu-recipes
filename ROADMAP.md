# Roadmap

Deferred ideas without a spec, one line each. Research starts when an item is picked up.

## Hosting and publishing

- Move both repos to the `sulu` GitHub org once proven; manifest content stays org-agnostic for that, and the harness takes the repo name from the `origin` remote (`SULU_RECIPES_REPO` overrides it).
- Register `sulu-flex-skeleton` on Packagist under its final name once the org move is done.

## Release lines and versions

- The 3.1 line, once `sulu/skeleton` tags `3.1.0`; the harness already takes one pin file per line in `tests/lines/`.
- When Symfony 8.2.0 is released, follow "New Symfony minor" in `docs/maintaining.md`; the `8.2-dev` bare run becomes `8.2`.

## CI and drift

- Move `qa.yml` and `drift.yml` from `ubuntu-24.04` to Ubuntu 26 once `setup-php` supports PHP 8.5 there; `ubuntu-latest` moves to Ubuntu 26 from 19 October 2026.

## Content

- Send the `.fix.patch` files for files taken from `sulu/skeleton` (nine today) upstream to `sulu/skeleton`; drift then reports them as no longer applying, and they can be dropped. A fix in `sulu/sulu/<line>/` goes to that line's branch. A fix in a shared folder goes to the `2.6` branch, which the maintainers merge into `3.0`, unless `Lines: 3.0` limits it to `3.0`. The fix patches of official manifests (`manifest.json`, `post-install.txt`) carry Sulu choices such as MySQL and stay here.
- Split the build inputs from the checks: move `tests/patches/` to `patches/` and `tests/lines/` plus `tests/pins.env` to `lines/`, keep the scripts that produce something (generate, build-endpoint, make-patch, supersede, setup-tools, drift) in `bin/`, and leave only the checks and their expectation files in `tests/`. The recipe folders stay at the root, because Flex links to `<package>/<version>` there. The `tag` job of `sulu-flex-skeleton` reads `tests/lines/<line>.env` from `main`, so it moves in the same step. Picks up after the derived recipe build.
