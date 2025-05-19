#!/bin/bash

PROGRAM_NAME="CloudChat"
VERSION="1.0.7"
ARCHIVE_NAME="${PROGRAM_NAME}-${VERSION}.tar.gz"

SOURCE_DIR="build/linux/x64/release/bundle"
TARGET_DIR="setup_linux/output"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found!"
    exit 1
fi

mkdir -p "$TARGET_DIR"

tar -czvf "$TARGET_DIR/$ARCHIVE_NAME" -C "$SOURCE_DIR" .

echo "Success: Archive created at $TARGET_DIR/$ARCHIVE_NAME"
exit 0
