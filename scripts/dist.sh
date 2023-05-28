#!/usr/bin/env tea bash

source <(tea --magic=bash)

npm i
npx -- ncc build action.js --minify --out dist/out

rm -rf dist/build
mv node_modules/koffi/build dist

cd dist/build/2.*.*/
rm -rf koffi_*bsd*
rm -rf *ia32
rm -rf *koffi_win32*

cd ../../out
rm install-pre-reqs.sh
ln -s ../../install-pre-reqs.sh
