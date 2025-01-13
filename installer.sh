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
  elif test -f /etc/arch-release; then
    # installing gcc isn't my favorite thing, but even clang depends on it
    # on archlinux. it provides libgcc. since we use it for testing, the risk
    # to our builds is very low.
    $SUDO pacman --noconfirm -Sy gcc libatomic_ops libxcrypt-compat
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
    if [ -f /usr/local/bin/pkgx ]; then
      echo "upgrading: /usr/local/bin/pkgx" >&2
    else
      echo "installing: /usr/local/bin/pkgx" >&2
    fi

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

    if [ "$(command which pkgx)" != /usr/local/bin/pkgx ]; then
      echo "warning: active pkgx is not /usr/local/bin/pkgx" >&2
      export PATH="/usr/local/bin:$PATH"  # so we can exec if required
    fi

    # tell the user what version we just installed
    pkgx --version

  else
    curl $progress --fail --proto '=https' \
        "https://pkgx.sh/$(uname)/$(uname -m)".tgz \
      | tar xz --directory "$tmpdir"

    export PATH="$tmpdir:$PATH"
    export PKGX_DIR="$tmpdir"
  fi

  unset tmpdir pipe
}

_pkgx_is_old() {
  v="$(/usr/local/bin/pkgx --version || echo pkgx 0)"
  /usr/local/bin/pkgx --silent semverator gt \
    $(curl -Ssf https://pkgx.sh/VERSION) \
    $(echo $v | awk '{print $2}')
}

_should_install_pkgx() {
  if [ ! -f /usr/local/bin/pkgx ]; then
    return 0
  elif _pkgx_is_old >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

########################################################################### meat

if _should_install_pkgx; then
  _install_pkgx "$@"
elif [ $# -eq 0 ]; then
  echo "$(pkgx --version) already installed" >&2
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
  pacman() {
    echo "   pacman" "$@" >&2
  }
  unset SUDO
fi

_install_pre_reqs

if [ $# -gt 0 ]; then
  pkgx "$@"
elif [ $(basename "/$0") != 'installer.sh' ]; then
  # ^^ temporary exception for action.ts

  if type eval >/dev/null 2>&1; then
    # we `type eval` as on Travis there was no `eval`!
    eval "$(pkgx --shellcode)" 2>/dev/null
  fi

  if ! _is_ci; then
    echo "now type: pkgx --help" >&2
  fi
fi
