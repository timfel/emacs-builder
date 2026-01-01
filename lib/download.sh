#!/usr/bin/env bash
# APK Download Management
# Downloads Emacs and Termux from SourceForge's termux-integration folder

# Base URL for termux-integrated builds
SOURCEFORGE_TERMUX_URL="https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/termux"

# Download a file with progress
download_file() {
    local url="$1"
    local output="$2"

    log_info "Downloading: $url"

    if command -v curl &>/dev/null; then
        # -L: follow redirects, -#: progress bar, -f: fail on HTTP errors
        curl -L -# -f -o "$output" "$url" || return 1
    elif command -v wget &>/dev/null; then
        wget --show-progress -O "$output" "$url" || return 1
    else
        log_error "Neither curl nor wget found"
        return 1
    fi

    return 0
}

# Get latest Emacs version from SourceForge termux folder
get_latest_emacs_version() {
    local api_url="https://sourceforge.net/projects/android-ports-for-gnu-emacs/rss?path=/termux"

    local version
    version=$(curl -sL "$api_url" 2>/dev/null | grep -oE 'emacs-[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | uniq | tail -1)

    if [[ -n "$version" ]]; then
        echo "${version#emacs-}"
    else
        # Fallback to known stable version
        echo "30.2"
    fi
}

# Get Emacs APK download URL
# Uses termux-integrated builds with API 29 (Android 10+) for arm64
get_emacs_download_url() {
    local version="${1:-$(get_latest_emacs_version)}"
    local api_level="${EMACS_API_LEVEL:-29}"
    local arch="${EMACS_ARCH:-arm64-v8a}"

    # SourceForge download URL for termux-integrated Emacs
    echo "${SOURCEFORGE_TERMUX_URL}/emacs-${version}-${api_level}-${arch}.apk/download"
}

# Get latest Termux version from GitHub
get_latest_termux_version() {
    local api_url="https://api.github.com/repos/termux/termux-app/releases/latest"

    local version
    version=$(curl -sL "$api_url" 2>/dev/null | grep -oE '"tag_name":\s*"v?[0-9.]+"' | head -1 | grep -oE '[0-9.]+')

    if [[ -n "$version" ]]; then
        echo "$version"
    else
        # Fallback to known working version
        echo "0.118.1"
    fi
}

# Get Termux APK download URL from GitHub releases
get_termux_download_url() {
    local version="${1:-$(get_latest_termux_version)}"
    local arch="${TERMUX_ARCH:-arm64-v8a}"

    # GitHub release URL
    echo "https://github.com/termux/termux-app/releases/download/v${version}/termux-app_v${version}+github-debug_${arch}.apk"
}

# Download Emacs APK
download_emacs() {
    local cache_dir="$1"
    local version="${EMACS_VERSION:-$(get_latest_emacs_version)}"
    local api_level="${EMACS_API_LEVEL:-29}"
    local arch="${EMACS_ARCH:-arm64-v8a}"
    local output_file="$cache_dir/emacs-${version}-${api_level}-${arch}.apk"

    # Check if already cached
    if [[ -f "$output_file" ]]; then
        log_info "Using cached Emacs APK: $output_file"
        echo "$output_file"
        return 0
    fi

    mkdir -p "$cache_dir"

    local download_url
    download_url=$(get_emacs_download_url "$version")

    log_info "Downloading Emacs $version (API $api_level, $arch)..."
    if download_file "$download_url" "$output_file"; then
        # Verify it's a valid APK (starts with PK zip header)
        if head -c 2 "$output_file" | grep -q "PK"; then
            log_success "Downloaded Emacs APK: $output_file"
            echo "$output_file"
            return 0
        else
            log_error "Downloaded file is not a valid APK"
            cat "$output_file" | head -5  # Show what we got for debugging
            rm -f "$output_file"
            return 1
        fi
    else
        log_error "Failed to download Emacs APK"
        rm -f "$output_file"
        return 1
    fi
}

# Download Termux APK
download_termux() {
    local cache_dir="$1"
    local version="${TERMUX_VERSION:-$(get_latest_termux_version)}"
    local arch="${TERMUX_ARCH:-arm64-v8a}"
    local output_file="$cache_dir/termux-${version}-${arch}.apk"

    # Check if already cached
    if [[ -f "$output_file" ]]; then
        log_info "Using cached Termux APK: $output_file"
        echo "$output_file"
        return 0
    fi

    mkdir -p "$cache_dir"

    local download_url
    download_url=$(get_termux_download_url "$version")

    log_info "Downloading Termux $version ($arch) from GitHub..."
    if download_file "$download_url" "$output_file"; then
        # Verify it's a valid APK
        if head -c 2 "$output_file" | grep -q "PK"; then
            log_success "Downloaded Termux APK: $output_file"
            echo "$output_file"
            return 0
        else
            log_error "Downloaded file is not a valid APK"
            cat "$output_file" | head -5  # Show what we got for debugging
            rm -f "$output_file"
            return 1
        fi
    else
        log_error "Failed to download Termux APK"
        rm -f "$output_file"
        return 1
    fi
}

# List available Emacs versions (for --list-versions)
list_emacs_versions() {
    log_info "Fetching available Emacs versions from SourceForge (termux builds)..."
    local api_url="https://sourceforge.net/projects/android-ports-for-gnu-emacs/rss?path=/termux"

    curl -sL "$api_url" 2>/dev/null | grep -oE 'emacs-[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | uniq | sed 's/emacs-//'
}

# List available Termux versions
list_termux_versions() {
    log_info "Fetching available Termux versions from GitHub..."
    local api_url="https://api.github.com/repos/termux/termux-app/releases"

    curl -sL "$api_url" 2>/dev/null | grep -oE '"tag_name":\s*"v?[0-9.]+"' | grep -oE '[0-9.]+' | head -10
}
