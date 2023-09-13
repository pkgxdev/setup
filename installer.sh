#!/bin/sh

set -e

if test -n "$VERBOSE" -o -n "$GITHUB_ACTIONS" -a -n "$RUNNER_DEBUG"; then
  set -x
fi

if test -d /usr/local/bin -a ! -w /usr/local/bin; then
  SUDO="sudo"
elif test -d /usr/local -a ! -w /usr/local; then
  SUDO="sudo"
elif test -d /usr -a ! -w /usr; then
  SUDO="sudo"
fi

_install_tea() {
  if [ -z "$CI" ]; then
    PROGRESS="--progress-bar"
  fi

  curl $PROGRESS --compressed --fail --proto '=https' https://tea.xyz/$(uname)/$(uname -m) > "$1"/tea
  chmod +x "$1"/tea
}

_install_pre_reqs() {
  if test -f /etc/debian_version; then
    apt update --yes

    # minimal but required or networking doesn’t work
    # https://packages.debian.org/buster/all/netbase/filelist
    COMMON="netbase"

    # difficult to pkg in our opinion
    COMMON="libudev-dev $COMMON"

    case $(cat /etc/debian_version) in
    jessie/sid|8.*|stretch/sid|9.*)
      apt --yes install libc-dev libstdc++-4.8-dev libgcc-4.7-dev $COMMON;;
    buster/sid|10.*)
      apt --yes install libc-dev libstdc++-8-dev libgcc-8-dev $COMMON;;
    bullseye/sid|11.*)
      apt --yes install libc-dev libstdc++-10-dev libgcc-9-dev $COMMON;;
    bookworm/sid|12.*|*)
      apt --yes install libc-dev libstdc++-11-dev libgcc-11-dev $COMMON;;
    esac
  elif test -f /etc/fedora-release; then
    $SUDO yum --assumeyes install libatomic
  fi
}

_is_ci() {
  [ -n "$CI" ] && [ $CI != 0 ]
}

########################################################################### meat

if ! command -v tea >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"

  _install_tea "$tmpdir"

  if [ $# -eq 0 ]; then
    $SUDO sh -c "mkdir -p /usr/local/bin && mv $tmpdir/tea /usr/local/bin/tea"
    export PATH="/usr/local/bin:$PATH"  # just in case
  else
    export PATH="$tmpdir:$PATH"
  fi
fi

if _is_ci; then
  apt() {
    # we should use apt-get not apt in CI
    # weird shit ref: https://askubuntu.com/a/668859
    cmd=$1
    shift
    $SUDO apt-get $cmd -qq -o=Dpkg::Use-Pty=0 "$@"
  }
else
  apt() {
    case "$1" in
    update)
      echo "ensure you have the `tea` pre-requisites installed:" >&2
      echo >&2
      ;;
    install)
      echo "   apt-get" "$@" >&2
      ;;
    esac
  }
  yum() {
    echo "   yum" "$@" >&2
  }
  unset SUDO
fi

_install_pre_reqs

if [ $# -gt 0 ]; then
  exec tea "$@"
else
  # https://stackoverflow.com/a/28776166
  sourced=0
  if [ -n "$ZSH_VERSION" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
  elif [ -n "$KSH_VERSION" ]; then
    [ "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ] && sourced=1
  elif [ -n "$BASH_VERSION" ]; then
    (return 0 2>/dev/null) && sourced=1
  else # All other shells: examine $0 for known shell binary filenames.
    # Detects `sh` and `dash`; add additional shell filenames as needed.
    case ${0##*/} in sh|-sh|dash|-dash) sourced=1;; esac
  fi
  if [ $sourced = 1 ]; then
    eval "$(tea --shellcode)"
  elif ! _is_ci; then
    echo "now type: tea --help" >&2
  fi
fi
