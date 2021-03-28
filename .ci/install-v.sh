#!/bin/sh

set -e

VLANG_TARGET_OS=""
VLANG_VERSION="0.2.2"

case "$TRAVIS_OS_NAME" in
    osx) VLANG_TARGET_OS="macos" ;;
    linux) VLANG_TARGET_OS="linux" ;;
    windows) VLANG_TARGET_OS="windows" ;;
esac

FN="v_${VLANG_TARGET_OS}.zip"
URL="https://github.com/vlang/v/releases/download/${VLANG_VERSION}/${FN}"

echo "Downloading from: $URL"

wget -q "$URL"
unzip -q "$FN"

ls -lash

cd v
sudo ./v symlink