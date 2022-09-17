#!/bin/bash
#FIXME ^^ ideally we'd be POSIX compliant

set -e

if test -n "$VERBOSE"; then
  set -x
fi

######################################################################## vars
if test -z "$TEA_SECRET"; then
  echo "coming soon"
  exit
fi

OLDWD="$PWD"

if test -z "$PREFIX"; then
  # use existing installation if found
  if which tea >/dev/null 2>&1; then
    PREFIX="$(tea --prefix --silent)"
    ALREADY_INSTALLED=1
    YES=1
  fi
  # we check again: in case the above failed for some reason
  if test -z "$PREFIX"; then
    PREFIX="$HOME/.tea"
  fi
fi

if test -z "$CURL"; then
  if which curl >/dev/null 2>&1; then
    CURL="curl -fL"
  else
    # how they got here without curl: we dunno
    echo "you need curl, or you can set \`\$CURL\`" >&2
    exit 1
  fi
fi

HW_TARGET=$(uname)/$(uname -m)

case $HW_TARGET in
Darwin/arm64)
  MIDFIX=darwin/aarch64;;
Darwin/x86_64)
  MIDFIX=darwin/x86-64;;
Linux/arm64|Linux/aarch64)
  MIDFIX=linux/aarch64;;
Linux/x86_64)
  MIDFIX=linux/x86-64;;
*)
  echo "(currently) unsupported OS or architecture ($HW_TARGET)" >&2
  echo "open a discussion: https://github.com/teaxyz/cli/discussions" >&2
  exit 1;;
esac

##################################################################### confirm
if test -z "$ALREADY_INSTALLED"; then
  echo "this script installs tea"
  echo
  echo "> tea installs to \`$PREFIX\`"
  echo "> tea (itself) won’t touch files outside its prefix"
  echo
fi
if test -z "$YES"; then
  if [ ! -t 1 ]; then
    echo "no tty detected, re-run with \`YES=1\` set"
  fi

  read -n1 -s -r -p $'press the `t` key to continue…\n' key

  if [ "$key" != 't' ]; then
    echo "k, aborting"
    echo
    echo "> btw tea is a single executable you can easily install yourself"
    echo "> check out our github for instructions"
    echo
    exit
  fi

  echo
fi


####################################################################### fetch
v="$($CURL https://$TEA_SECRET/tea.xyz/$MIDFIX/versions.txt | tail -n1)"

mkdir -p "$PREFIX"/tea.xyz/var
cd "$PREFIX"/tea.xyz

function link {
  if test -L v$1; then
    rm -f v$1
  elif test -d v$1; then
    echo "\`v$1' is unexpectedly a directory"
  fi
  ln -s "v$v" v$1
}

if test ! -x tea.xyz/v$v/bin/tea -o ! -f tea.xyz/v$v/bin/tea -o -n "$FORCE"; then
  $CURL "https://$TEA_SECRET/tea.xyz/$MIDFIX/v$v.tar.gz" | tar xz --strip-components 1
  if ! test -d v\*; then
    # if v* is a directory then this is a self-installed source distribution
    # in that case we don’t do this symlink
    link \*
  fi
  link "$(echo $v | cut -d. -f1)"
  link "$(echo $v | cut -d. -f1 -f2)"
fi


################################################################# prep pantry
cd var

function update_pantry {
  #NOTE pretty nasty global mods here
  export GIT_DIR=$PWD/pantry/.git
  export GIT_WORK_TREE=$PWD/pantry

  test -z "$(git status --porcelain)" || return 0
  if ! git diff --quiet; then return 0; fi
  test "$(git branch --show-current)" = main || return 0

  git remote update

  local BASE LOCAL
  BASE="$(git merge-base @ '@{u}')"
  LOCAL="$(git rev-parse @)"
  if test "$BASE" = "$LOCAL"; then
    git pull
  fi

  unset GIT_DIR GIT_WORK_TREE
}

#TODO could use a tea installed git

if test ! -d pantry; then
  if which git >/dev/null 2>&1; then
    git clone https://github.com/teaxyz/pantry.git
  else
    #NOTE **fails** because the repo is still private
    $CURL https://github.com/teaxyz/pantry/archive/refs/heads/main.tar.gz | tar xz
    # tea itself will install `git` for pantry updates
  fi
elif which git >/dev/null 2>&1; then
  update_pantry
fi

###################################################################### finish
tea="$PREFIX/tea.xyz/v$v/bin/tea"

if test "$#" -gt 0; then
  # indeed, we only install `tea` into the `PATH` for the bare install line
  cd "$OLDWD"
  exec "$tea" "$@"
else
  # TODO do this automatically if we can write to `/usr/local/bin`
  echo
  echo "the final step is down to you:"
  echo "    sudo ln -s $tea /usr/local/bin/tea"
  # TODO or prompt them to add a line to their .zshrc
fi
