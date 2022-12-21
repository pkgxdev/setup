#!/bin/sh

if test -f /etc/debian_version; then
  apt-get --yes update

  case $(cat /etc/debian_version) in
  jessie/sid)
    apt-get --yes install libc-dev libstdc++-4.8-dev libgcc-10-dev;;
  stretch/sid)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-10-dev;;
  buster/sid)
    apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev;;
  bullseye/sid)
    apt-get --yes install libc-dev libstdc++-10-dev libgcc-9-dev;;
  bookworm/sid)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-10-dev;;
  *)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-10-dev;;
  esac
elif test -f /etc/fedora-release; then
  yum --assumeyes install libatomic
fi
