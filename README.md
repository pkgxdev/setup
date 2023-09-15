![tea](https://tea.xyz/banner.png)

* This repository provides the `tea` GitHub Action.
* It also hosts [`installer.sh`](./installer.sh); the result of `curl tea.xyz`.


# GitHub Action

```yaml
- uses: teaxyz/setup@v1
```

Installs the latest version of `tea`.

See [`action.yml`] for all inputs and outputs, but here’s the usual ones:

```yaml
- uses: teaxyz/setup@v1
  with:
    +: deno@1.30 rust@1.60
```

## Shell Integration

We cannot integrate with the GitHub Actions shell. But you probably don’t
need it.

## Should you Cache `~/.tea`?

No. tea packages are just tarballs. Caching is just a tarball. You’ll likely
just slow things down.

&nbsp;


# `tea` Installer

To install tea:

```sh
$ curl https://tea.xyz | sh

# - installs to `/usr/local/bin/tea`
# - if tea is already installed it’s a noop
```

To use `tea` to run a command in a temporary sandbox:

```sh
$ curl -Ssf https://tea.xyz | sh -s -- gum spin -- sleep 5

# - if tea is installed, uses that installation to run gum
# - if tea is *not* installed, downloads tea to a temporary location
# - packages are still cached in `~/.tea` but tea itself is not installed
```

This syntax is easier to remember:

```sh
sh <(curl tea.xyz) gum spin -- sleep 5
```

> There is the **notable caveat** that it will not work with bash <4
> which is the bash that comes with macOS. Even though macOS has defaulted to
> zsh for years it is still relatively easy for users to end up in a situation
> where bash is the shell interpreting your commands. Your call.

[`action.yml`]: ./action.yml
[tea.xyz]: https://tea.xyz
