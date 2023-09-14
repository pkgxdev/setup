![tea](https://tea.xyz/banner.png)

* [`installer.sh`](./installer.sh) is delivered when you `curl tea.xyz`.
* This repository also provides the `tea` GitHub Action.

# GitHub Action 0.18.3

```yaml
- uses: teaxyz/setup@v0
```

Installs tea, your dependencies (computed from your developer environment),
adds your deps to `PATH` and exports some other *tea’ish* variables like
`VERSION`.

See [`action.yml`] for all inputs and outputs, but here’s the usual ones:

```yaml
- uses: teaxyz/setup@v0
  with:
    +: |
      deno.land^1.30
      rust-lang.org^1.60
```

Our packages are named after their homepages, to see what is available you
can browse the pantry on our website:
[tea.xyz] (we agree this isn’t great UX)

## Magic

We cannot install our shell magic into GitHub Actions. So unless your dev-env
includes the package or you manually add the package with `+:` you will need
to ensure it is called with a `tea` prefix, eg. `tea npx`.

## Should you Cache `~/.tea`?

No. tea packages are just tarballs. Caching is just a tarball. You’ll likely
just slow things down.

## Interesting Usages

At tea, we consider the version in the `README` the definitive version.
Thus we use GitHub Actions to automatically tag and publish that version when
the README is edited and the version changes.

See our CI scripts for details.



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
