# Contributing

## Setup

You need PHP 8.5, Composer, Docker and `jq`. Run `tests/setup-tools.sh` once to install the recipe checker.

On first use, the harness clones `sulu/skeleton` and the official recipe repositories into its work directory (`$TMPDIR/sulu-recipes`, or the path in `SULU_RECIPES_WORKDIR`) and checks the recipes against the pinned commits. Only `tests/drift.sh` looks past the pins.

`docs/scripts.md` lists every script, variable and file mentioned here.

## Changing a recipe file

A recipe file that `sulu/skeleton` also has must equal that file at the pinned commit. It may differ only through a patch in `tests/patches/`, and the patch must start with a `Reason:` and an `Evidence:` line. A file that a superseded recipe takes from its official recipe (its `manifest.json`, its `post-install.txt`) follows the same rule, measured against the official file at the pin in `tests/pins.env`. Files with neither source, such as `config/packages/sulu.yaml` in `sulu/sulu/<line>/`, are edited directly, without a patch.

To change a file, edit it in place and write the patch:

```bash
bin/make-patch.sh fix <recipe-file> --reason "<why>" --evidence "<link or command>"
```

Use `fix` for a deliberate fix and `adapt` when the file has to fit an older package version or content another recipe adds.

A recipe folder outside `sulu/sulu/` is served to every release line, so its files must fit each line in `tests/lines/`. A file that differs between lines belongs in `sulu/sulu/<line>/`.

## Checking locally

Run the checks in this order:

```bash
tests/style.sh
tests/patches.sh
tests/build-endpoint.sh
tests/install.sh
tests/install-bare.sh
SKELETON_DIR=<sulu-flex-skeleton checkout> tests/parity.sh
```

`tests/patches.sh` checks every line. The install scripts and parity check the 3.0 line by default; set `SULU_LINE=2.6` to check the other one. `SULU_RECIPES_REUSE=1` makes repeated parity runs faster.

## Reading CI failures

`.github/workflows/qa.yml` runs these jobs on every pull request:

| Job | Runs | Reproduce locally |
|---|---|---|
| `lint` | shellcheck, `tests/style.sh`, `tests/docs.sh`, `tests/build-endpoint.sh`, `tests/patches.sh` | `shellcheck -x -P tests $(ls tests/*.sh bin/*.sh \| grep -v tests/lib.sh) && tests/style.sh && tests/docs.sh && tests/build-endpoint.sh && tests/patches.sh` |
| `lines` | `tests/matrix.sh` | `tests/matrix.sh` |
| `install (<line>, PHP <php>, MySQL <mysql>)` | `tests/install.sh` | `SULU_LINE=<line> SULU_PHP=<php> SULU_MYSQL_VERSION=<mysql> tests/install.sh` |
| `install-bare (<line>, PHP <php>, Symfony <symfony>, <deps>)` | `tests/install-bare.sh` | `SULU_LINE=<line> SULU_PHP=<php> SULU_MYSQL_VERSION=<mysql> SULU_BARE_SYMFONY=<symfony> SULU_BARE_DEPS=<deps> tests/install-bare.sh`, plus `SULU_BARE_LOCK=<lock>` when the run in `SULU_BARE_RUNS` names one |
| `parity (<line>)` | `tests/parity.sh` | `SULU_LINE=<line> SKELETON_DIR=<checkout of sulu-flex-skeleton at SULU_FLEX_SKELETON_REF> tests/parity.sh` |

`SULU_PHP` only checks that the running PHP has that version; it does not switch PHP for you. A failed `install`, `install-bare` or `parity` job uploads the logs from the work directory as an artifact.

## Pull requests

- Write code, comments and commit messages in English.
- Manifests name no owner or organization.
- Every pull request against `main` gets a preview endpoint on the branch `flex/pull-<number>`, linked in a comment on the pull request. Use it to try the recipes in a project before merge.
