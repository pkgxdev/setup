#!/bin/sh

set -e

_main() {
  if _should_install_pkgx; then
    _install_pkgx "$@"
    _install_pre_reqs
  elif [ $# -eq 0 ]; then
    echo /usr/local/bin/"$(pkgx --version) already installed" >&2
    echo /usr/local/bin/"$(pkgm --version) already installed" >&2
    exit
  fi

  if [ $# -gt 0 ]; then
    pkgx "$@"
  else
    if type eval >/dev/null 2>&1; then
      if ! [ "$major_version" ]; then
        major_version=$(pkgx --version | cut -d' ' -f2 | cut -d. -f1)
      fi
      if [ $major_version -lt 2 ]; then
        eval "$(pkgx --shellcode)" 2>/dev/null
      fi
    fi
    if ! _is_ci; then
      echo "now type: pkgx --help" >&2
    fi
  fi
}

_prep() {
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
}

_is_ci() {
  [ -n "$CI" ] && [ $CI != 0 ]
}

_install_pre_reqs() {
  if _is_ci; then
    apt() {
      # we should use apt-get not apt in CI
      # weird shit ref: https://askubuntu.com/a/668859
      export DEBIAN_FRONTEND=noninteractive
      cmd=$1
      shift
      $SUDO apt-get $cmd --yes -qq -o=Dpkg::Use-Pty=0 $@
    }
  else
    apt() {
      case "$1" in
      update)
        echo "ensure you have the \`pkgx\` pre-requisites installed:" >&2
        ;;
      install)
        echo "   apt-get" "$@" >&2
        ;;
      esac
    }
    yum() {
      echo "ensure you have the \`pkgx\` pre-requisites installed:" >&2
      echo "   yum" "$@" >&2
    }
    pacman() {
      echo "ensure you have the \`pkgx\` pre-requisites installed:" >&2
      echo "   pacman" "$@" >&2
    }
  fi

  if test -f /etc/debian_version; then
    apt update

    # minimal but required or networking doesn’t work
    # https://packages.debian.org/buster/all/netbase/filelist
    A="netbase"

    # difficult to pkg in our opinion
    B=libudev-dev

    # ca-certs needed until we bundle our own root cert
    C=ca-certificates

    case $(cat /etc/debian_version) in
    jessie/sid|8.*|stretch/sid|9.*)
      apt install libc-dev libstdc++-4.8-dev libgcc-4.7-dev $A $B $C;;
    buster/sid|10.*)
      apt install libc-dev libstdc++-8-dev libgcc-8-dev $A $B $C;;
    bullseye/sid|11.*)
      apt install libc-dev libstdc++-10-dev libgcc-9-dev $A $B $C;;
    bookworm/sid|12.*|*)
      apt install libc-dev libstdc++-11-dev libgcc-11-dev $A $B $C;;
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

_install_pkgx() {
  if _is_ci; then
    progress="--no-progress-meter"
  else
    progress="--progress-bar"
  fi

  tmpdir="$(mktemp -d)"

  if [ $# -eq 0 ]; then
    if [ -f /usr/local/bin/pkgx ]; then
      echo "upgrading: /usr/local/bin/pkg[xm]" >&2
    else
      echo "installing: /usr/local/bin/pkg[xm]" >&2
    fi

    # using a named pipe to prevent curl progress output trumping the sudo password prompt
    pipe="$tmpdir/pipe"
    mkfifo "$pipe"

    curl --silent --fail --proto '=https' -o "$tmpdir/pkgm" \
      https://pkgxdev.github.io/pkgm/pkgm.ts

    curl $progress --fail --proto '=https' "https://pkgx.sh/$(uname)/$(uname -m)".tgz > "$pipe" &
    $SUDO sh -c "
      mkdir -p /usr/local/bin
      tar xz --directory /usr/local/bin < '$pipe'
      install -m 755 "$tmpdir/pkgm" /usr/local/bin
    " &
    wait

    rm -r "$tmpdir"

    if [ "$(command -v pkgx 2>&1)" != /usr/local/bin/pkgx ]; then
      echo "warning: active pkgx is not /usr/local/bin/pkgx" >&2
      export PATH="/usr/local/bin:$PATH"  # so we can exec if required
    fi

    # tell the user what version we just installed
    pkgx --version
    pkgm --version

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
  if [ "$PKGX_UPDATE" = no ]; then
    return 1
  else
    new_version=$(curl -Ssf https://pkgx.sh/VERSION)
    old_version=$(/usr/local/bin/pkgx --version || echo pkgx 0)
    old_version=$(echo $old_version | cut -d' ' -f2)
    major_version=$(echo $new_version | cut -d. -f1)

    /usr/local/bin/pkgx --silent semverator gt $new_version $old_version
  fi
}

_pkgm_is_old() {
  if [ "$PKGX_UPDATE" = no ]; then
    return 1
  else
    new_version=$(curl -Ssf https://pkgxdev.github.io/pkgm/version.txt)
    old_version=$(pkgm --version || echo pkgm 0)
    old_version=$(echo $old_version | cut -d' ' -f2)

    /usr/local/bin/pkgx --silent semverator gt $new_version $old_version
  fi
}

_should_install_pkgx() {
  if [ ! -f /usr/local/bin/pkgx ]; then
    return 0
  elif _pkgx_is_old >/dev/null 2>&1 || _pkgm_is_old >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

_prep
if [ "$PKGX_INSTALL_PREREQS" != 1 ]; then
  _main "$@"
else
  _install_pre_reqs
fi
