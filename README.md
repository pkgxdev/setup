![tea](https://tea.xyz/banner.png)

[`install.sh`](./install.sh) is delivered when you `curl tea.xyz`.

# GitHub Action 0.8.0

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

* `sh <(curl tea.xyz) --yes` assumes affirmative for all prompts
* `sh <(curl tea.xyz) --prefix foo` change install location
* `sh <(curl tea.xyz) --version 1.2.3` install a specific version


## Via GitHub Actions

```yaml
- uses: teaxyz/setup@v0
  with:
    target: build
```

Is the equivalent of `tea build`, ie. runs the executable markdown from your
project’s README for the `# build` section. Of course we install your
dependencies first.

There is no need to specify a target, `- uses: teaxyz/setup@v0` by itself
installs your deps and exports some variables like `VERSION`. See [`action.yml`]
for all inputs and outputs.

[action.yml]: ../../action.yml

### Interesting Usages

At tea, we consider the version in the `README` the definitive version.
Thus we use GitHub Actions to automatically tag and publish that version when
the README is edited and the version changes.

See our CI scripts for details.


# Test

```sh
node --check ./action.js
```

## Dependencies

|   Project   | Version |
|-------------|---------|
| nodejs.org  | ^16     |


[`action.yml`]: ./action.yml
