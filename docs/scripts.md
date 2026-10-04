# Scripts and files

This is the reference for the scripts in `tests/` and `bin/`, the environment variables they read and the files they use. `CONTRIBUTING.md` explains how to use them when you change a recipe; `docs/maintaining.md` covers maintainer tasks.

Every script except `tests/matrix.sh` sources `tests/lib.sh`. Path arguments of `bin/make-patch.sh` and `bin/sync-upstream.sh` are relative to the repository root. The work directory holds the upstream clones (`$WORK/clones/`), the endpoint build, the test projects and the logs.

## Scripts

### tests/setup-tools.sh

`tests/setup-tools.sh`

Installs `symfony-tools/recipes-checker` into `.tools/`. Run it once, and again to update it.

### tests/build-endpoint.sh

`tests/build-endpoint.sh [<dir> [<flex-branch>]]`

Lints the recipe sources and compiles the Flex endpoint into `output/`. Without arguments it builds this checkout for `flex/main`. With arguments it builds another checkout for another branch, which is how a pull request gets its preview endpoint. `tests/install.sh`, `tests/install-bare.sh` and `tests/parity.sh` call it themselves.

### tests/style.sh

`tests/style.sh [<dir>]`

Runs the style checks of `symfony/recipes` over the recipes. Exceptions are listed with a reason in `tests/style-exceptions.txt`.

### tests/docs.sh

`tests/docs.sh [<dir>]`

Checks that every script in `tests/` and `bin/` has a header comment with a `# Usage:` line, that this file names every script and every `SULU_*` and `SKELETON_DIR` variable they and the workflows use, and that `CONTRIBUTING.md` names every job of `qa.yml`. It reports every gap and exits 1 if there is one.

### tests/patches.sh

`tests/patches.sh [<dir>]`

Checks that every recipe file equals its `sulu/skeleton` file at the pin of every line plus its patches in `tests/patches/`. A superseded recipe takes some files from its official recipe (its `manifest.json`, its `post-install.txt` and any file no line of `sulu/skeleton` has). Each of those must equal the official file at the pin in `tests/pins.env` plus its patches. Every patch needs a target, a `Reason:` and an `Evidence:` line. A patch whose header has a `Lines:` line (for example `Lines: 3.0`) applies only to the release lines it lists; for the other lines the file must equal that line's `sulu/skeleton` file without the patch. A `Lines:` value without a `tests/lines/<line>.env` fails the check, and so does a header with more than one `Lines:` line or one without a value. The official recipe is the highest folder of the package in `symfony/recipes` or `symfony/recipes-contrib` that is not above the folder version here, as Flex picks it. It also inserts the `add-lines` blocks of all manifests into their base file the way Flex does: in manifest order. A block counts for a line only if its recipe's package is in that line's `sulu/skeleton` `composer.json` (`require` or `require-dev`), and so is every package in its `requires` that has a recipe in this repository; other `requires` count as installed. A target file is checked for a line only if the package of the recipe that ships it is in that `composer.json` too. The result must equal `sulu/skeleton` at the pin of each line whose `sulu/skeleton` has the file, plus the base file's fix patch. The check fails for a block Flex would skip (no content, unknown position, missing target, a placeholder other than `%CONFIG_DIR%`) and for a target file that more than one recipe folder ships. It also fails for blocks of different recipes whose result depends on the install order: the same position, the same content, or one block containing another's target.

### tests/install.sh

`tests/install.sh`

Installs `sulu/sulu` into a fresh `symfony/skeleton` from the local endpoint and runs the checks.

### tests/install-bare.sh

`tests/install-bare.sh`

Installs `sulu/sulu` alone into a fresh `symfony/skeleton` from the local endpoint, plus `SULU_BARE_REQUIRE` and, as dev requirements, `SULU_BARE_REQUIRE_DEV` of the line. It runs the checks and compares the recipe set with `tests/lines/<line>.bare-lock.txt`, or `tests/lines/<line>.bare-lock.<SULU_BARE_LOCK>.txt` when `SULU_BARE_LOCK` is set. It also checks that no `AGENTS.md` or `CLAUDE.md` is created, and that `.symfony.local.yaml` exists exactly when `symfony/framework-bundle` is not locked at recipe `6.4`.

### tests/parity.sh

`SKELETON_DIR=<checkout> tests/parity.sh`

Installs `sulu-flex-skeleton` from the checkout in `SKELETON_DIR` and `sulu/skeleton` at the pin, and compares the two projects. Only the differences listed in `tests/lines/<line>.parity-expected.txt` may remain. It also compares `debug:config` for the extensions in `SULU_PARITY_CONFIG`.

### tests/drift.sh

`tests/drift.sh`

Reports where `sulu/skeleton` or an official recipe moved past its pin, one file per finding in `$WORK/drift/`. It reads the clones in `$WORK/clones/`. `.github/workflows/drift.yml` runs it weekly and turns the files into issues. If `composer.json` of `sulu/skeleton` changed, the report for that line also lists the changed keys, cut after two levels (three under `extra`). `sulu-flex-skeleton` has to follow them (see "Pin bump" in `docs/maintaining.md`).

### tests/matrix.sh

`tests/matrix.sh [<line>]`

Prints the `lines`, `install`, `install_push` and `bare` matrices of `qa.yml` from `SULU_PHP_MYSQL` and `SULU_BARE_RUNS` in `tests/lines/*.env`, or of one line.

### tests/lib.sh

Sourced by the other scripts, never run directly. Loads `tests/lines/$SULU_LINE.env` and `tests/pins.env`, prepares the work directory and defines the helpers.

### bin/make-patch.sh

`bin/make-patch.sh fix|adapt <recipe-file> [--reason <text> --evidence <text>] [--lines "<line> ..."]`

