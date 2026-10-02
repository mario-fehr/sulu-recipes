# Roadmap

Deferred ideas without a spec, one line each. Research starts when an item is picked up.

## Hosting and publishing

- Move both repos to the `sulu` GitHub org once proven; manifest content stays org-agnostic for that.
- Register `sulu-flex-skeleton` on Packagist under its final name once the org move is done.

## Release lines and versions

- The 2.6 line.
- The 3.1 line (upstream already has a `3.1` branch).
- Test Symfony 6.4 and 8.x against the `6.4/` recipe folders.
- Check the recipes against every `3.0.x` tag, not only the pinned one.
- Prove a bare `composer require sulu/sulu` (without `sulu/skeleton`'s package set): Sulu's config needs `scheb/2fa-bundle` and the web profiler routes, so the recipe would need to guard or drop those parts. Also: `/public/uploads` is then not gitignored, since only `sulu-flex-skeleton`'s hand-written `.gitignore` covers it.

## CI and drift

- Add a PHP 8.2 to 8.4 and MySQL 5.7/8.0 matrix to `qa.yml`, like the CI of `sulu/skeleton`.
- Port the style checks from `callable-qa.yml` in `symfony/recipes`: indentation, `.yaml` extension, no `.gitkeep`, no symlinks.
- Once others contribute or the repos move to the `sulu` org, require the `lint`, `install` and `parity` checks on `main` (and `qa / lint`, `qa / install`, `qa / parity` on the skeleton's `3.0`) through branch protection; today only force pushes and deletion are blocked, and `flex-update.yml` publishes only after `qa.yml` passes.
- Detect drift between the recipes and `sulu/skeleton` or the superseded official recipes; issue only, no auto-fix.
- `pr-preview` and `flex-cleanup`, only once there are outside contributors; block symlinks and use `persist-credentials: false`.
- A functional smoke test in CI (boot, build, admin login).
- Harness polish left over from the milestone C review: check port 8000 before the endpoint build, notice a `php -S` that exits, a clear message when no install recorded `endpoint.tree`, labels in `checks.log`, a guard for an empty `require-dev` list, and a top-level-only `vendor` exclude in `parity.sh`.

## Content

- Ship Sulu's stricter tooling configs (`phpstan.dist.neon` at level `max` with its `tests/phpstan/*` stubs, Sulu's `.php-cs-fixer.dist.php`).
- Decide how `sulu-flex-skeleton` tracks `sulu/skeleton`'s `composer.json` `conflict` key over time.
- Trimming `sulu-flex-skeleton`'s `require` to non-transitive packages is not planned: the created project's `src/Kernel.php` uses `symfony/config` and FOS HttpCache directly, and Composer's convention is to require what your own code uses.
