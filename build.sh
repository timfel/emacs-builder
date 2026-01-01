#!/usr/bin/env bash
#
# Emacs + Termux APK Builder
# Downloads prebuilt APKs and resigns them with a shared certificate
# so they can run with the same Android user ID (sharedUserId).
#
# Usage: ./build.sh [options]
#
# See --help for options.
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Script location and setup
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────────────────────────────────────
# Logging utilities
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# All logs go to stderr so they don't interfere with function return values
log_info()    { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─────────────────────────────────────────────────────────────────────────────
# Load configuration and libraries
# ─────────────────────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/tools.sh"
source "$SCRIPT_DIR/lib/download.sh"
source "$SCRIPT_DIR/lib/signing.sh"

# ─────────────────────────────────────────────────────────────────────────────
# Help message
# ─────────────────────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
Emacs + Termux APK Builder

Builds resigned Emacs and Termux APKs with a shared signing certificate,
enabling them to run with the same Android user ID (sharedUserId).

USAGE:
    ./build.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    --emacs-version VER     Specify Emacs version (e.g., 29.4)
    --termux-version VER    Specify Termux version (e.g., 0.118.1)
    --keystore PATH         Use custom keystore file
    --storepass PASS        Keystore password (default: android)
    --alias NAME            Key alias (default: androiddebugkey)
    --keypass PASS          Key password (default: android)
    --output DIR            Output directory (default: ./output)
    --clean                 Clean cache and output directories
    --list-versions         List available versions
    --emacs-only            Only build Emacs APK
    --termux-only           Only build Termux APK

EXAMPLES:
    ./build.sh                                    # Build with defaults
    ./build.sh --emacs-version 29.4              # Specific Emacs version
    ./build.sh --clean                            # Clean and rebuild
    ./build.sh --keystore ~/my.keystore          # Custom keystore

EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse command line arguments
# ─────────────────────────────────────────────────────────────────────────────
CLEAN=false
LIST_VERSIONS=false
BUILD_EMACS=true
BUILD_TERMUX=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --emacs-version)
            EMACS_VERSION="$2"
            shift 2
            ;;
        --termux-version)
            TERMUX_VERSION="$2"
            shift 2
            ;;
        --keystore)
            KEYSTORE_PATH="$2"
            shift 2
            ;;
        --storepass)
            KEYSTORE_PASS="$2"
            shift 2
            ;;
        --alias)
            KEY_ALIAS="$2"
            shift 2
            ;;
        --keypass)
            KEY_PASS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --list-versions)
            LIST_VERSIONS=true
            shift
            ;;
        --emacs-only)
            BUILD_TERMUX=false
            shift
            ;;
        --termux-only)
            BUILD_EMACS=false
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Main execution
# ─────────────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            Emacs + Termux APK Builder                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Handle --list-versions
    if [[ "$LIST_VERSIONS" == true ]]; then
        echo "Available Emacs versions:"
        list_emacs_versions
        echo ""
        echo "Available Termux versions:"
        list_termux_versions
        exit 0
    fi

    # Handle --clean
    if [[ "$CLEAN" == true ]]; then
        log_info "Cleaning cache and output directories..."
        rm -rf "$SCRIPT_DIR/$CACHE_DIR"/* 2>/dev/null || true
        rm -rf "$SCRIPT_DIR/$OUTPUT_DIR"/*.apk 2>/dev/null || true
        log_success "Cleaned"
    fi

    # Step 1: Set up tools
    log_info "Step 1: Setting up Android build tools..."
    if ! setup_tools "$SCRIPT_DIR"; then
        log_error "Failed to set up build tools"
        exit 1
    fi

    if ! verify_tools; then
        exit 1
    fi

    # Step 2: Ensure keystore exists
    log_info "Step 2: Ensuring keystore exists..."
    if ! ensure_keystore "$KEYSTORE_PATH" "$KEYSTORE_PASS" "$KEY_ALIAS" "$KEY_PASS"; then
        exit 1
    fi

    # Step 3: Download APKs
    log_info "Step 3: Downloading APKs..."
    local cache_dir="$SCRIPT_DIR/$CACHE_DIR"
    local output_dir="$SCRIPT_DIR/$OUTPUT_DIR"

    local emacs_apk=""
    local termux_apk=""

    if [[ "$BUILD_EMACS" == true ]]; then
        emacs_apk=$(download_emacs "$cache_dir")
        if [[ -z "$emacs_apk" ]]; then
            log_error "Failed to download Emacs APK"
            exit 1
        fi
    fi

    if [[ "$BUILD_TERMUX" == true ]]; then
        termux_apk=$(download_termux "$cache_dir")
        if [[ -z "$termux_apk" ]]; then
            log_error "Failed to download Termux APK"
            exit 1
        fi
    fi

    # Step 4: Resign APKs
    log_info "Step 4: Resigning APKs..."

    local signed_emacs=""
    local signed_termux=""

    if [[ -n "$emacs_apk" ]]; then
        # Extract version from filename (e.g., emacs-31.0.50-29-arm64-v8a.apk -> 31.0.50)
        local emacs_basename
        emacs_basename=$(basename "$emacs_apk")
        local emacs_version
        emacs_version=$(echo "$emacs_basename" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

        signed_emacs=$(resign_apk \
            "$emacs_apk" \
            "$output_dir" \
            "emacs-${emacs_version}-signed.apk" \
            "$KEYSTORE_PATH" "$KEYSTORE_PASS" "$KEY_ALIAS" "$KEY_PASS")

        if [[ -z "$signed_emacs" ]]; then
            log_error "Failed to resign Emacs APK"
            exit 1
        fi
    fi

    if [[ -n "$termux_apk" ]]; then
        # Extract version from filename (e.g., termux-0.118.3-arm64-v8a.apk -> 0.118.3)
        local termux_basename
        termux_basename=$(basename "$termux_apk")
        local termux_version
        termux_version=$(echo "$termux_basename" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

        signed_termux=$(resign_apk \
            "$termux_apk" \
            "$output_dir" \
            "termux-${termux_version}-signed.apk" \
            "$KEYSTORE_PATH" "$KEYSTORE_PASS" "$KEY_ALIAS" "$KEY_PASS")

        if [[ -z "$signed_termux" ]]; then
            log_error "Failed to resign Termux APK"
            exit 1
        fi
    fi

    # Step 5: Verify matching signatures
    if [[ -n "$signed_emacs" && -n "$signed_termux" ]]; then
        log_info "Step 5: Verifying signatures match..."
        if ! verify_matching_signatures "$signed_emacs" "$signed_termux"; then
            log_error "Signature verification failed!"
            exit 1
        fi
    fi

    # Done!
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      BUILD COMPLETE!                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ -n "$signed_emacs" ]]; then
        log_success "Emacs APK:  $signed_emacs"
    fi
    if [[ -n "$signed_termux" ]]; then
        log_success "Termux APK: $signed_termux"
    fi

    echo ""
    log_info "Install with: adb install -r <apk_file>"
    log_info "Both apps will run as the same Android user, enabling sharing."
    echo ""
}

main "$@"
