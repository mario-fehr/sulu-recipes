# sulu-recipes

> [!WARNING]
> This project is in heavy development. The recipes, the file layout and the behavior may still change without notice, and it is not ready for production use.

Symfony Flex recipes for Sulu 2.6 and 3.0. `sulu/sulu` has no official Flex recipe, and Sulu has to own files that the official recipes of other packages create. This repository therefore serves its own Flex endpoint.

The endpoint adds recipes for packages that have none:

- `sulu/sulu`
- `symfony-cmf/routing-bundle`
- `phpstan/phpstan-doctrine`, `phpstan/phpstan-symfony`, `phpstan/extension-installer`
- `rector/rector`
- `cmsig/seal-memory-adapter`
- `scheb/2fa-email`, `scheb/2fa-trusted-device`

It also supersedes the official recipes of fourteen packages:

- `symfony/framework-bundle`, `symfony/console`, `symfony/security-bundle`, `symfony/twig-bundle`, `symfony/web-profiler-bundle`, `symfony/form`
- `doctrine/doctrine-bundle`, `doctrine/phpcr-bundle`
- `scheb/2fa-bundle`
- `friendsofsymfony/jsrouting-bundle`
- `phpstan/phpstan`, `php-cs-fixer/shim`, `vincentlanglet/twig-cs-fixer`, `phpunit/phpunit`

## Getting started

### New project from sulu-flex-skeleton

Start a project from the template [sulu-flex-skeleton](https://github.com/mario-fehr/sulu-flex-skeleton):

    composer create-project mario-fehr/sulu-flex-skeleton my-project --repository='{"type":"vcs","url":"https://github.com/mario-fehr/sulu-flex-skeleton"}'

The branch `2.6` or `3.0` of `sulu-flex-skeleton` selects the line. For 2.6, use the same command with the `--repository` option and `mario-fehr/sulu-flex-skeleton:2.6.x-dev` as the package.

### Bare install from symfony/skeleton

A plain `symfony/skeleton` works as a starting point too, tested with `symfony/skeleton` 7.4 and 8.1. CI also installs the oldest patch release of each line that Composer will install, together with the newest versions of all other dependencies; Composer currently blocks older releases because of security advisories.

```bash
composer create-project symfony/skeleton:7.4.* my-project --no-install   # or 8.1.*
cd my-project
composer config extra.symfony.endpoint --json '["https://raw.githubusercontent.com/mario-fehr/sulu-recipes/flex/main/index.json", "flex://defaults"]'
composer config extra.symfony.allow-contrib true
composer install
composer require sulu/sulu:~3.0.0 cmsig/seal-loupe-adapter
composer require --dev cmsig/seal-memory-adapter
bin/adminconsole sulu:admin:update-build
```

For Sulu 2.6, use only `symfony/skeleton:7.4.*`, run the command below instead of the two SEAL lines, and skip the `--dev` step. Then run `bin/adminconsole sulu:admin:update-build` as for 3.0.

```bash
composer require sulu/sulu:~2.6.0 jackalope/jackalope-doctrine-dbal handcraftedinthealps/zendsearch
```

Notes:

- `--no-install` matters: Flex applies a recipe only when it installs the package, and `symfony/skeleton` already contains `symfony/framework-bundle` and `symfony/console`. Their recipes (Sulu's kernel, `bin/console`) must come from this endpoint, so set the endpoint before the first `composer install`.
- Sulu 2.6 needs a PHPCR transport, or Composer cannot resolve `sulu/sulu`. `zendsearch` backs the default search adapter.
- `sulu/sulu` 2.6 and 3.0.8 allow `friendsofsymfony/jsrouting-bundle` below 3.6, which lacks the `routing.php` the recipe's admin routes import. Such a project needs `jsrouting-bundle` 3.6 or newer (Composer installs it unless dependencies are pinned lower).
- The `stage` environment (`.env.stage`) needs `symfony/monolog-bundle`; without it, `APP_ENV=stage` fails with `Container extension "monolog" is not registered`.

### Existing Symfony project

Start a new project from `sulu-flex-skeleton` and move your existing code into it. Flex applies a recipe only when it installs the package, and in an existing project the packages Sulu's recipes replace (`symfony/framework-bundle`, `symfony/console`, `symfony/security-bundle`, `doctrine/doctrine-bundle` and others) are already installed, so the recipes would have to overwrite files you have usually changed: the kernel, the front controller, the console, the security and Doctrine config, `.env` and `compose.yaml`. Sulu describes the same approach in [Adding Sulu CMS to an existing Symfony project](https://sulu.io/blog/adding-sulu-cms-to-an-existing-symfony-project).

## Updating recipes

Some recipes moved between packages. A project installed with an older version of these recipes needs the manual steps in [docs/updating.md](docs/updating.md).

## Endpoint

One endpoint serves both lines; the installed Sulu version picks the recipe. A project points Flex at it through `extra.symfony.endpoint` in `composer.json`, as `sulu-flex-skeleton` already does:

```json
"extra": { "symfony": { "endpoint": ["https://raw.githubusercontent.com/mario-fehr/sulu-recipes/flex/main/index.json", "flex://defaults"] } }
```

On every push to `main`, `.github/workflows/flex-update.yml` compiles the recipes into the `flex/main` branch, but only after `qa.yml` has passed for that commit.

## Differences from the official recipes

The `symfony/form` recipe here comes from Sulu 2.6, so a 3.0 project that requires `symfony/form` gets a `config/packages/csrf.yaml` with every line commented out instead of the official one that enables stateless CSRF protection; uncomment it if the project wants that.

## Development

You need PHP 8.5, Composer, Docker and `jq`. `CONTRIBUTING.md` shows how to change a recipe and check it locally. `docs/scripts.md` describes every script, variable and file of the harness, and `docs/maintaining.md` has the maintainer runbooks. CI runs the checks in `.github/workflows/qa.yml`.

## License

MIT, see `LICENSE`.
