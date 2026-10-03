# Maintaining

Runbooks for the recurring maintainer tasks. `docs/scripts.md` describes every script and file named here.

## Pin bump

When: a drift issue reports a new `sulu/skeleton` tag of a line, or an official recipe that moved.

1. Set `SULU_SKELETON_SHA` and `SULU_SKELETON_VERSION` in `tests/lines/<line>.env`, or `SYMFONY_RECIPES_SHA` or `SYMFONY_RECIPES_CONTRIB_SHA` in `tests/pins.env`.
2. For a `sulu/skeleton` pin, run `SULU_LINE=<line> bin/sync-skeleton.sh`. It rewrites the recipe files from the new pin plus their patches. For a pin in `tests/pins.env`, port the change of the official recipe by hand, because `bin/sync-skeleton.sh` reads only `sulu/skeleton`.
3. A file reported as `kept` has a patch that no longer applies. Edit the file and rewrite the patch with `bin/make-patch.sh`, or delete the patch if upstream took the change. `kept (removed upstream)` means `sulu/skeleton` no longer has the file; delete the patch and decide whether the recipe keeps the file.
4. Run `tests/patches.sh` and the install harnesses of the line (`tests/install.sh`, `tests/install-bare.sh`, `tests/parity.sh`).
5. Update `tests/lines/<line>.parity-expected.txt` and the bare-lock files only for differences you can explain.

Files: `tests/lines/<line>.env` or `tests/pins.env`, the recipe files, `tests/patches/`, the expectation files of the line.

## Drift issue

When: `.github/workflows/drift.yml` runs `tests/drift.sh` every Monday at 06:00 UTC, or on demand, and opens or updates one issue per finding, labeled `drift`. An issue for a newer tag of a line closes the one for the older tag.

The issue title tells you what moved:

- `sulu/skeleton <line>: <tag> released`: a new tag of a line. The issue lists the changed files the recipes ship and whether each patch still applies to the new tag. Do a pin bump.
- `Official recipe changed: <package>`: the official recipe of a package moved past `tests/pins.env`. If this repository supersedes the package, port the change to its recipe or record why not, then bump the pin. If the package is in `SULU_YAML_PACKAGES`, check whether `config/packages/sulu.yaml` of the `sulu/sulu` recipe still fits, then bump the pin.
- `sulu/skeleton: new line <minor>`: a new minor of `sulu/skeleton` has no line yet. Add a release line.

Close the issue with the commit that resolves it.

## Superseding an official recipe

When: Sulu needs to own a file that an official recipe installs.

1. Run `bin/supersede.sh recipes|contrib <package>/<version> <package>/<version>`. The first path is the folder in the official repository, the second the target folder here. It prints `sulu:` for every file taken from `sulu/skeleton` and `official:` for every file kept from the official recipe.
2. Review the files, and write a patch with `bin/make-patch.sh` for every change you make.
3. Add the package to `SUPERSEDED` in `tests/lib.sh`, so drift watches its official recipe and the install checks expect this repository's recipe. If its vendor is new, add the vendor to `RECIPE_VENDORS` there too, or `tests/build-endpoint.sh` leaves the recipe out. If not every line installs the package, add it to the `installed` case in `tests/install.sh`.
4. Run `tests/style.sh`, `tests/patches.sh` and parity for every line, and update `tests/lines/<line>.parity-expected.txt`.

Files: the new recipe folder, `tests/lib.sh`, `tests/install.sh`, `tests/patches/`, the parity expectations.

For a package without an official recipe, create the recipe folder by hand instead of running `bin/supersede.sh`, and add the package to `OWN_RECIPES` in `tests/lib.sh` instead of `SUPERSEDED`.

## New release line

When: a drift issue reports a new minor of `sulu/skeleton`.

1. Create `tests/lines/<line>.env` with every key listed in `docs/scripts.md`.
2. Create `sulu/sulu/<line>/` from the `sulu/skeleton` tag.
3. Create `tests/lines/<line>.parity-expected.txt`. Create `tests/lines/<line>.bare-lock.txt` for the runs in `SULU_BARE_RUNS` that have no lock name, and `tests/lines/<line>.bare-lock.<name>.txt` for each lock name.
4. Check both ends of the version range: `composer require` and `--prefer-lowest`, and which recipe version Flex selects for each package. If the lowest run does not boot because of an upstream version, raise it with `SULU_BARE_LOWEST_FLOOR`.
5. Create a `<line>` branch in `sulu-flex-skeleton`.
6. Update branch protection for `main` and the new skeleton branch.

Files: `tests/lines/<line>.*`, `sulu/sulu/<line>/`, the skeleton branch.

## Branch protection

When: a new line, or a changed `SULU_PHP_MYSQL` or `SULU_BARE_RUNS`, changes the names of the `qa.yml` jobs. Branch protection requires every job by name, so a pull request stays blocked on a job name that no longer exists.

Print the job names from the line files:

```bash
tests/matrix.sh | jq -Rrn '[inputs | capture("^(?<k>[a-z_]+)=(?<v>.*)$") | {(.k): (.v | fromjson)}] | add | ["lint", "lines"] + [.install[] | "install (\(.line), PHP \(.php), MySQL \(.mysql))"] + [.bare[] | "install-bare (\(.line), PHP \(.php), Symfony \(.symfony), \(.deps))"] + [.lines[] | "parity (\(.))"] | .[]'
```

Set them on `main` of this repository. For a branch of `sulu-flex-skeleton`, take `lint`, `lines` and the jobs of that branch's line, each prefixed with `qa / `:

```bash
gh api -X PUT repos/<owner>/<repo>/branches/<branch>/protection --input - <<'EOF'
{"required_status_checks":{"strict":false,"checks":[{"context":"lint"},{"context":"lines"},{"context":"<job name>"}]},"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
EOF
```

Check the result:

```bash
gh api repos/<owner>/<repo>/branches/<branch>/protection --jq '[.required_status_checks.checks[].context]'
```

## Publishing

- `.github/workflows/flex-update.yml` compiles the endpoint into the `flex/main` branch on every push to `main`, once `qa.yml` has passed for that commit. On push, `qa.yml` runs only the last PHP and MySQL pair of each line (`install_push` of `tests/matrix.sh`) and no `install-bare` jobs, so an upstream regression on an old version can't block publishing.
- `.github/workflows/pr-preview.yml` builds a preview endpoint on `flex/pull-<number>` for every pull request against `main` and links it in a comment.
- `.github/workflows/flex-cleanup.yml` removes the preview endpoint when the pull request is closed.

After a transfer of the repository to another owner:

1. Update the endpoint URL in `README.md` and in `composer.json` of `sulu-flex-skeleton`.
2. The harness takes the repository name from the `origin` remote; set `SULU_RECIPES_REPO` only where that remote is missing.
3. Set branch protection in the new location.
