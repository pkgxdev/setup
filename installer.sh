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

_install_pre_reqs() {
  if test -f /etc/debian_version; then
    apt update --yes

    # minimal but required or networking doesn’t work
    # https://packages.debian.org/buster/all/netbase/filelist
    A=netbase

    # difficult to pkg in our opinion
    B=libudev-dev

    case $(cat /etc/debian_version) in
    jessie/sid|8.*|stretch/sid|9.*)
      apt --yes install libc-dev libstdc++-4.8-dev libgcc-4.7-dev $A $B;;
    buster/sid|10.*)
      apt --yes install libc-dev libstdc++-8-dev libgcc-8-dev $A $B;;
    bullseye/sid|11.*)
      apt --yes install libc-dev libstdc++-10-dev libgcc-9-dev $A $B;;
    bookworm/sid|12.*|*)
      apt --yes install libc-dev libstdc++-11-dev libgcc-11-dev $A $B;;
    esac
  elif test -f /etc/fedora-release; then
    $SUDO yum --assumeyes install libatomic
  fi
}

_is_ci() {
  [ -n "$CI" ] && [ $CI != 0 ]
}

_install_pkgx() {
  if _is_ci; then
    progress="--no-progress-meter"
  else
    progress="--progress-bar"
  fi

  tmpdir=$(mktemp -d)

  if [ $# -eq 0 ]; then
    echo "Installing: /usr/local/bin/pkgx" >&2

    # using a named pipe to prevent curl progress output trumping the sudo password prompt
    pipe="$tmpdir/pipe"
    mkfifo "$pipe"

    curl $progress --fail --proto '=https' "https://pkgx.sh/$(uname)/$(uname -m)".tgz > "$pipe" &
    $SUDO sh -c "
      mkdir -p /usr/local/bin
      tar xz --directory /usr/local/bin < '$pipe'
    " &
    wait

    rm -r "$tmpdir"

    export PATH="/usr/local/bin:$PATH"  # just in case
  else
    curl $progress --fail --proto '=https' \
        "https://pkgx.sh/$(uname)/$(uname -m)".tgz \
      | tar xz --directory "$tmpdir"

    export PATH="$tmpdir:$PATH"
  fi

  unset tmpdir pipe
}

_should_install_pkgx() {
  if ! command -v pkgx >/dev/null 2>&1; then
    return 0
  elif [ $(/usr/bin/which pkgx) != /usr/local/bin/pkgx ]; then
    # if pkgx is not installed to /usr/local/bin then we’re not getting involved
    return 1
  fi

  # if the installed version is less than the available version then upgrade
  pkgx --silent semverator lt \
    $(curl -Ssf https://pkgx.sh/VERSION) \
    $(/usr/local/bin/pkgx --version | awk '{print $2}') >/dev/null 2>&1
}

########################################################################### meat

if _should_install_pkgx; then
  _install_pkgx "$@"
fi

if _is_ci; then
  apt() {
    # we should use apt-get not apt in CI
    # weird shit ref: https://askubuntu.com/a/668859
    export DEBIAN_FRONTEND=noninteractive
    cmd=$1
    shift
    $SUDO apt-get $cmd -qq -o=Dpkg::Use-Pty=0 $@
  }
else
  apt() {
    case "$1" in
    update)
      echo "ensure you have the `pkgx` pre-requisites installed:" >&2
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
  pkgx "$@"
elif [ $(basename "/$0") != 'installer.sh' ]; then
  # ^^ temporary exception for action.ts
  eval "$(pkgx --shellcode)" 2>/dev/null

  if ! _is_ci; then
    echo "now type: pkgx --help" >&2
  fi
fi
