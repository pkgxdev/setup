#!/bin/bash
#FIXME ^^ ideally we'd be POSIX compliant

set -e

if test -n "$VERBOSE"; then
  set -x
fi

if test -z "$FORCE"; then
  if which tea >/dev/null; then
    #TODO should do a signature check on the binary
    exec tea "$@"
  fi
fi

######################################################################## vars
if test -z "$TEA_SECRET"; then
  echo "coming soon"
  exit
fi

OLDWD="$PWD"

if test -z "$PREFIX"; then
  PREFIX="$HOME/.tea"
fi

if test -z "$CURL"; then
  if which curl >/dev/null; then
    CURL="curl -fL"
  else
    # how they got here without curl: we dunno
    echo "you need curl, or you can set \`$CURL\`" >&2
    exit 1
  fi
fi

HW_TARGET=$(uname)/$(uname -m)

case $HW_TARGET in
Darwin/arm64)
  MIDFIX=darwin/aarch64;;
Darwin/x86_64)
  MIDFIX=darwin/x86-64;;
Linux/arm64)
  MIDFIX=linux/aarch64;;
Linux/x86_64)
  MIDFIX=linux/x86-64;;
*)
  echo "(currently) unsupported OS or architecture ($HW_TARGET)" >&2
  echo "open a discussion: https://github.com/teaxyz/cli/discussions" >&2
  exit 1;;
esac

##################################################################### confirm
echo "this script installs tea"
echo
echo "> tea installs to \`$PREFIX\`"
echo "> tea (itself) won’t touch files outside its prefix"
echo

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
cd "$PREFIX"
$CURL "https://$TEA_SECRET/tea.xyz/$MIDFIX/v$v.tar.gz" | tar xz

cd tea.xyz
ln -sf "v$v" v'*'
#TODO ^^ use tea to do this (also need major/minor symlinks)

################################################################# prep pantry
cd var

if test ! -e pantry; then
  if which git >/dev/null; then
    git clone https://github.com/teaxyz/pantry.git
  else
    $CURL https://github.com/teaxyz/pantry/archive/refs/heads/main.tar.gz | tar xz
    # tea itself will install `git` for pantry updates
  fi
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
