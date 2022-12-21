#!/bin/sh
# installs linux pre-reqs with the system packager
# PR your system!

if test -f /etc/debian_version; then
  apt-get --yes update

  case $(cat /etc/debian_version) in
  jessie/sid|8.*|stretch/sid|9.*)
    apt-get --yes install libc-dev libstdc++-4.8-dev libgcc-4.7-dev;;
  buster/sid|10.*)
    apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev;;
  bullseye/sid|11.*)
    apt-get --yes install libc-dev libstdc++-10-dev libgcc-9-dev;;
  bookworm/sid|12.*|*)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-10-dev;;
  esac
elif test -f /etc/fedora-release; then
  yum --assumeyes install libatomic
fi
