#!/usr/bin/env bash
# arch-bootstrap / 04-harden.sh
# Sensible-defaults hardening: ufw firewall, locked-down sshd, fail2ban,
# kernel sysctls, DNS-over-HTTPS via systemd-resolved.
# Run AFTER 01-bootstrap.sh and 02-qol.sh.
#
# This script is intentionally NOT paranoid:
# - no AppArmor/SELinux churn
# - no USBGuard (would block your fife/drum corps audio gear, ham radio TNCs, etc.)
# - no umask 077 (breaks too many things)
# It hardens the network attack surface, which is the realistic threat for a laptop.

set -euo pipefail

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33m!!! %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run as your normal user, not root. sudo is invoked where needed."
command -v paru >/dev/null || die "paru not found. Run 01-bootstrap.sh first."

# --- SSH port choice ------------------------------------------------------
# Non-standard port discourages drive-by scanners. Not real security
# (anyone targeting you will nmap), but cuts log noise dramatically.
SSH_PORT="${SSH_PORT:-2222}"

# --- 1. Firewall (ufw) ----------------------------------------------------
msg "Installing + configuring ufw"
paru -S --noconfirm --needed ufw

# Default: deny all incoming, allow all outgoing. The laptop initiates
# connections; it doesn't need to accept them (except sshd below).
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow sshd on the chosen port, rate-limited (ufw drops 6+ conns in 30s).
sudo ufw limit "${SSH_PORT}/tcp" comment 'sshd (rate-limited)'

# Allow mDNS for local discovery (printers, Chromecast, etc.). Comment
# out if you don't want it.
sudo ufw allow in proto udp to 224.0.0.251 port 5353 comment 'mDNS'

# Allow Bluetooth obex push (file transfer). Optional.
# sudo ufw allow proto tcp to any port 4358 comment 'obex'

sudo ufw --force enable
sudo systemctl enable --now ufw

# --- 2. SSH (locked down) -------------------------------------------------
msg "Installing + locking down sshd"
paru -S --noconfirm --needed openssh

# Generate host keys if not present (some installs skip this)
sudo ssh-keygen -A

# Write a drop-in config — non-destructive, overrides /etc/ssh/sshd_config
sudo install -d -m 755 /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<EOF
# Managed by arch-bootstrap/04-harden.sh
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
AuthenticationMethods publickey
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
MaxAuthTries 3
MaxSessions 4
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
# Strong crypto only
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
# Only allow your user — replace if your username isn't 'crom'
AllowUsers crom
EOF

# Validate before reloading
sudo sshd -t || die "sshd config invalid, not enabling"

# Don't auto-start sshd — enable manually when you actually need it.
# `sudo systemctl start sshd` to bring it up for a session.
sudo systemctl disable sshd 2>/dev/null || true

# --- 3. fail2ban ----------------------------------------------------------
msg "Installing fail2ban (in case sshd is on)"
paru -S --noconfirm --needed fail2ban

sudo install -d -m 755 /etc/fail2ban/jail.d
sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled = true
port    = ${SSH_PORT}
EOF

sudo systemctl enable --now fail2ban

# --- 4. Kernel hardening (sysctls) ---------------------------------------
msg "Applying kernel sysctl hardening"
sudo tee /etc/sysctl.d/99-hardening.conf >/dev/null <<'EOF'
# Managed by arch-bootstrap/04-harden.sh

# --- Network ---
# Ignore ICMP broadcast (smurf attack mitigation)
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1
# Reverse path filtering (drop spoofed packets)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Don't accept ICMP redirects (MITM risk)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
# Don't accept source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# Log martian packets
net.ipv4.conf.all.log_martians = 1
# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

