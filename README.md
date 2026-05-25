# arch-bootstrap

Reproducible setup for the Legion 5 laptop. Arch + Hyprland + NVIDIA + the JEM x AI dev stack.

## Usage (the fast path)

After `archinstall` + first boot + wifi connected (`nmcli device wifi connect <ssid> password <pw>`):

```bash
# 1. Core install
curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/01-bootstrap.sh | bash

# 2. Reboot for NVIDIA modules
sudo reboot

# 3. Hyprland config
mkdir -p ~/.config/hypr
curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/hypr/hyprland.conf -o ~/.config/hypr/hyprland.conf
curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/hypr/zprofile-snippet >> ~/.zprofile

# 4. QoL pass
curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/02-qol.sh | bash

# 5. Generate SSH key and add to GitHub
ssh-keygen -t ed25519 -C "legion-laptop"
cat ~/.ssh/id_ed25519.pub   # paste at https://github.com/settings/keys

# 6. Pull configs (dot-claude + vault)
curl -fsSL https://raw.githubusercontent.com/julien-jemxai/arch-bootstrap/main/03-pull-configs.sh | bash
```

## archinstall TUI options

|Option             |Value                                                              |
|-------------------|-------------------------------------------------------------------|
|Mirror region      |United States                                                      |
|Locale             |en_US.UTF-8                                                        |
|Disk               |NVMe → wipe + best-effort default layout                           |
|Filesystem         |**btrfs** with subvolumes (mount `/home` and `/var/log` as subvols)|
|Encryption         |**LUKS**, strong password — write it down on physical paper        |
|Bootloader         |**systemd-boot** (not GRUB)                                        |
|Hostname           |`legion` (or whatever)                                             |
|Root password      |set                                                                |
|User               |`crom`, sudo, password                                             |
|Profile            |**minimal** (NOT desktop — we build the WM by hand)                |
|Audio              |pipewire                                                           |
|Kernels            |`linux-zen` AND `linux-lts`                                        |
|Network            |NetworkManager                                                     |
|Additional packages|leave empty                                                        |
|Timezone           |America/New_York                                                   |
|Time sync          |yes                                                                |

## What each script does

- **`01-bootstrap.sh`** — paru, NVIDIA (open-dkms), Hyprland + Wayland stack, terminal/shell/dev tools (ghostty, zsh, starship, neovim, gh, fzf, ripgrep, eza, yazi, …), zen-browser + obsidian + claude-code, tlp/NetworkManager, sets zsh as default shell.
- **`02-qol.sh`** — Nerd Fonts + Noto, Bluetooth, screenshot stack (grimblast + satty), pavucontrol/playerctl, cliphist, brightnessctl, nautilus + thumbnailers, GTK theme tools, keychain, chrony.
- **`03-pull-configs.sh`** — SSH precheck, clones `dot-claude` → `~/.claude` and `vault` → `~/vault`, prints manual checklist.
- **`hypr/hyprland.conf`** — NVIDIA env block, day-one keybinds, Fn keys (brightness/audio/media), screenshots, clipboard history, autostarts.
- **`hypr/zprofile-snippet`** — auto-launch Hyprland from tty1.

## Manual steps the scripts cannot do

1. **GitHub SSH key** — generate on laptop, paste pubkey at github.com/settings/keys.
1. **`GITHUB_TOKEN`** — new token at github.com/settings/tokens, scopes `repo` + `read:org`. Paste into `~/.claude/settings.json`. **Do not reuse the PC’s token.**
1. **Claude Code hooks** — re-add to `~/.claude/settings.json`:
- `SessionStart` → `~/.claude/scripts/vault-session-context.sh`
- `UserPromptSubmit` → `~/.claude/scripts/inject-time.sh`
- `PostToolUse` (Edit|Write|MultiEdit) → `~/.claude/scripts/vault-autocommit.sh`
- `Stop` → `~/.claude/scripts/vault-autopush.sh`
1. **MCP re-auth** — Claude Code → Settings → Integrations, connect each.
1. **Browser** — open Zen, sign into Google, sign into password manager. Done.
1. **Bluetooth pairing** — `blueman-applet` or `bluetoothctl`.

## MVP test sequence

Verify in order:

1. `Hyprland` launches from tty1, waybar visible
1. `Super+Enter` opens ghostty
1. `claude` runs in the terminal, MCPs reconnect after re-auth
1. `Super+O` opens Obsidian on the vault
1. `/checkin` works (SessionStart hook fires, biohacking 5 rounds run, journal written)
1. Vault auto-commit fires on the new journal entry — `git -C ~/vault log -1` shows it

If all 6 pass, production.

## Day-one keybind cheatsheet

|Bind                             |Action                   |
|---------------------------------|-------------------------|
|`Super+Enter`                    |ghostty                  |
|`Super+B`                        |Zen browser              |
|`Super+O`                        |Obsidian                 |
|`Super+D`                        |fuzzel launcher          |
|`Super+E`                        |nautilus                 |
|`Super+Q`                        |kill window              |
|`Super+F`                        |fullscreen               |
|`Super+V`                        |float toggle             |
|`Super+X`                        |clipboard history        |
|`Super+Shift+R`                  |reload Hyprland          |
|`Super+Shift+E`                  |exit Hyprland            |
|`Super+1..9`                     |workspace                |
|`Super+Shift+1..9`               |move window to workspace |
|`Super+h/j/k/l`                  |focus left/down/up/right |
|`Print`                          |screenshot area → satty  |
|`Shift+Print`                    |screenshot screen → satty|
|`XF86MonBrightnessUp/Down`       |brightness ±5%           |
|`XF86AudioRaiseVolume/Lower/Mute`|volume                   |

Workspace spine: 1 = terminal/claude code, 2 = browser, 3 = obsidian.