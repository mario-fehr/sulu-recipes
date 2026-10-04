# Updating recipes

Recipes moved between packages in this repository. A project installed with an older version of these recipes needs the steps below; a new project does not. In every `composer recipes:install` command, leave out packages your project does not install, because `recipes:install` installs nothing if one listed package is missing. After every command with `--force`, review the diff, since `--force` rewrites the recipe files of those packages.

## `sulu/sulu`, `symfony/twig-bundle` and `symfony/security-bundle`

`templates/base.html.twig` and `config/packages/security.yaml` moved from the `symfony/twig-bundle` and `symfony/security-bundle` recipes into the `sulu/sulu` recipe, so they can differ between Sulu 2.6 and 3.0.

Run `composer recipes:update sulu/sulu` first, then `symfony/twig-bundle` and `symfony/security-bundle`. The `sulu/sulu` update adds `base.html.twig` and `security.yaml` as new recipe files over the existing ones. If a project's copy differs from the recipe's (for example the 2FA lines in `security.yaml`), Flex reports the update "with conflicts" and leaves conflict markers in that file. Resolve them by keeping the project's content.

The `symfony/twig-bundle` and `symfony/security-bundle` updates then keep those files, because `sulu/sulu` now lists them. Flex only warns that another recipe still references them. In the other order, Flex removes both files (a staged `git rm`), and `git restore --staged --worktree <file>` brings them back.

## 2FA and the web profiler

The 2FA config (the `two_factor` firewall block and the `^/admin/2fa` access rule) moved from the `symfony/security-bundle` recipe to the add-lines of the `scheb/2fa-bundle` recipe. The `email` and `trusted_device` options moved from `config/packages/scheb_2fa.yaml` of `scheb/2fa-bundle` into `config/packages/scheb_2fa_email.yaml` and `config/packages/scheb_2fa_trusted_device.yaml`, which the new `scheb/2fa-email` and `scheb/2fa-trusted-device` recipes ship.

`config/routes/web_profiler_admin.yaml` moved from `sulu/sulu` to `symfony/web-profiler-bundle`, so `composer recipes:update sulu/sulu` removes the admin profiler routes.

After the updates in the previous section, run:

```bash
composer recipes:install scheb/2fa-bundle scheb/2fa-email scheb/2fa-trusted-device symfony/web-profiler-bundle --force
```

`composer recipes:update scheb/2fa-bundle` removes the `email` and `trusted_device` blocks from `scheb_2fa.yaml`. Both options stay off until the `scheb/2fa-email` and `scheb/2fa-trusted-device` recipes are installed (the command above). If `scheb_2fa.yaml` still has both blocks when you install them, the same values are set twice and Symfony merges them. Remove the blocks anyway: if you later remove `scheb/2fa-email`, a leftover `email` block fails the boot with `Unrecognized options`.

## Tooling

The tooling configs moved from the `sulu/sulu` recipe into the recipes of the tool packages. `composer recipes:update sulu/sulu` stages the deletion of `rector.php`, `tests/rector/` and `.twig-cs-fixer.dist.php`, even if your project changed them. To keep them, run `git restore --staged --worktree rector.php .twig-cs-fixer.dist.php tests/rector`. Then apply the new recipes, which keep existing files and add the `tests/phpstan/` stubs:

```bash
composer recipes:install rector/rector phpstan/phpstan-doctrine phpstan/phpstan-symfony phpstan/extension-installer
```

To replace the official `phpstan.dist.neon` and `.php-cs-fixer.dist.php` with Sulu's, run the command below. `.twig-cs-fixer.dist.php` already is Sulu's file. `vincentlanglet/twig-cs-fixer` is in the command only to switch its `symfony.lock` entry to this repository and add `/.twig-cs-fixer.php` to `.gitignore`. `--force` also rewrites the restored `.twig-cs-fixer.dist.php`, so take your changes back with `git checkout -p`.

```bash
composer recipes:install phpstan/phpstan php-cs-fixer/shim vincentlanglet/twig-cs-fixer --force
```

The recipes add the phpstan settings in `phpstan.dist.neon` and the `withPHPStanConfigs` call in `rector.php` as blocks. If you change a line inside one of these blocks, a later `recipes:install` or `recipes:update` of the phpstan or rector packages adds the block a second time; remove the duplicate.

## `phpunit/phpunit` and `.env.test`

In an existing 3.0 project, `composer recipes:update sulu/sulu` leaves `.env.test` and its `###> sulu/sulu ###` block with `SEAL_DSN=memory://` as they are, and tests keep working. `composer recipes:install phpunit/phpunit --force` switches to this repository's `phpunit/phpunit` recipe and rewrites `.env.test` (as in `sulu/skeleton`), `bin/phpunit` and `tests/bootstrap.php`. `composer recipes:update phpunit/phpunit` does not work for this switch.
