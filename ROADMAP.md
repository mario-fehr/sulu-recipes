# Roadmap

Deferred ideas without a spec, one line each. Research starts when an item is picked up.

## Hosting and publishing

- Publish this repo on GitHub, bootstrap an orphan `flex/main` branch, and add `flex-update.yml` (with `concurrency`) calling `symfony/recipes`' official reusable workflow.
- Publish `sulu-flex-skeleton` on GitHub and Packagist, with tags per release line.
- Move both repos to the `sulu` GitHub org once proven; manifest content stays org-agnostic for that.

## Release lines and versions

- The 2.6 line.
- The 3.1 line (upstream already has a `3.1` branch).
- Test Symfony 6.4 and 8.x against the `6.4/` recipe folders.
- Check the recipes against every `3.0.x` tag, not only the pinned one.
- Prove a bare `composer require sulu/sulu` (without `sulu/skeleton`'s package set): Sulu's config needs `scheb/2fa-bundle` and the web profiler routes, so the recipe would need to guard or drop those parts. Also: `/public/uploads` is then not gitignored, since only `sulu-flex-skeleton`'s hand-written `.gitignore` covers it.

## CI and drift

- `qa.yml`: lint plus a real `composer require sulu/sulu` against a locally served endpoint.
- Detect drift between the recipes and `sulu/skeleton` or the superseded official recipes; issue only, no auto-fix.
- `pr-preview` and `flex-cleanup`, only once there are outside contributors; block symlinks and use `persist-credentials: false`.
- A functional smoke test in CI (boot, build, admin login).

## Content

- Ship Sulu's stricter tooling configs (`phpstan.dist.neon` at level `max` with its `tests/phpstan/*` stubs, Sulu's `.php-cs-fixer.dist.php`).
- Decide how `sulu-flex-skeleton` tracks `sulu/skeleton`'s `composer.json` `conflict` key over time.
- Trimming `sulu-flex-skeleton`'s `require` to non-transitive packages is not planned: the created project's `src/Kernel.php` uses `symfony/config` and FOS HttpCache directly, and Composer's convention is to require what your own code uses.

## Known harness gaps

Found in the PoC's final review; they matter once the harnesses run unattended in CI. Remove each line when the CI spec covers it.

- `milestone-b.sh` discards `debug:config`/`debug:router` exit codes; a crash on both sides compares as equal.
- `POC_REUSE=1` rebuilds the endpoint but compares projects installed from the previous one.
- `milestone-a.sh` does not probe port 8001 and waits a fixed `sleep 2` for `php -S`.
- `build-endpoint.sh` compiles from a copy of the working tree, so git-ignored stray files under a recipe directory would be published locally but not by CI.
