#!/bin/sh

if test -f /etc/debian_version; then
  apt-get --yes update

  case $(cat /etc/debian_version) in
  bookworm/sid)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-10-dev;;
  *)
    apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev;;
  esac
elif test -f /etc/fedora-release; then
  yum --assumeyes install libatomic
fi
