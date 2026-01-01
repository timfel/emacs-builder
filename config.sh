#!/usr/bin/env bash
# Configuration for Emacs + Termux APK Builder
# Modify these values to customize the build

# ─────────────────────────────────────────────────────────────────────────────
# Keystore Configuration
# ─────────────────────────────────────────────────────────────────────────────
# Uses Android's standard debug keystore by default
KEYSTORE_PATH="${KEYSTORE_PATH:-$HOME/.android/debug.keystore}"
KEYSTORE_PASS="${KEYSTORE_PASS:-android}"
KEY_ALIAS="${KEY_ALIAS:-androiddebugkey}"
KEY_PASS="${KEY_PASS:-android}"

# ─────────────────────────────────────────────────────────────────────────────
# APK Versions (leave empty to auto-detect latest)
# ─────────────────────────────────────────────────────────────────────────────
EMACS_VERSION="${EMACS_VERSION:-30.2}"
TERMUX_VERSION="${TERMUX_VERSION:-}"

# ─────────────────────────────────────────────────────────────────────────────
# Download Sources
# ─────────────────────────────────────────────────────────────────────────────
# Emacs APK from SourceForge (has GnuTLS support)
EMACS_SOURCE_URL="https://sourceforge.net/projects/android-ports-for-gnu-emacs/files"

# Termux from GitHub releases
TERMUX_GITHUB_REPO="termux/termux-app"
TERMUX_SOURCE_URL="https://github.com/${TERMUX_GITHUB_REPO}/releases"

# Android command-line tools
ANDROID_CMDLINE_TOOLS_VERSION="11076708"
ANDROID_BUILD_TOOLS_VERSION="35.0.0"

# ─────────────────────────────────────────────────────────────────────────────
# Directories (relative to script location)
# ─────────────────────────────────────────────────────────────────────────────
CACHE_DIR="${CACHE_DIR:-cache}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
TOOLS_DIR="${TOOLS_DIR:-tools}"
