#!/bin/bash
# Gera port/nhacnhac/nhacnhac.love e dist/Nhac-Nhac-R36S.zip (pronto para copiar no cartão SD)
set -e
cd "$(dirname "$0")"
rm -f port/nhacnhac/nhacnhac.love
(cd src && zip -9 -q -r ../port/nhacnhac/nhacnhac.love .)
mkdir -p dist
rm -f dist/Nhac-Nhac-R36S.zip
(cd port && zip -9 -q -r ../dist/Nhac-Nhac-R36S.zip Nhac-Nhac.sh nhacnhac -x "nhacnhac/savedata/*" "nhacnhac/log.txt")
echo "OK: dist/Nhac-Nhac-R36S.zip"
