#!/bin/sh
# installs linux pre-reqs with the system packager
# PR your system!

if test -f /etc/debian_version; then
  apt-get --yes update

  # minimal but required or networking doesn’t work
  # https://packages.debian.org/buster/all/netbase/filelist
  COMMON="netbase"

  # difficult to pkg in our opinion
  COMMON="libudev-dev $COMMON"

  case $(cat /etc/debian_version) in
  jessie/sid|8.*|stretch/sid|9.*)
    apt-get --yes install libc-dev libstdc++-4.8-dev libgcc-4.7-dev $COMMON;;
  buster/sid|10.*)
    apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev $COMMON;;
  bullseye/sid|11.*)
    apt-get --yes install libc-dev libstdc++-10-dev libgcc-9-dev $COMMON;;
  bookworm/sid|12.*|*)
    apt-get --yes install libc-dev libstdc++-11-dev libgcc-11-dev $COMMON;;
  esac
elif test -f /etc/fedora-release; then
  yum --assumeyes install libatomic
fi
