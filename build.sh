#!/bin/bash
# Gera port/guloso/guloso.love e dist/Guloso-R36S.zip (pronto para copiar no cartão SD)
set -e
cd "$(dirname "$0")"
rm -f port/guloso/guloso.love
(cd src && zip -9 -q -r ../port/guloso/guloso.love .)
mkdir -p dist
rm -f dist/Guloso-R36S.zip
(cd port && zip -9 -q -r ../dist/Guloso-R36S.zip Guloso.sh guloso -x "guloso/savedata/*" "guloso/log.txt")
echo "OK: dist/Guloso-R36S.zip"