# --- Kernel ---
# Restrict kernel pointer access (dmesg, /proc/kallsyms)
kernel.kptr_restrict = 2
# Restrict dmesg to root
kernel.dmesg_restrict = 1
# Disable kexec (prevents loading new kernel at runtime)
kernel.kexec_load_disabled = 1
# Restrict unprivileged BPF (recent CVEs)
kernel.unprivileged_bpf_disabled = 1
# Harden BPF JIT
net.core.bpf_jit_harden = 2
# Restrict ptrace to parent process only
kernel.yama.ptrace_scope = 1
# Disable SysRq (mostly — leave reboot/sync available with 4)
kernel.sysrq = 4

# --- Filesystem ---
# Prevent symlink/hardlink attacks in world-writable dirs (/tmp)
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
# Restrict core dumps from setuid binaries
fs.suid_dumpable = 0
EOF

sudo sysctl --system >/dev/null

# --- 5. DNS-over-HTTPS via systemd-resolved -------------------------------
msg "Configuring DNS-over-HTTPS (Cloudflare + Quad9 fallback)"
sudo install -d -m 755 /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dns-over-tls.conf >/dev/null <<'EOF'
# Managed by arch-bootstrap/04-harden.sh
# DNS-over-TLS to Cloudflare + Quad9. (systemd-resolved supports DoT, not DoH —
# same encryption guarantee, different transport. For true DoH use dnscrypt-proxy.)
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8 8.8.4.4
DNSOverTLS=yes
DNSSEC=allow-downgrade
Cache=yes
ReadEtcHosts=yes
EOF

# Make NetworkManager use systemd-resolved as the DNS backend
sudo install -d -m 755 /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
systemd-resolved=true
EOF

# Point /etc/resolv.conf at systemd-resolved's stub resolver
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sudo systemctl enable --now systemd-resolved
sudo systemctl restart NetworkManager

# --- 6. Disable common attack-surface services ---------------------------
msg "Disabling unused services"
# Bluetooth was enabled by 02-qol.sh — keep it. If you don't use BT, run:
#   sudo systemctl disable --now bluetooth
# CUPS (printing) — not installed by default in our stack, no action needed.
# Avahi — same, only installed if you pulled it in for mDNS.

# --- Audit verification --------------------------------------------------
msg "Verification"

echo
echo "--- ufw status ---"
sudo ufw status verbose

echo
echo "--- sshd status (should be 'disabled'; start manually when needed) ---"
sudo systemctl is-enabled sshd 2>/dev/null || echo "disabled"
sudo systemctl is-active sshd 2>/dev/null || echo "inactive"

echo
echo "--- fail2ban ---"
sudo systemctl is-active fail2ban

echo
echo "--- DNS resolution check (should show DoT=yes, +DNS-over-TLS) ---"
resolvectl status | grep -E "DNS Servers|DNS-over-TLS|DNSSEC" | head -10 || true

echo
echo "--- Quick sysctl spot-check ---"
sysctl kernel.kptr_restrict kernel.dmesg_restrict net.ipv4.tcp_syncookies fs.protected_symlinks

# --- Done -----------------------------------------------------------------
cat <<EOF

============================================================
 04-harden.sh DONE.

 What's active now:
   - ufw: deny incoming except sshd on port ${SSH_PORT} (rate-limited)
   - sshd: configured + disabled. Start when needed:
       sudo systemctl start sshd
     Stop when done:
       sudo systemctl stop sshd
   - fail2ban: watching sshd, 3 strikes = 1h ban
   - sysctls: kernel + network hardening applied
   - DNS: encrypted via DoT to Cloudflare + Quad9

 To SSH INTO this laptop from elsewhere:
   ssh -p ${SSH_PORT} crom@<laptop-ip>
   (And first: copy your other machine's pubkey to ~/.ssh/authorized_keys here.
    No password auth — keys only.)

 Verify DNS is encrypted (Wireshark on port 53 should show nothing,
 port 853 should show TLS to 1.1.1.1):
   resolvectl status
   resolvectl query example.com

 To temporarily disable a rule for debugging:
   sudo ufw disable      # firewall off
   sudo ufw enable       # back on
============================================================
EOF
