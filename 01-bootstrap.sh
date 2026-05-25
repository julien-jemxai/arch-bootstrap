#!/usr/bin/env bash
# arch-bootstrap / 01-bootstrap.sh
# Core install: paru, NVIDIA, Hyprland stack, dev tools, browser, power mgmt.
# Run AFTER archinstall + network is up.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/01-bootstrap.sh | bash

set -euo pipefail

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

# --- Preflight ------------------------------------------------------------
[[ $EUID -eq 0 ]] && die "Run as your normal user, not root. sudo is invoked where needed."
command -v pacman >/dev/null || die "pacman not found. This script is for Arch."
ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || die "No network. Connect wifi first: nmcli device wifi connect <ssid> password <pw>"

msg "Updating system"
sudo pacman -Syu --noconfirm

# --- 1. paru (AUR helper) -------------------------------------------------
if ! command -v paru >/dev/null; then
  msg "Installing paru"
  sudo pacman -S --noconfirm --needed git base-devel
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  ( cd "$tmp/paru" && makepkg -si --noconfirm )
  rm -rf "$tmp"
else
  msg "paru already installed, skipping"
fi

# --- 2. NVIDIA (Legion 5 dGPU, Turing+) -----------------------------------
msg "Installing NVIDIA (open-dkms variant)"
paru -S --noconfirm --needed \
  nvidia-open-dkms nvidia-utils lib32-nvidia-utils \
  libva-nvidia-driver egl-wayland

# --- 3. Display + WM stack ------------------------------------------------
msg "Installing Hyprland + Wayland stack"
paru -S --noconfirm --needed \
  hyprland xdg-desktop-portal-hyprland \
  waybar fuzzel mako hypridle hyprlock hyprpaper hyprpicker \
  qt5-wayland qt6-wayland polkit-gnome \
  grim slurp wl-clipboard

# --- 4. Terminal + shell + dev essentials ---------------------------------
msg "Installing terminal, shell, dev tools"
paru -S --noconfirm --needed \
  ghostty zsh starship atuin \
  zellij neovim git-delta gh jq yq \
  fzf ripgrep fd bat zoxide eza yazi

# --- 5. Browser + Obsidian ------------------------------------------------
msg "Installing browser + Obsidian"
paru -S --noconfirm --needed zen-browser-bin obsidian

# Claude Code (separate installer, not in pacman/AUR)
if ! command -v claude >/dev/null; then
  msg "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
else
  msg "Claude Code already installed, skipping"
fi

# --- 6. Power management (laptop-critical) --------------------------------
msg "Installing + enabling power management"
paru -S --noconfirm --needed tlp tlp-rdw powertop
sudo systemctl enable --now tlp NetworkManager

# --- 7. Default shell -----------------------------------------------------
if [[ "$SHELL" != *zsh ]]; then
  msg "Setting zsh as default shell"
  chsh -s /usr/bin/zsh
else
  msg "zsh already default shell"
fi

# --- Done -----------------------------------------------------------------
cat <<'EOF'

============================================================
 01-bootstrap.sh DONE.

 Next:
   1. REBOOT NOW so NVIDIA modules load fresh:
        sudo reboot

   2. After reboot, drop in the Hyprland config:
        mkdir -p ~/.config/hypr
        curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/hypr/hyprland.conf \
          -o ~/.config/hypr/hyprland.conf
        curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/hypr/zprofile-snippet \
          >> ~/.zprofile

   3. Run the QoL pass:
        curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/02-qol.sh | bash

   4. Run the config pull (needs GitHub SSH key first):
        curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/03-pull-configs.sh | bash
============================================================
EOF
