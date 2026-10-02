# sulu-recipes

Symfony Flex recipes for Sulu. `sulu/sulu` has no official Flex recipe, so this repo adds one for `sulu/sulu` 3.0. It also adds a recipe for `symfony-cmf/routing-bundle`, which has none, and supersedes the official recipes of seven packages whose files Sulu must own: `symfony/framework-bundle`, `symfony/security-bundle`, `symfony/console`, `symfony/twig-bundle`, `scheb/2fa-bundle`, `friendsofsymfony/jsrouting-bundle` and `doctrine/doctrine-bundle`.

## Usage

Start a project from the template [sulu-flex-skeleton](https://github.com/mario-fehr/sulu-flex-skeleton):

    composer create-project mario-fehr/sulu-flex-skeleton my-project --repository='{"type":"vcs","url":"https://github.com/mario-fehr/sulu-flex-skeleton"}'

The skeleton points Flex at this endpoint via `extra.symfony.endpoint` in `composer.json`:

```json
"extra": { "symfony": { "endpoint": ["https://raw.githubusercontent.com/mario-fehr/sulu-recipes/flex/main/index.json", "flex://defaults"] } }
```

The recipes assume the package set of `sulu/skeleton`. A bare `composer require sulu/sulu` in another project is not supported yet.

## Publishing

`.github/workflows/flex-update.yml` compiles the recipes into the `flex/main` branch on every push to `main`, but only after `qa.yml` has passed for that commit.

## Development

You need PHP 8.5, Composer, Docker and `jq`.

The test harness reads `sulu/skeleton` from `.references/sulu-skeleton`, so clone it there before running the harness (CI does the same):

    git clone https://github.com/sulu/skeleton.git .references/sulu-skeleton

- `tests/setup-tools.sh` installs the recipe checker.
- `tests/build-endpoint.sh` lints the recipes and compiles the endpoint into `output/`.
- `tests/install.sh` installs `sulu/sulu` into a fresh `symfony/skeleton` from that local endpoint.
- `tests/parity.sh` compares a `sulu-flex-skeleton` install with a `sulu/skeleton` install.

CI runs all of them in `.github/workflows/qa.yml`.

## License

MIT, see `LICENSE`.
