![tea](https://tea.xyz/banner.png)

[`install.sh`](./install.sh) is delivered when you `curl tea.xyz`.

# GitHub Action 0.12.2

This repository also provides the `tea` GitHub Action.

```yaml
- uses: teaxyz/setup@v0
```


# Usage

## Via Terminal

```sh
sh <(curl tea.xyz)

# - installs to `~/.tea`
# - if tea is already installed, the script instead checks for updates
```

```sh
sh <(curl -Ssf tea.xyz) gum spin -- sleep 5

# - if tea is installed, uses that installation to run gum
# - if tea is *not* installed, downloads gum and its deps to a safe and
#   temporary location and executes the command
```

> NOTE we omit `https://` for clarity, *please* include it in all your usages.

### Options

* `sh <(curl tea.xyz) --yes` assumes affirmative for all prompts
* `sh <(curl tea.xyz) --prefix foo` change install location (you can use this option to force a re-install)
* `sh <(curl tea.xyz) --version 1.2.3` install a specific version of tea


## Via GitHub Actions

```yaml
- uses: teaxyz/setup@v0
```

Installs tea, your dependencies (listed in your `README.md`), adds your deps
to `PATH` and exports some other *tea’ish* variables like `VERSION`.

See [`action.yml`] for all inputs and outputs.

> NOTE: we cannot install our shell magic, so if eg. `npx` is not listed in
> your dependencies you will need to invoke it as `tea npx` to use it.

### Interesting Usages

At tea, we consider the version in the `README` the definitive version.
Thus we use GitHub Actions to automatically tag and publish that version when
the README is edited and the version changes.

See our CI scripts for details.


# Tasks

## Test

```sh
node --check ./action.js
```

[`action.yml`]: ./action.yml
