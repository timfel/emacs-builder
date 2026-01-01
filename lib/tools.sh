#!/usr/bin/env bash
# SDK Tools Management
# Detects or downloads Android SDK command-line tools (apksigner, zipalign)

# Tool paths (populated by setup_tools)
APKSIGNER=""
ZIPALIGN=""
KEYTOOL=""

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin)  echo "mac" ;;
        Linux)   echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "win" ;;
        *)       echo "unknown" ;;
    esac
}

# Find existing Android SDK installation
find_android_sdk() {
    local sdk_locations=(
        "${ANDROID_HOME:-}"
        "${ANDROID_SDK_ROOT:-}"
        "$HOME/Library/Android/sdk"        # macOS Android Studio default
        "$HOME/Android/Sdk"                 # Linux Android Studio default
        "/opt/android-sdk"                  # Common Linux location
        "/usr/local/android-sdk"
    )

    for location in "${sdk_locations[@]}"; do
        if [[ -n "$location" && -d "$location/build-tools" ]]; then
            echo "$location"
            return 0
        fi
    done
    return 1
}

# Find build-tools with apksigner
find_build_tools() {
    local sdk_path="$1"
    local build_tools_dir="$sdk_path/build-tools"

    if [[ ! -d "$build_tools_dir" ]]; then
        return 1
    fi

    # Find the latest version
    local latest_version
    latest_version=$(ls -1 "$build_tools_dir" 2>/dev/null | sort -V | tail -1)

    if [[ -n "$latest_version" && -f "$build_tools_dir/$latest_version/apksigner" ]]; then
        echo "$build_tools_dir/$latest_version"
        return 0
    fi
    return 1
}

# Download Android command-line tools
download_cmdline_tools() {
    local tools_dir="$1"
    local platform
    platform=$(detect_platform)

    if [[ "$platform" == "unknown" ]]; then
        log_error "Unsupported platform: $(uname -s)"
        return 1
    fi

    local download_url="https://dl.google.com/android/repository/commandlinetools-${platform}-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
    local zip_file="$tools_dir/cmdline-tools.zip"

    log_info "Downloading Android command-line tools..."
    mkdir -p "$tools_dir"

    if command -v curl &>/dev/null; then
        curl -L -o "$zip_file" "$download_url" || return 1
    elif command -v wget &>/dev/null; then
        wget -O "$zip_file" "$download_url" || return 1
    else
        log_error "Neither curl nor wget found. Cannot download tools."
        return 1
    fi

    log_info "Extracting command-line tools..."
    unzip -q -o "$zip_file" -d "$tools_dir" || return 1
    rm -f "$zip_file"

    # Move to expected location for sdkmanager
    if [[ -d "$tools_dir/cmdline-tools" ]]; then
        mkdir -p "$tools_dir/cmdline-tools/latest"
        mv "$tools_dir/cmdline-tools/"* "$tools_dir/cmdline-tools/latest/" 2>/dev/null || true
    fi

    return 0
}

# Install build-tools using sdkmanager
install_build_tools() {
    local tools_dir="$1"
    local sdkmanager="$tools_dir/cmdline-tools/latest/bin/sdkmanager"

    if [[ ! -x "$sdkmanager" ]]; then
        log_error "sdkmanager not found at: $sdkmanager"
        return 1
    fi

    log_info "Installing build-tools:${ANDROID_BUILD_TOOLS_VERSION}..."

    # Accept licenses and install build-tools
    yes | "$sdkmanager" --sdk_root="$tools_dir" --licenses &>/dev/null || true
    "$sdkmanager" --sdk_root="$tools_dir" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" || return 1

    return 0
}

# Check if Java is available
check_java() {
    # On macOS, there's a stub that exists but prompts to install Java
    # We need to actually run java to check if it works
    if java -version &>/dev/null; then
        return 0
    fi

    log_error "Java is required but not installed."
    echo ""
    echo "Please install Java JDK:"
    echo ""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "  brew install openjdk"
        echo "  # Then add to PATH:"
        echo "  echo 'export PATH=\"/opt/homebrew/opt/openjdk/bin:\$PATH\"' >> ~/.zshrc"
    else
        echo "  sudo apt install openjdk-17-jdk    # Debian/Ubuntu"
        echo "  sudo dnf install java-17-openjdk   # Fedora"
    fi
    echo ""
    return 1
}

# Main setup function - ensures apksigner and zipalign are available
setup_tools() {
    local script_dir="$1"
    local tools_dir="$script_dir/$TOOLS_DIR"

    # Check Java first (required for sdkmanager, apksigner, keytool)
    if ! check_java; then
        return 1
    fi

    # Always need keytool (comes with Java)
    KEYTOOL=$(command -v keytool 2>/dev/null)
    if [[ -z "$KEYTOOL" ]]; then
        log_error "keytool not found. Please install Java JDK."
        return 1
    fi

    # Check for existing Android SDK
    local sdk_path
    sdk_path=$(find_android_sdk)

    if [[ -n "$sdk_path" ]]; then
        log_info "Found Android SDK at: $sdk_path"
        local build_tools_path
        build_tools_path=$(find_build_tools "$sdk_path")

        if [[ -n "$build_tools_path" ]]; then
            APKSIGNER="$build_tools_path/apksigner"
            ZIPALIGN="$build_tools_path/zipalign"
            log_success "Using system build-tools: $build_tools_path"
            return 0
        fi
    fi

    # Check for locally installed tools
    local local_build_tools="$tools_dir/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"
    if [[ -f "$local_build_tools/apksigner" ]]; then
        APKSIGNER="$local_build_tools/apksigner"
        ZIPALIGN="$local_build_tools/zipalign"
        log_success "Using local build-tools: $local_build_tools"
        return 0
    fi

    # Need to download tools
    log_warning "Android build-tools not found. Downloading..."

    if ! download_cmdline_tools "$tools_dir"; then
        log_error "Failed to download command-line tools"
        return 1
    fi

    if ! install_build_tools "$tools_dir"; then
        log_error "Failed to install build-tools"
        return 1
    fi

    # Verify installation
    local_build_tools="$tools_dir/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"
    if [[ -f "$local_build_tools/apksigner" ]]; then
        APKSIGNER="$local_build_tools/apksigner"
        ZIPALIGN="$local_build_tools/zipalign"
        log_success "Build-tools installed successfully"
        return 0
    fi

    log_error "Build-tools installation failed"
    return 1
}

# Verify all tools are ready
verify_tools() {
    local missing=0

    if [[ ! -x "$APKSIGNER" ]]; then
        log_error "apksigner not found or not executable: $APKSIGNER"
        missing=1
    fi

    if [[ ! -x "$ZIPALIGN" ]]; then
        log_error "zipalign not found or not executable: $ZIPALIGN"
        missing=1
    fi

    if [[ ! -x "$KEYTOOL" ]]; then
        log_error "keytool not found or not executable: $KEYTOOL"
        missing=1
    fi

    return $missing
}
