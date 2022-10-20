![tea](https://tea.xyz/banner.png)

[`install.sh`](./install.sh) is delivered when you `curl tea.xyz`.

# GitHub Action 0.6.0

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
sh <(curl tea.xyz) +charm.sh/gum gum spin -- sleep 5

# - if tea is installed, uses that installation to run gum
# - if tea is *not* installed, downloads gum and its deps to a safe and
#   temporary location and executes the command
```

### Options

* `YES=1`, for headless environments, assumes affirmative for all prompts
* `TEA_PREFIX=/path` change install location


## Via GitHub Actions

```yaml
- use: teaxyz/setup@v0
  with:
    target: build
```

Is the equivalent of `tea build`, ie. runs the executable markdown from your project’s README for the `# build` section. Of course we
install your dependencies first.


# Test

```sh
node --check ./action.js
```
