#!/bin/bash
# Builds Habit Stack and installs it as an Arch Linux package via pacman.
# Run from anywhere -- uses the directory of this script as the repo root.
# Requires: flutter, base-devel (provides makepkg), sudo for pacman.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The desktop app is a Flutter *web* build served by a small local wrapper:
# Flutter's Linux embedder only reaches ~20fps at 4K, while the same Dart code
# in Chrome sustains ~144fps.
WEB_DIR="$SCRIPT_DIR/build/web"
WRAPPER_BUNDLE="$SCRIPT_DIR/build/cli/bundle"
WORK_DIR="$(mktemp -d)"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Parse version from pubspec.yaml (strip build number: 1.0.0+1 -> 1.0.0)
PKGVER="$(grep '^version:' "$SCRIPT_DIR/pubspec.yaml" \
    | sed 's/^version:[[:space:]]*//' | sed 's/+.*//')"

echo "==> Building Habit Stack $PKGVER (Flutter web release)..."
cd "$SCRIPT_DIR"
flutter build web --release

echo "==> Compiling the desktop wrapper..."
# `dart build cli`, not `dart compile exe`: the package pulls in dependencies
# with native build hooks, which `dart compile` refuses to handle even though
# the wrapper itself uses none of them.
rm -rf "$SCRIPT_DIR/build/cli"
dart build cli -o "$SCRIPT_DIR/build/cli"

echo "==> Generating PKGBUILD..."
cat > "$WORK_DIR/PKGBUILD" <<EOF
pkgname=habit-stack
pkgver=$PKGVER
pkgrel=1
pkgdesc='Atomic Habits implementation-intentions app'
arch=('x86_64')
url='https://github.com/kuhyx/habit_stack'
license=('custom')
# No hard browser dependency: naming one means makepkg installs it, and this
# system has a policy that immediately removes 'chromium' again, which then
# fails dependency resolution. The wrapper discovers whatever is present.
depends=()
optdepends=('chromium: renders the app window'
            'google-chrome: renders the app window')
# !strip is load-bearing: the wrapper is a Dart AOT executable with its
# snapshot embedded in the ELF, and stripping discards it. The stripped binary
# still runs, but is just the bare Dart VM printing a usage message.
options=('!strip' '!debug')

package() {
    # Preserve the bundle's bin/ + lib/ layout: the executable loads its native
    # libraries from ../lib and resolves the web assets from ../web.
    install -dm755 "\$pkgdir/opt/habit-stack"
    cp -r "$WRAPPER_BUNDLE/bin" "\$pkgdir/opt/habit-stack/bin"
    # lib/ only exists when a dependency ships native code; this app has none,
    # so the bundle is bin/-only and copying lib/ unconditionally fails.
    if [[ -d "$WRAPPER_BUNDLE/lib" ]]; then
        cp -r "$WRAPPER_BUNDLE/lib" "\$pkgdir/opt/habit-stack/lib"
    fi
    chmod 755 "\$pkgdir/opt/habit-stack/bin/habit_stack_desktop"

    install -dm755 "\$pkgdir/opt/habit-stack/web"
    cp -r "$WEB_DIR/." "\$pkgdir/opt/habit-stack/web/"

    install -dm755 "\$pkgdir/usr/bin"
    cat > "\$pkgdir/usr/bin/habit-stack" <<'WRAPPER'
#!/bin/bash
exec /opt/habit-stack/bin/habit_stack_desktop "\$@"
WRAPPER
    chmod 755 "\$pkgdir/usr/bin/habit-stack"
}
EOF

echo "==> Installing package via makepkg..."
cd "$WORK_DIR"
makepkg -sif --noconfirm

echo "==> Installing the desktop entry..."
"$SCRIPT_DIR/desktop/install_desktop_entry.sh"

echo "==> Done. 'habit-stack' now runs version $PKGVER installed via pacman."
