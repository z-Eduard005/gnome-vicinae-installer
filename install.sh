#!/bin/bash
VICINAE_INSTALLER="curl -fsSL https://vicinae.com/install.sh | bash"
VICINAE_ENTRY_DIR="/usr/local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
EXT_CLI="$HOME/.local/bin/gnome-extensions-cli"

success() { printf "\033[1;32m%s\033[0m" "$1"; }
err() { printf "\033[1;31m%s\033[0m" "$1"; }
warn() { printf "\033[1;33m%s\033[0m" "$1"; }

install_python() {
  if command -v dnf &>/dev/null; then
    sudo dnf install -y python3-pip
  elif command -v apt &>/dev/null; then
    sudo apt install -y python3-pip
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm python3-pip
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y python3-pip
  else
    echo "$(err "No supported package manager found. Please install python3-pip manually.")"; exit 1
  fi
}

ask_confirm() {
  read -rp "$(warn "$1 [y/N]: ")" proceed
  if [[ "$proceed" == [yY] ]]; then
    return 0
  else
    return 1
  fi
}

create_gnome_shortcut() {
  local id="$1" name="$2" command="$3" binding="$4"
  local schema="org.gnome.settings-daemon.plugins.media-keys"
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${id}/"

  local existing
  existing=$(gsettings get "$schema" custom-keybindings)

  if echo "$existing" | grep -q "'$path'"; then
    local updated="$existing"
  else
    local updated=$(echo "$existing" | sed "s|]|, '${path}']|" | sed "s|\[, |[|")
  fi

  gsettings set "$schema" custom-keybindings "$updated"
  gsettings set "${schema}.custom-keybinding:${path}" name "$name"
  gsettings set "${schema}.custom-keybinding:${path}" command "$command"
  gsettings set "${schema}.custom-keybinding:${path}" binding "$binding"
}

if [ "$EUID" -eq 0 ]; then
  echo "$(err 'Do not run this script with "sudo"!')" >&2
  exit 1
fi

proceed_install=true
if command -v vicinae &>/dev/null; then
  eval "$VICINAE_INSTALLER" 2>/dev/null
  echo "$(warn "Vicinae is already installed")"
  ask_confirm "Do you want to reinstall?" || proceed_install=false
fi

if $proceed_install; then
  pip3 install gnome-extensions-cli
  $EXT_CLI install vicinae@dagimg-dot
  eval "$VICINAE_INSTALLER" && systemctl --user enable vicinae --now || { echo "$(err "Failed to install vicinae")"; exit 1; }
  mkdir -p "$AUTOSTART_DIR"
  cp "$VICINAE_ENTRY_DIR/vicinae.desktop" "$AUTOSTART_DIR"

  create_gnome_shortcut "vicinae-toggle" "Vicinae Toggle" "vicinae toggle" "<Alt>space"
  create_gnome_shortcut "vicinae-clipboard" "Vicinae Clipboard" "vicinae deeplink vicinae://launch/clipboard/history" "<Alt>v"
  create_gnome_shortcut "vicinae-restart" "Vicinae Restart" "systemctl --user restart vicinae.service" "<Control><Alt>space"

  echo "$(success "Vicinae installed")"
  echo "$(success "<Alt+Space> to open vicinae")"
  echo "$(success "<Alt+V> to open vicinae clipboard manager")"
  echo "$(success "<Ctrl+Alt+Space> to restart vicinae service")"
  echo "$(success "You can change hotkeys in default settings app later")"
fi