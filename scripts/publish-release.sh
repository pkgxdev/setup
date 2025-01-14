#!/usr/bin/env -S pkgx +bun +gum bash -eo pipefail

cd "$(dirname "$0")"/..

if ! git diff-index --quiet HEAD --; then
  echo "error: dirty working tree" >&2
  exit 1
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != main ]; then
  echo "error: requires main branch" >&2
  exit 1
fi

if test "$VERBOSE"; then
  set -x
fi

# ensure we have the latest version tags
git fetch origin -pft

# ensure github tags the right release
git push origin main

versions="$(git tag | grep '^v[0-9]\+\.[0-9]\+\.[0-9]\+')"
v_latest="$(bunx -- semver --include-prerelease $versions | tail -n1)"

case $1 in
major|minor|patch|prerelease)
  v_new=$(bunx -- semver bump $v_latest --increment $1)
  ;;
"")
  echo "usage $0 <major|minor|patch|prerelease|VERSION>" >&2
  exit 1;;
*)
  if test "$(bunx -- semver """$1""")" != "$1"; then
    echo "$1 doesn't look like valid semver."
    exit 1
  fi
  v_new=$1
  ;;
esac

if [ $v_new = $v_latest ]; then
  echo "$v_new already exists!" >&2
  exit 1
fi

if ! gh release view v$v_new >/dev/null 2>&1; then
  gum confirm "prepare draft release for $v_new?" || exit 1

  gh release create \
    v$v_new \
    --draft=true \
    --generate-notes \
    --notes-start-tag=v$v_latest \
    --title=v$v_new
else
  gum format "> existing $v_new release found, using that"
  echo  #spacer
fi


gh workflow run cd.yml --raw-field version="$v_new"
# ^^ infuriatingly does not tell us the ID of the run

gum spin --title 'sleeping 5s because GitHub API is slow' -- sleep 5

run_id=$(gh run list --json databaseId --workflow=cd.yml | jq '.[0].databaseId')

if ! gh run watch --exit-status $run_id; then
  foo=$?
  gum format -- "> gh run view --web $run_id"
  exit $foo
fi

gh release upload --clobber v$v_new ./installer.sh

gh release view v$v_new

gum confirm "draft prepared, release $v_new?" || exit 1

node run dist
git add ./action.js
git commit --message $v_new
git tag $v_new
git push origin $v_new

gh release edit \
  v$v_new \
  --verify-tag \
  --latest \
  --draft=false
