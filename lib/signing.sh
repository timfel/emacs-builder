#!/usr/bin/env bash
# APK Signing
# Handles keystore creation, APK alignment, signing, and verification

# Create debug keystore if it doesn't exist
ensure_keystore() {
    local keystore_path="$1"
    local keystore_pass="$2"
    local key_alias="$3"
    local key_pass="$4"

    if [[ -f "$keystore_path" ]]; then
        log_info "Using existing keystore: $keystore_path"
        return 0
    fi

    log_info "Creating debug keystore at: $keystore_path"

    # Ensure directory exists
    mkdir -p "$(dirname "$keystore_path")"

    # Generate keystore with standard debug credentials
    "$KEYTOOL" -genkey -v \
        -keystore "$keystore_path" \
        -storepass "$keystore_pass" \
        -alias "$key_alias" \
        -keypass "$key_pass" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US" \
        2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_success "Created debug keystore"
        return 0
    else
        log_error "Failed to create keystore"
        return 1
    fi
}

# Align an APK file (required before signing)
align_apk() {
    local input_apk="$1"
    local output_apk="$2"

    log_info "Aligning APK: $(basename "$input_apk")"

    # zipalign requires output file to not exist
    rm -f "$output_apk"

    # -p: page-align uncompressed .so files (for Android 6.0+)
    # -v: verbose
    # 4: 4-byte alignment
    "$ZIPALIGN" -p -f 4 "$input_apk" "$output_apk" 2>/dev/null
    local result=$?

    if [[ $result -eq 0 && -f "$output_apk" ]]; then
        log_success "Aligned: $(basename "$output_apk")"
        return 0
    else
        log_error "Failed to align APK"
        return 1
    fi
}

# Sign an APK file
sign_apk() {
    local apk_path="$1"
    local keystore_path="$2"
    local keystore_pass="$3"
    local key_alias="$4"
    local key_pass="$5"

    log_info "Signing APK: $(basename "$apk_path")"

    # apksigner modifies the APK in-place
    "$APKSIGNER" sign \
        --ks "$keystore_path" \
        --ks-pass "pass:$keystore_pass" \
        --ks-key-alias "$key_alias" \
        --key-pass "pass:$key_pass" \
        "$apk_path" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        log_success "Signed: $(basename "$apk_path")"
        return 0
    else
        log_error "Failed to sign APK"
        return 1
    fi
}

# Verify APK signature
verify_signature() {
    local apk_path="$1"

    log_info "Verifying signature: $(basename "$apk_path")"

    local result
    result=$("$APKSIGNER" verify --print-certs "$apk_path" 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "Signature verified: $(basename "$apk_path")"
        # Output cert info to stderr so it doesn't interfere with return values
        echo "$result" | grep -v "^WARNING" | grep -E "^Signer|DN:" | head -4 >&2
        return 0
    else
        log_error "Signature verification failed"
        echo "$result"
        return 1
    fi
}

# Get certificate fingerprint from APK
get_apk_fingerprint() {
    local apk_path="$1"

    # Filter out Java warnings and extract SHA-256 fingerprint
    "$APKSIGNER" verify --print-certs "$apk_path" 2>&1 | grep -v "^WARNING" | grep "SHA-256" | head -1 | awk '{print $NF}'
}

# Verify both APKs have matching signatures
verify_matching_signatures() {
    local apk1="$1"
    local apk2="$2"

    log_info "Verifying signatures match..."

    local fp1 fp2
    fp1=$(get_apk_fingerprint "$apk1")
    fp2=$(get_apk_fingerprint "$apk2")

    if [[ -z "$fp1" || -z "$fp2" ]]; then
        log_error "Could not extract fingerprints"
        return 1
    fi

    if [[ "$fp1" == "$fp2" ]]; then
        log_success "Signatures match!"
        log_info "SHA-256: $fp1"
        return 0
    else
        log_error "Signatures do NOT match!"
        log_error "APK 1: $fp1"
        log_error "APK 2: $fp2"
        return 1
    fi
}

# Full resign workflow for a single APK
resign_apk() {
    local input_apk="$1"
    local output_dir="$2"
    local output_name="$3"
    local keystore_path="$4"
    local keystore_pass="$5"
    local key_alias="$6"
    local key_pass="$7"

    local aligned_apk="$output_dir/${output_name}"
    local temp_apk="$output_dir/.${output_name}.aligned"

    mkdir -p "$output_dir"

    # Step 1: Align the APK
    if ! align_apk "$input_apk" "$temp_apk"; then
        return 1
    fi

    # Step 2: Copy to final location
    mv "$temp_apk" "$aligned_apk"

    # Step 3: Sign the APK
    if ! sign_apk "$aligned_apk" "$keystore_path" "$keystore_pass" "$key_alias" "$key_pass"; then
        rm -f "$aligned_apk"
        return 1
    fi

    # Step 4: Verify signature
    if ! verify_signature "$aligned_apk"; then
        rm -f "$aligned_apk"
        return 1
    fi

    echo "$aligned_apk"
    return 0
}
