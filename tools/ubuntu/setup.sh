#!/usr/bin/env bash
# One-time setup of Aeterna on an Ubuntu laptop (desktop mode: mouse and keys, no headset, no XR simulator).
# Run it from inside a clone of the repo:   bash tools/ubuntu/setup.sh
# It installs git-lfs, downloads Godot (the version in GODOT_VERSION below) into ~/.local/share/aeterna,
# imports the project once, and adds an "Aeterna" icon to the app menu. The icon pulls the newest game from GitHub
# every time it starts, so after this you never touch the laptop again.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="$HOME/.local/share/aeterna"
GODOT_BIN="$HOME_DIR/godot"

echo "== 1/4 packages"
sudo apt-get update -qq
sudo apt-get install -y git git-lfs curl unzip libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libvulkan1 mesa-vulkan-drivers
git lfs install
(cd "$REPO" && git lfs pull)

echo "== 2/4 Godot $GODOT_VERSION"
mkdir -p "$HOME_DIR"
if [ ! -x "$GODOT_BIN" ] || ! "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION%-stable}"; then
  tmp="$(mktemp -d)"
  curl -fL -o "$tmp/godot.zip" "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  mv "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
  chmod +x "$GODOT_BIN"
  rm -rf "$tmp"
fi
"$GODOT_BIN" --version

echo "== 3/4 first import (takes a while once)"
"$GODOT_BIN" --headless --xr-mode off --path "$REPO/godot" --import || true

echo "== 4/4 launcher"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
cat > "$HOME/.local/bin/aeterna" <<LAUNCH
#!/usr/bin/env bash
# Update from GitHub (never fails the launch), re-import what changed, then start the game.
cd "$REPO"
git pull --ff-only -q 2>&1 || echo "aeterna: could not update (offline or local edits); starting the version you have"
git lfs pull -q 2>&1 || true
"$GODOT_BIN" --headless --xr-mode off --path "$REPO/godot" --import >/dev/null 2>&1 || true
exec "$GODOT_BIN" --path "$REPO/godot" --xr-mode off --resolution 1600x900 "\$@"
LAUNCH
chmod +x "$HOME/.local/bin/aeterna"
cat > "$HOME/.local/share/applications/aeterna.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Aeterna
Comment=Update and play Aeterna (desktop mode)
Exec=$HOME/.local/bin/aeterna
Terminal=false
Categories=Game;
DESK
echo
echo "Done. Open the app menu and search for Aeterna, or run: aeterna"
echo "Keys: 1 / 2 / 3 pick a tower, left click builds, Esc or right click cancels, Enter or Space starts the night, Tab = x2 speed, R = new run."
