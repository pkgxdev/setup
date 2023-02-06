![tea](https://tea.xyz/banner.png)

* [`install.sh`](./install.sh) is delivered when you `curl tea.xyz`.
* This repository also provides the `tea` GitHub Action.


# `- uses: teaxyz/setup@v0` 0.14.0

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

We cannot install our shell magic into GitHub Actions. So unless you manually
add a package with `+:` you will need to ensure it is called with a `tea`
prefix, eg. `tea npx`.

## Interesting Usages

At tea, we consider the version in the `README` the definitive version.
Thus we use GitHub Actions to automatically tag and publish that version when
the README is edited and the version changes.

See our CI scripts for details.



# `sh <(curl tea.xyz)`

To install tea:

```sh
$ sh <(curl tea.xyz)

# - installs to `~/.tea`
# - if tea is already installed, the script instead checks for updates
```

To use tea to run a command in a temporary sandbox:

```sh
$ sh <(curl -Ssf tea.xyz) gum spin -- sleep 5

# - if tea is installed, uses that installation to run gum
# - if tea is *not* installed, downloads gum and its deps to a safe and
#   temporary location and executes the command
```

> NOTE we omit `https://` for clarity, *please* include it in all your usages.

## Options

* `sh <(curl tea.xyz) --yes` assumes affirmative for all prompts
* `sh <(curl tea.xyz) --prefix foo` change install location (you can use this option to force a re-install)
* `sh <(curl tea.xyz) --version 1.2.3` install a specific version of tea



&nbsp;

# Tasks

## Check

Run this with `xc check`.

```sh
node --check ./action.js
```


[`action.yml`]: ./action.yml
[tea.xyz]: https://tea.xyz
