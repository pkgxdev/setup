#!/bin/sh

if which git; then
  git config --global url."https://teaxyz:$1@github.com/teaxyz/pantry".insteadOf "https://github.com/teaxyz/pantry"
fi
