#!/usr/bin/env bash
# Build usign from the pinned OpenWrt commit (the one in the test router's firmware, also used by
# aether-proxy's host tests).  usign.sh <output binary>
set -euo pipefail
rev=c4c72b1b07945ee192361dc751291a7c98d6adcd
out=$1
src=$(mktemp -d)
trap 'rm -rf "$src"' EXIT
git clone -q https://github.com/openwrt/usign.git "$src" || git clone -q https://git.openwrt.org/project/usign.git "$src"
git -C "$src" checkout -q "$rev"
(cd "$src" && cc -O2 -std=gnu99 -o "$out" ed25519.c edsign.c f25519.c fprime.c sha512.c main.c base64.c)
