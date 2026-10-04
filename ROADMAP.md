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

- Spike to decide whether a trimmed `require` and `require-dev` is worth proposing upstream to `sulu/skeleton`; `sulu-flex-skeleton` stays identical to `sulu/skeleton`, so drift and parity stay meaningful. Run it with `tests/install.sh` and `tests/parity.sh` on a scratch branch in two variants: (a) without the fully redundant `symfony/monolog-bridge`, `symfony/error-handler` and `symfony/css-selector`; (b) without everything another required package brings, keeping the version limits through `extra.symfony.require` and `conflict`. Record the resolved versions, the selected recipe folders, parity, whether the project boots, and whether Flex unconfigures a recipe when a package is dropped.
- Spike: minimal recipes, accepted by effective config (`debug:config`, `debug:router`) instead of file parity.
- Send the documentation fixes in `tests/patches/` upstream to `sulu/skeleton`; drift then reports them as no longer applying, and they can be dropped. A fix for both lines goes to the `2.6` branch of `sulu/skeleton`, which its maintainers merge into `3.0`; a fix with `Lines: 3.0` goes to `3.0`.
