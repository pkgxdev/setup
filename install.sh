#!/bin/sh

set -e

if [ -n "$VERBOSE" ]; then
  set -x
fi

if [ "$1" = "--show" ] && [ $2 = "twitter" ]; then
  echo "https://twitter.com/teaxyz_"
elif [ -n "$TEA_SECRET" ]; then
  # Hi, I know you’re excited but genuinely, pls wait for release
  # I added this so I can do CI :/
  case $(uname) in
  Darwin)
    MIDFIX=darwin/aarch64;;
  *)
      echo "unsupported OS or architecture" >&2
      exit 1;;
  esac

  if [ ! -f /usr/local/bin/tea ]; then
    tmp=$(mktemp)
    curl https://$TEA_SECRET/tea.xyz/$MIDFIX/tea -o $tmp
    sudo mkdir -p /usr/local/bin
    sudo mv $tmp /usr/local/bin/tea
    sudo chmod u+x /usr/local/bin/tea
    sudo mkdir -p /opt
    sudo chgrp staff /opt
    sudo chmod g+w /opt
  fi

  if [ "$#" -gt 1 ]; then
    exec /usr/local/bin/tea "$@"
  fi
else
  echo
  echo "418 I’m a teapot"
  echo
  echo "thanks for your interest in tea."
  echo "alas, we’re not quite ready to serve you yet."
  echo
  echo "while you wait why not follow us on Twitter:"
  echo
  echo '    open $(sh <(curl tea.xyz) --show twitter)'
  echo
fi
