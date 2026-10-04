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

- Store each superseded recipe as a delta against the official recipe at its pin, instead of as a list of files taken from `sulu/skeleton` or the official recipe: one diff per file from the official file to ours (the `sulu/skeleton` content plus our patches), whole files where the official recipe has none, and a drop list of official files we leave out (such as `config/packages/security.yaml` and `templates/base.html.twig`), and the build applies them to the official folder. It builds on the derived recipe build (recipe files generated from lists at build time) and only changes the storage of superseded recipes. A spike on 04.10.2026 showed that of the 84 files of the superseded recipes, 35 equal the official file and would not be stored, 44 become deltas with 646 changed lines, 5 stay whole files (53 lines) and 3 recipes need a drop list, and the endpoint built this way was byte-identical (61 files). Deferred because a delta mixes `sulu/skeleton` changes with our own patches, so the `Reason:` and `Evidence:` per change are lost, and every `sulu/skeleton` pin bump needs the deltas regenerated. To pick it up, write a spec that includes a tool regenerating the deltas on a pin bump, and accept it only if the endpoint stays byte-identical to the derived build.
- Send the documentation fixes in `tests/patches/` upstream to `sulu/skeleton`; drift then reports them as no longer applying, and they can be dropped. A fix for both lines goes to the `2.6` branch of `sulu/skeleton`, which its maintainers merge into `3.0`; a fix with `Lines: 3.0` goes to `3.0`.
