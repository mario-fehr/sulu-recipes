# Roadmap

Deferred ideas without a spec, one line each. Research starts when an item is picked up.

## Hosting and publishing

- Move both repos to the `sulu` GitHub org once proven; manifest content stays org-agnostic for that, and the harness takes the repo name from the `origin` remote (`SULU_RECIPES_REPO` overrides it).
- Register `sulu-flex-skeleton` on Packagist under its final name once the org move is done.

## Release lines and versions

- The 2.6 line.
- The 3.1 line, once `sulu/skeleton` tags `3.1.0`; the harness already takes one pin file per line in `tests/lines/`.
- Test Symfony 6.4 and 8.x against the `6.4/` recipe folders, for the `sulu-flex-skeleton` path only (the bare install already runs on 8.1).
- Check the recipes against every `3.0.x` tag, not only the pinned one.
- Assign shared recipe versions to release lines; `symfony/twig-bundle/6.4`'s `base.html.twig` uses `sulu_page_navigation_root_tree`, which Sulu 2.6 does not have.
- Give packages from `sulu/skeleton`'s set that are installed after a bare install their Sulu config. 2FA (together with `scheb/2fa-email` and `scheb/2fa-trusted-device`) and the profiler routes already work. Check whether `scheb/2fa-bundle` alone boots, since `scheb_2fa.yaml` enables `email` and `trusted_device`, and check the other packages.
- Support adding `sulu/sulu` to an existing project. Superseded recipes of installed packages need `composer recipes:install <package> --force`, which overwrites files; document or script it.
- Add a `symfony/framework-bundle/8.1/` version (a copy of this repository's `6.4` version, without the `AGENTS.md` and `CLAUDE.md` that the official `8.1` recipe copies into the project), and before supporting Symfony 8.2, compare with the official `8.2` versions of `symfony/framework-bundle`, `symfony/security-bundle` and `symfony/web-profiler-bundle` and add a bare run on 8.2.

## CI and drift

- Move `qa.yml` and `drift.yml` from `ubuntu-24.04` to Ubuntu 26 once `setup-php` supports PHP 8.5 there; `ubuntu-latest` moves to Ubuntu 26 from 19 October 2026.
- Patches for files that come only from an official recipe (`symfony/recipes`, `symfony/recipes-contrib`). `tests/patches.sh` covers only files shared with `sulu/skeleton`; the others are checked by `tests/drift.sh` against the pins in `tests/pins.env`, and there is no way to patch them.

## Content

- Ship Sulu's stricter tooling configs (`phpstan.dist.neon` at level `max` with its `tests/phpstan/*` stubs, Sulu's `.php-cs-fixer.dist.php`).
- Decide how `sulu-flex-skeleton` tracks `sulu/skeleton`'s `composer.json` `conflict` key over time.
- Trimming `sulu-flex-skeleton`'s `require` to non-transitive packages is not planned: the created project's `src/Kernel.php` uses `symfony/config` and FOS HttpCache directly, and Composer's convention is to require what your own code uses.
- Spike: minimal recipes, accepted by effective config (`debug:config`, `debug:router`) instead of file parity.
- Send the documentation fixes in `tests/patches/` upstream to `sulu/skeleton`; drift then reports them as no longer applying, and they can be dropped.
- Move skeleton tooling configs (`rector.php`, `tests/rector/`, `.twig-cs-fixer.dist.php`) from the `sulu/sulu` recipe into recipes of the tool packages, so they only land in projects that install the tool.
