![pkgx](https://pkgx.dev/banner.png)

* This repository provides the `pkgx` GitHub Action.
* It also hosts [`installer.sh`](./installer.sh); the result of `curl pkgx.sh`.


# GitHub Action

```yaml
- uses: pkgxdev/setup@v1
```

Installs the latest version of `pkgx`.

See [`action.yml`] for all inputs and outputs, but here’s the usual ones:

```yaml
- uses: pkgxdev/setup@v1
  with:
    +: deno@1.30
       rust@1.60   # we understand colloquial names, generally just type what you know
       clang       # versions aren’t necessary if you don’t care
```

The easiest way to know if it will work in the action is to try it locally on your computer:

```
$ pkgx +rust
# if there’s output, we got it
```

### Shell Integration

We cannot integrate with the GitHub Actions shell. But you probably don’t
need it.

### Should you Cache `~/.pkgx`?

No. pkgx packages are just tarballs. Caching is just a tarball. You’ll likely
just slow things down.

&nbsp;


# `pkgx` Installer

To install `pkgx`:

```sh
$ curl https://pkgx.sh | sh

# - installs to `/usr/local/bin/pkgx`
# - if pkgx is already installed it’s a noop
```

To use `pkgx` to run a command in a temporary sandbox:

```sh
$ curl -Ssf https://pkgx.sh | sh -s -- gum spin -- sleep 5

# - if pkgx is installed, uses that installation to run gum
# - if pkgx is *not* installed, downloads pkgx to a temporary location
# - packages are still cached in `~/.pkgx` but pkgx itself is not installed
```

This syntax is easier to remember:

```sh
sh <(curl -L pkgx.sh) gum spin -- sleep 5
```

> There is the **notable caveat** that it will not work with bash <4
> which is the bash that comes with macOS. Even though macOS has defaulted to
> zsh for years it is still relatively easy for users to end up in a situation
> where bash is the shell interpreting your commands. Your call.

[`action.yml`]: ./action.yml
