#!/bin/sh

set -e

_main() {
  if _should_install_pkgx; then
    _install_pkgx "$@"
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

_install_pkgx() {
  if _is_ci; then
    progress="--no-progress-meter"
  else
    progress="--progress-bar"
  fi

  tmpdir="$(mktemp -d)"

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
      if [ ! -f /usr/local/bin/pkgm ]; then
        echo '#!/usr/bin/env -S pkgx -q! pkgm' > /usr/local/bin/pkgm
        chmod +x /usr/local/bin/pkgm
      fi
      if [ ! -f /usr/local/bin/mash ]; then
        echo '#!/usr/bin/env -S pkgx -q! mash' > /usr/local/bin/mash
        chmod +x /usr/local/bin/mash
      fi
    " &
    wait

    rm -r "$tmpdir"

    if [ "$(command -v pkgx 2>&1)" != /usr/local/bin/pkgx ]; then
      echo "warning: active pkgx is not /usr/local/bin/pkgx" >&2
      export PATH="/usr/local/bin:$PATH"  # so we can exec if required
    fi

    # tell the user what version we just installed
    pkgx --version
    pkgx pkgm@latest --version
    pkgx mash@latest --version

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
_main "$@"
