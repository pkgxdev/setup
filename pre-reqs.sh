#!/bin/sh

if test -f /etc/debian_version; then
  apt-get --yes update
  apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev
fi
