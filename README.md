# sulu-recipes

> [!WARNING]
> This project is in heavy development. The recipes, the file layout and the behavior may still change without notice, and it is not ready for production use.

Symfony Flex recipes for Sulu. `sulu/sulu` has no official Flex recipe, so this repo adds recipes for `sulu/sulu` 2.6 and 3.0. It also adds a recipe for `symfony-cmf/routing-bundle`, which has none, and supersedes the official recipes of ten packages whose files Sulu must own: `symfony/framework-bundle`, `symfony/security-bundle`, `symfony/console`, `symfony/twig-bundle`, `symfony/web-profiler-bundle`, `scheb/2fa-bundle`, `friendsofsymfony/jsrouting-bundle`, `doctrine/doctrine-bundle`, `doctrine/phpcr-bundle` and `symfony/form`.

## Usage

Start a project from the template [sulu-flex-skeleton](https://github.com/mario-fehr/sulu-flex-skeleton):

    composer create-project mario-fehr/sulu-flex-skeleton my-project --repository='{"type":"vcs","url":"https://github.com/mario-fehr/sulu-flex-skeleton"}'

One endpoint serves both lines, and the installed Sulu version picks the recipe. With `sulu-flex-skeleton`, the branch `2.6` or `3.0` selects the line. For 2.6, use the same command with the `--repository` option and `mario-fehr/sulu-flex-skeleton:2.6.x-dev` as the package.

The `symfony/form` recipe here comes from Sulu 2.6, so a 3.0 project that requires `symfony/form` gets a `config/packages/csrf.yaml` with every line commented out instead of the official one that enables stateless CSRF protection; uncomment it if the project wants that.

The skeleton points Flex at this endpoint via `extra.symfony.endpoint` in `composer.json`:

```json
"extra": { "symfony": { "endpoint": ["https://raw.githubusercontent.com/mario-fehr/sulu-recipes/flex/main/index.json", "flex://defaults"] } }
```

### Bare install

You can also start from a plain `symfony/skeleton` instead of `sulu-flex-skeleton`. This is tested with `symfony/skeleton` 7.4 and 8.1.

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

For Sulu 2.6, use only `symfony/skeleton:7.4.*`. Instead of the two SEAL lines, run the command below, and skip the `--dev` step. Then run `bin/adminconsole sulu:admin:update-build` as for 3.0.

```bash
composer require sulu/sulu:~2.6.0 jackalope/jackalope-doctrine-dbal handcraftedinthealps/zendsearch
```

Sulu 2.6 needs a PHPCR transport, or Composer cannot resolve `sulu/sulu`. `zendsearch` backs the default search adapter.

`--no-install` matters: Flex applies a recipe only when it installs the package, and `symfony/skeleton` already contains `symfony/framework-bundle` and `symfony/console`. Their recipes (Sulu's kernel, `bin/console`) must come from this endpoint, so the endpoint has to be set before the first `composer install`. For the same reason the bare install does not work for an existing project.

It needs `doctrine/doctrine-bundle` 2.13 or newer. A fresh project gets the newest version. A `doctrine/doctrine-bundle` below 2.13 installed together with `sulu/sulu` gets no Doctrine recipe from this endpoint.

### Updating recipes

Two recipe moves affect existing projects. The 2FA config (the `two_factor` firewall block and the `^/admin/2fa` access rule) moved from the `symfony/security-bundle` recipe to the add-lines of the `scheb/2fa-bundle` recipe. `templates/base.html.twig` and `config/packages/security.yaml` moved from the `symfony/twig-bundle` and `symfony/security-bundle` recipes into the `sulu/sulu` recipe, so they can differ between Sulu 2.6 and 3.0. Also, `config/routes/web_profiler_admin.yaml` moved from `sulu/sulu` to `symfony/web-profiler-bundle`, so `composer recipes:update sulu/sulu` removes the admin profiler routes.

Run `composer recipes:update sulu/sulu` first, then `symfony/twig-bundle` and `symfony/security-bundle`. The `sulu/sulu` update adds `base.html.twig` and `security.yaml` as new recipe files over the existing ones. If a project's copy differs from the recipe's (for example the 2FA lines in `security.yaml`), Flex reports the update "with conflicts" and leaves conflict markers in that file; resolve them by keeping the project's content. The `symfony/twig-bundle` and `symfony/security-bundle` updates then keep those files, because `sulu/sulu` now lists them; Flex only warns that another recipe still references them. In the other order, Flex removes both files (a staged `git rm`), and `git restore --staged --worktree <file>` brings them back.

After updating either recipe, run the command below. `--force` rewrites those packages' recipe files, so review the diff afterwards.

```bash
composer recipes:install scheb/2fa-bundle symfony/web-profiler-bundle --force
```

## Publishing

`.github/workflows/flex-update.yml` compiles the recipes into the `flex/main` branch on every push to `main`, but only after `qa.yml` has passed for that commit.

## Development

You need PHP 8.5, Composer, Docker and `jq`. `CONTRIBUTING.md` shows how to change a recipe and check it locally. `docs/scripts.md` describes every script, variable and file of the harness, and `docs/maintaining.md` has the maintainer runbooks. CI runs the checks in `.github/workflows/qa.yml`.

## License

MIT, see `LICENSE`.
