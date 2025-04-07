![pkgx](https://pkgx.dev/banner.png)

* This repository provides the `pkgx` GitHub Action.
* It also hosts [`installer.sh`](./installer.sh); the result of `curl pkgx.sh`.


# GitHub Action

```yaml
- uses: pkgxdev/setup@v3
```

Installs the latest version of `pkgx`.

> [!NOTE]
> * `v2` of this action defaults to pkgx^1
> * `v3` of this action defaults to pkgx^2

See [`action.yml`] for all inputs and outputs, but here’s the usual ones:

```yaml
- uses: pkgxdev/setup@v3
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

> See [`@pkgxdev/dev`] to run the `dev` command in a GitHub Actions compatible manner


## Should you Cache `~/.pkgx`?

No. pkgx packages are just tarballs. Caching is just a tarball. You’ll likely
just slow things down.

## Version History

* `v4` defaults to `pkgx`^2, uses node^20 and doesn’t install any pre-reqs on Linux†
* `v3` defaults to `pkgx`^2 and uses node^20
* `v2` defaults to `pkgx`^1 and uses node^20
* `v1` defaults to `pkgx`@latest and uses node^16
* `v0` should not be used

> † `pkgx` requires glibc>=2.28, libgcc, libstdc++ and libatomic. Generally
> images come installed with these. If you are building binaries you may need
> the `-dev` versions of these packages also.

&nbsp;


# The `pkgx` Installer

To install `pkgx`:

```sh
$ curl https://pkgx.sh | sh

# - installs `pkgx` & `pkgm` to `/usr/local/bin`
# - if both are already installed, does an update check
```

Or on Windows:

```ps1
$ irm https://pkgx.sh | iex
# - installs `pkgx.exe` to `$env:ProgramFiles/pkgx`
# - adds it to your system PATH
```

## Temporary Sandboxes

To use `pkgx` to run a command in a temporary sandbox:

```sh
$ curl -Ssf https://pkgx.sh | sh -s -- gum spin -- sleep 5

# - if pkgx is installed, uses that installation to run gum
# - if pkgx *isn’t* installed, downloads pkgx to a temporary location
# - if pkgx *isn’t* installed, packages are also cached to a temporary location
```

> This usage of our installer can be useful for demonstrative purposes in
> READMEs and gists.

This syntax is easier to remember:

```sh
sh <(curl -L pkgx.sh) gum spin -- sleep 5
```

> There is the **notable caveat** that the above easier syntax will not work with bash <4
> which is the bash that comes with macOS. Even though macOS has defaulted to
> zsh for years it is still relatively easy for users to end up in a situation
> where bash is the shell interpreting your commands. **Your call**.
>
> Additionally, use of `-L` is subject to man-in-the-middle attacks.
> Again **your call**.

[`action.yml`]: ./action.yml
[`@pkgxdev/dev`]: https://github.com/pkgxdev/dev
