#!/bin/bash

# Copy Foundry artifacts to the artifacts folder for use in JavaScript
# Run this script after compiling contracts with Foundry

SOURCE_DIR="../out"
TARGET_DIR="artifacts/out"

# Create artifacts directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy all .sol directories
echo "Copying Foundry artifacts to artifacts/out..."
cp -r "$SOURCE_DIR"/*.sol "$TARGET_DIR/" 2>/dev/null || true

echo "✅ Artifacts copied successfully!"

