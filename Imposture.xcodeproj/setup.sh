#!/bin/bash
set -euo pipefail

# iOS Claude Template Setup Script
# Replaces all {{PLACEHOLDER}} markers in CLAUDE.md with your project values

CLAUDE_MD="CLAUDE.md"

if [ ! -f "$CLAUDE_MD" ]; then
    echo "Error: $CLAUDE_MD not found. Run this script from the project root."
    exit 1
fi

echo "=== iOS Claude Template Setup ==="
echo ""
echo "This script will replace placeholder values in CLAUDE.md."
echo ""

# Project Name
read -rp "Project name (Xcode scheme/project name): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name is required."
    exit 1
fi

# Bundle ID
read -rp "Bundle ID (e.g., com.example.myapp): " BUNDLE_ID
if [ -z "$BUNDLE_ID" ]; then
    echo "Error: Bundle ID is required."
    exit 1
fi

# Description
read -rp "Project description (one line): " PROJECT_DESCRIPTION

# App Type
echo ""
echo "App type options: SwiftUI app, widget, SPM package, multi-platform app"
read -rp "App type [SwiftUI app]: " APP_TYPE
APP_TYPE="${APP_TYPE:-SwiftUI app}"

# Platforms
echo ""
echo "Platform options: iOS 26, macOS 26, watchOS 12, visionOS 2"
read -rp "Target platforms [iOS 26]: " PLATFORMS
PLATFORMS="${PLATFORMS:-iOS 26}"

# Key Files Description
read -rp "Key files description (brief note about important files) [Core app files]: " KEY_FILES_DESCRIPTION
KEY_FILES_DESCRIPTION="${KEY_FILES_DESCRIPTION:-Core app files}"

echo ""
echo "--- Replacing placeholders ---"

# Use | as sed delimiter to avoid issues with / in values
sed -i '' "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$CLAUDE_MD"
sed -i '' "s|{{BUNDLE_ID}}|${BUNDLE_ID}|g" "$CLAUDE_MD"
sed -i '' "s|{{PROJECT_DESCRIPTION}}|${PROJECT_DESCRIPTION}|g" "$CLAUDE_MD"
sed -i '' "s|{{APP_TYPE}}|${APP_TYPE}|g" "$CLAUDE_MD"
sed -i '' "s|{{PLATFORMS}}|${PLATFORMS}|g" "$CLAUDE_MD"
sed -i '' "s|{{KEY_FILES_DESCRIPTION}}|${KEY_FILES_DESCRIPTION}|g" "$CLAUDE_MD"

echo "Done! CLAUDE.md has been configured for: $PROJECT_NAME"
echo ""

# Check for remaining placeholders
REMAINING=$(grep -c '{{' "$CLAUDE_MD" 2>/dev/null || true)
if [ "$REMAINING" -gt 0 ]; then
    echo "Warning: $REMAINING lines still contain {{placeholders}}:"
    grep -n '{{' "$CLAUDE_MD"
    echo ""
fi

# Git init
if [ ! -d ".git" ]; then
    read -rp "Initialize git repository? [y/N]: " INIT_GIT
    if [[ "$INIT_GIT" =~ ^[Yy]$ ]]; then
        git init
        echo "Git repository initialized."
    fi
fi

# Self-delete
echo ""
read -rp "Delete this setup script? [Y/n]: " DELETE_SELF
if [[ ! "$DELETE_SELF" =~ ^[Nn]$ ]]; then
    rm -- "$0"
    echo "Setup script removed."
fi

echo ""
echo "Setup complete! Run 'claude' to start Claude Code."
