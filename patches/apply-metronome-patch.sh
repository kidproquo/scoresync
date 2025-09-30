#!/bin/bash

# Script to apply the metronome plugin patch for Android timing fix

PLUGIN_VERSION="2.0.6"
PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/metronome-$PLUGIN_VERSION"
PATCH_FILE="patches/metronome-plugin/android/src/main/java/com/sumsg/metronome/Metronome.java"
TARGET_FILE="$PLUGIN_PATH/android/src/main/java/com/sumsg/metronome/Metronome.java"

echo "Applying metronome plugin patch..."

# Check if plugin exists
if [ ! -d "$PLUGIN_PATH" ]; then
    echo "Error: Metronome plugin v$PLUGIN_VERSION not found in pub cache"
    echo "Please run 'flutter pub get' first"
    exit 1
fi

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file not found: $PATCH_FILE"
    exit 1
fi

# Backup original file
if [ -f "$TARGET_FILE" ]; then
    echo "Backing up original file..."
    cp "$TARGET_FILE" "$TARGET_FILE.backup"
fi

# Apply patch
echo "Copying patched file..."
cp "$PATCH_FILE" "$TARGET_FILE"

echo "Patch applied successfully!"
echo "Run 'flutter clean && flutter pub get' to rebuild with the patched plugin."

# Show what changed
echo ""
echo "Changes made:"
echo "- Added immediate tick callback in play() method"
echo "- Fixes Android timing offset to match iOS behavior"
echo "- Eliminates 1-beat visual/audio misalignment"