Writes the patch of an edited recipe file into `tests/patches/`. The patch is made against `sulu/skeleton` or, for files that come from the official recipe, against the official file. A `fix` patch is a deliberate fix, written against upstream. An `adapt` patch fits a file to an older package version or to content another recipe adds, and is written against upstream plus the fix. `--lines` writes a `Lines:` header so the patch applies only to those release lines, for a recipe that both lines share while their `sulu/skeleton` files differ; `SULU_LINE` must be one of them, and a later run keeps the header; `--lines ""` removes it.

### bin/sync-upstream.sh

`bin/sync-upstream.sh [<recipe-dir>...]`

Rewrites the recipe files from `sulu/skeleton` and the official recipes at their pins plus their patches, for all recipe folders or only the ones given. Run it after a pin bump. It prints `updated` for every file it changed and `kept` for every file whose patch no longer applies, and it exits 1 if it kept any file.

### bin/supersede.sh

`bin/supersede.sh recipes|contrib <official-recipe-dir> <target-dir>`

Copies an official recipe from `symfony/recipes` (`recipes`) or `symfony/recipes-contrib` (`contrib`) at the pin in `tests/pins.env` into `<target-dir>`. Each file that `sulu/skeleton` also has is taken from `sulu/skeleton`. It prints `sulu:` or `official:` for each file and then runs `bin/sync-upstream.sh` on the target.

## Environment

Every script that sources `tests/lib.sh` reads these:

| Variable | Default | Purpose |
|---|---|---|
| `SULU_LINE` | `3.0` | Release line; selects `tests/lines/<line>.env`. |
| `SULU_RECIPES_WORKDIR` | `$TMPDIR/sulu-recipes`, or `/tmp/sulu-recipes` without `TMPDIR` | Work directory. |
| `SULU_RECIPES_REPO` | `<owner>/<repo>` of the `origin` remote | Repository name in the endpoint and in the lock checks. |
| `SULU_PHP` | unset | A minor version such as `8.4`. If set, it must match the running PHP, or the script stops. |
| `SULU_MYSQL_VERSION` | `8.4` | MySQL image; only `tests/install.sh` and `tests/install-bare.sh` start a database. |

Read by one script:

| Variable | Script | Default | Purpose |
|---|---|---|---|
| `SULU_BARE_SYMFONY` | `tests/install-bare.sh` | `7.4` | `symfony/skeleton` version of the bare install. A value ending in `-dev`, such as `8.2-dev`, creates the project from `symfony/skeleton:<version>.x-dev`. |
| `SULU_BARE_DEPS` | `tests/install-bare.sh` | `highest` | `lowest` adds `--prefer-lowest` to `composer require sulu/sulu`. Only the packages that command adds drop to their lowest versions, while the packages of the fresh `symfony/skeleton` keep theirs. `oldest` installs the oldest `sulu/sulu` patch release of the line that Composer installs, found with a `--prefer-lowest --dry-run` require, with the newest other dependencies. |
| `SULU_BARE_LOCK` | `tests/install-bare.sh` | unset | Suffix of the bare-lock file to compare with. |
| `SKELETON_DIR` | `tests/parity.sh` | required | A clean `sulu-flex-skeleton` checkout. |
| `SULU_RECIPES_REUSE` | `tests/parity.sh` | `0` | `1` reuses both projects if the recipes, the patches and the line have not changed since they were installed. |

## Line files

`tests/lines/<line>.env` holds the pins and settings of one release line. `tests/lib.sh` loads the file of `SULU_LINE`; `tests/matrix.sh`, `tests/patches.sh` and `tests/drift.sh` read all of them.

| Key | Purpose |
|---|---|
| `SULU_SKELETON_SHA` | Pinned `sulu/skeleton` commit. |
| `SULU_SKELETON_VERSION` | Tag of that commit. |
| `SULU_FLEX_SKELETON_REF` | `sulu-flex-skeleton` branch that parity checks out. |
| `SULU_PHP_MYSQL` | `php:mysql` pairs, one `install` job per pair, using the versions `sulu/skeleton` tests in its own CI. |
| `SULU_BARE_RUNS` | `php:symfony:deps:lock` entries, one `install-bare` job each; `deps` is `highest`, `lowest` or `oldest`; `lock` is the `SULU_BARE_LOCK` of the run and may be empty. The `symfony` field may end in `-dev`; the branch protection runbook leaves such runs out. |
| `SULU_BARE_REQUIRE` | Extra packages of the bare install. |
| `SULU_BARE_REQUIRE_DEV` | Extra dev packages of the bare install. |
| `SULU_BARE_LOWEST_FLOOR` | `package:constraint` entries that raise the lowest run above upstream versions that do not boot. |
| `SULU_PARITY_CONFIG` | Extensions whose `debug:config` parity compares. |

## Other files

- `tests/pins.env`: `SYMFONY_RECIPES_SHA` and `SYMFONY_RECIPES_CONTRIB_SHA`, the pinned commits of the official recipe repositories.
- `tests/lines/<line>.bare-lock.txt`, `tests/lines/<line>.bare-lock.<name>.txt`: the recipe set a bare install must end up with.
- `tests/lines/<line>.parity-expected.txt`: the differences parity accepts.
- `tests/style-exceptions.txt`: style check exceptions, each with a reason.
- `tests/patches/<recipe-dir>/<file>.fix.patch`, `.adapt.patch`: the patches of a recipe file; each starts with a `Reason:` and an `Evidence:` line and an optional `Lines:` line.

## Internal names

`SULU_YAML_PACKAGES` is set in `tests/lib.sh` and read by `tests/drift.sh`. It lists the packages Flex installs from the official endpoint whose differences for Sulu live in `config/packages/sulu.yaml` of the `sulu/sulu` recipe; drift watches their official recipes.
