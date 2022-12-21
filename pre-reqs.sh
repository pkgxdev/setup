#!/bin/sh

if test -f /etc/debian_version; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install libc-dev libstdc++-8-dev libgcc-8-dev
fi
