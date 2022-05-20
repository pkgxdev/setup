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

    echo '# added by tea' >> ~/.zshrc
    echo 'add-zsh-hook -Uz chpwd (){ source <(tea -Eds) }' >> ~/.zshrc
  fi

  if [ "$#" -gt 1 ]; then
    exec /usr/local/bin/tea "$@"
  fi
else
  if [ "x$PAGER" == "x" ]; then
    PAGER=cat
  fi
  curl -Ssf https://raw.githubusercontent.com/teaxyz/white-paper/main/white-paper.md | $PAGER
fi
