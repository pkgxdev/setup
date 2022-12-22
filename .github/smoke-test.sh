#!/bin/sh
set -xe
test "$(~/.tea/tea.xyz/v0/bin/tea --prefix)" = "$HOME"/.tea
