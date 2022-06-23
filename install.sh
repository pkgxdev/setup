#!/bin/sh

set -e

if test -n "$VERBOSE"; then
  set -x
fi

if test "$1" = "--show" && test "$2" = "twitter"; then
  echo "https://twitter.com/teaxyz_"
elif test -n "$TEA_SECRET"; then
  # Hi, I know you’re excited but genuinely, pls wait for release
  # I added this so I can do CI :/
  case $(uname)-$(uname -m) in
  Darwin-arm64)
    MIDFIX=darwin/aarch64;;
  Darwin-x86_64)
    MIDFIX=darwin/x86-64;;
  Linux-x86_64)
    MIDFIX=linux/x86-64;;
  *)
    echo "unsupported OS or architecture" >&2
    exit 1;;
  esac

  if test ! -f /usr/local/bin/tea; then
    tmp=$(mktemp -t tea.XXXXXXX)
    curl --fail https://"$TEA_SECRET"/tea.xyz/$MIDFIX/v'*'.tar.gz -o "$tmp"
    sudo mkdir -p /opt
    # TODO: in Linux the answer is probably to chmod 777 /opt, unless it has a specific group
    # we can add our user to (which isn't `root`)
    sudo chgrp staff /opt
    sudo chmod g+w /opt
    cd /opt
    tar xzf "$tmp"
    cd tea.xyz
    if test ! -L v'*'; then
      ln -sf "$(find . -maxdepth 1 -type d -name "v[0-9].[0-9].[0-9]" | head -n 1)" v'*'
    fi

    sudo mkdir -p /usr/local/bin
    sudo ln -sf /opt/tea.xyz/v'*'/bin/tea /usr/local/bin/tea

    SHELLNAME=$(basename "$SHELL")
    if test "$SHELLNAME" = "fish"
    then
      {
        echo "if type -q tea"
        echo "  function __tea_env --on-variable PWD"
        echo "    eval (tea -Eds)"
        echo "  end"
        echo "end"
      } > ~/.config/fish/conf.d/tea.fish
    else
      {
        echo
        echo '# added by tea'
        echo 'add-zsh-hook -Uz chpwd (){ source <(tea -Eds) }'
      } >> ~/.zshrc
    fi
  fi

  if test "$#" -gt 1; then
    exec /usr/local/bin/tea "$@"
  fi
else
  curl -Ssf https://raw.githubusercontent.com/teaxyz/white-paper/main/white-paper.md | ${PAGER:-cat}
fi
