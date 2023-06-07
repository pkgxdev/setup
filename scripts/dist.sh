#!/usr/bin/env -S tea bash

set -e

# source <(tea --magic=bash)

tea npm install --include=dev

rm -rf dist

tea npx -- ncc build action.ts --minify --out dist/out

cp -R node_modules/koffi/build dist

cd dist/build/2.*.*/
rm -rf koffi_*bsd*
rm -rf *ia32
rm -rf *koffi_win32*
rm -rf koffi_linux_arm32hf
rm -rf koffi_linux_riscv64hf64

cd ../../out
rm install-pre-reqs.sh
ln -s ../../install-pre-reqs.sh
