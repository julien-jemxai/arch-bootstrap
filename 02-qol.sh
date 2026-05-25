#!/usr/bin/env bash
# arch-bootstrap / 02-qol.sh
# Quality-of-life: fonts, bluetooth, screenshots, clipboard, audio, fn-keys, themes, ssh-agent.
# Run AFTER 01-bootstrap.sh and reboot.

set -euo pipefail

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run as your normal user, not root."
command -v paru >/dev/null || die "paru not found. Run 01-bootstrap.sh first."

# --- Fonts ----------------------------------------------------------------
msg "Installing fonts (Nerd Fonts + Noto for unicode/emoji)"
paru -S --noconfirm --needed \
  ttf-jetbrains-mono-nerd \
  ttf-firacode-nerd \
  noto-fonts noto-fonts-emoji noto-fonts-cjk \
  ttf-liberation

# --- Bluetooth ------------------------------------------------------------
msg "Installing + enabling Bluetooth"
paru -S --noconfirm --needed bluez bluez-utils blueman
sudo systemctl enable --now bluetooth

# --- Screenshots ----------------------------------------------------------
msg "Installing screenshot tools (grimblast + satty for annotation)"
paru -S --noconfirm --needed grimblast-git satty

# --- Audio control --------------------------------------------------------
msg "Installing audio control (pavucontrol + playerctl)"
paru -S --noconfirm --needed pavucontrol playerctl

# --- Clipboard history ----------------------------------------------------
msg "Installing clipboard history (cliphist)"
paru -S --noconfirm --needed cliphist

# --- Brightness -----------------------------------------------------------
msg "Installing brightnessctl (for Fn brightness keys)"
paru -S --noconfirm --needed brightnessctl

# --- File manager + thumbnailers ------------------------------------------
msg "Installing file manager (nautilus) + thumbnailers"
paru -S --noconfirm --needed nautilus tumbler ffmpegthumbnailer

# --- GTK/icon theming -----------------------------------------------------
msg "Installing GTK theme tools + icon/cursor themes"
paru -S --noconfirm --needed \
  nwg-look \
  papirus-icon-theme \
  bibata-cursor-theme

# --- SSH agent management -------------------------------------------------
msg "Installing keychain (auto SSH agent on login)"
paru -S --noconfirm --needed keychain

# --- Better time sync -----------------------------------------------------
msg "Installing chrony (better than timesyncd for laptops that sleep)"
paru -S --noconfirm --needed chrony
sudo systemctl disable --now systemd-timesyncd 2>/dev/null || true
sudo systemctl enable --now chronyd

# --- Done -----------------------------------------------------------------
cat <<'EOF'

============================================================
 02-qol.sh DONE.

 The Fn keys, clipboard history, and screenshots are wired in
 the hyprland.conf already — they'll work after you log back
 into Hyprland.

 Next: 03-pull-configs.sh (once your GitHub SSH key is on this machine).
============================================================
EOF
