# Emacs + Termux APK Builder

Build resigned Emacs and Termux APKs with matching certificates, enabling them to share the same Android user ID (`sharedUserId`). This allows Emacs to access Termux's filesystem, packages, and shell environment.

## Why?

Android requires apps with `sharedUserId` to be signed with identical certificates. By resigning both Emacs and Termux with your own keystore, they can:

- Share the same Linux user ID on Android
- Access each other's files without root
- Let Emacs run Termux packages (gcc, python, git, etc.)

## Requirements

- **Java JDK** (for keytool, apksigner)
- **curl** or **wget**
- **unzip**

### macOS

```bash
brew install openjdk
sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
```

### Linux

```bash
sudo apt install openjdk-17-jdk   # Debian/Ubuntu
sudo dnf install java-17-openjdk  # Fedora
```

## Quick Start

```bash
# Clone the repo
git clone https://github.com/yourusername/emacsapk.git
cd emacsapk

# Build both APKs
./build.sh

# Output will be in (with version numbers):
#   output/emacs-31.0.50-signed.apk
#   output/termux-0.118.3-signed.apk
```

## Usage

```bash
# Build with defaults (latest versions, arm64)
./build.sh

# Specify Emacs version
./build.sh --emacs-version 30.2

# List available versions
./build.sh --list-versions

# Build only Emacs
./build.sh --emacs-only

# Build only Termux
./build.sh --termux-only

# Clean cache and rebuild
./build.sh --clean

# Use a custom keystore
./build.sh --keystore ~/my-release.keystore --alias mykey --storepass mypassword
```

## Installation

```bash
# Install to connected Android device
adb install -r output/emacs-signed.apk
adb install -r output/termux-signed.apk
```

**Note:** If you previously installed either app with a different signature, uninstall first:

```bash
adb uninstall org.gnu.emacs
adb uninstall com.termux
```

## Configuration

Edit `config.sh` to change defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `KEYSTORE_PATH` | `~/.android/debug.keystore` | Path to signing keystore |
| `EMACS_VERSION` | (latest) | Emacs version to download |
| `TERMUX_VERSION` | (latest) | Termux version to download |
| `EMACS_API_LEVEL` | `29` | Android API level (29 = Android 10+) |
| `EMACS_ARCH` | `arm64-v8a` | CPU architecture |

## Project Structure

```
emacsapk/
├── build.sh          # Main entry point
├── config.sh         # Configuration defaults
├── lib/
│   ├── tools.sh      # Android SDK tools management
│   ├── download.sh   # APK download logic
│   └── signing.sh    # Keystore and signing
├── cache/            # Downloaded APKs (gitignored)
├── output/           # Signed APKs (gitignored)
└── tools/            # Auto-downloaded SDK tools (gitignored)
```

## How It Works

1. **Tool Setup**: Checks for Android SDK build-tools. If not found, downloads `cmdline-tools` from Google and installs `build-tools` locally.

2. **Keystore**: Uses `~/.android/debug.keystore` (Android's standard debug keystore). Creates it if missing.

3. **Download**:
   - Emacs from [SourceForge android-ports](https://sourceforge.net/projects/android-ports-for-gnu-emacs/) (termux-integrated builds)
   - Termux from [GitHub releases](https://github.com/termux/termux-app/releases)

4. **Resign**:
   - `zipalign` - Aligns APK for optimal Android performance
   - `apksigner` - Signs with your keystore
   - Verifies both APKs have matching SHA-256 certificate fingerprints

## Sources

- **Emacs**: https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/termux/
- **Termux**: https://github.com/termux/termux-app/releases
- **Guide**: https://marek-g.github.io/posts/tips_and_tricks/emacs_on_android/

## License

MIT
