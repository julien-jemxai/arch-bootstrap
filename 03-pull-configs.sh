#!/usr/bin/env bash
# arch-bootstrap / 03-pull-configs.sh
# Pulls dot-claude + vault from GitHub. Both are private, so SSH key must be on GitHub first.

set -euo pipefail

msg() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run as your normal user, not root."

# --- SSH precheck ---------------------------------------------------------
# `ssh -T git@github.com` exits 1 on success (GitHub returns a greeting then
# closes the connection). It exits 255 if auth fails. Distinguish them.
msg "Checking GitHub SSH auth"
ssh_output=$(ssh -T -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 || true)
if echo "$ssh_output" | grep -q "successfully authenticated"; then
  echo "  OK: $(echo "$ssh_output" | head -1)"
else
  cat <<EOF

!!! GitHub SSH auth failed.

You need to:
  1. Generate a key:    ssh-keygen -t ed25519 -C "legion-laptop"
  2. Add it to GitHub:  cat ~/.ssh/id_ed25519.pub
                        (paste at https://github.com/settings/keys)
  3. Re-run this script.

Output from ssh -T git@github.com:
$ssh_output
EOF
  exit 1
fi

# --- dot-claude -----------------------------------------------------------
if [[ -d ~/.claude ]]; then
  msg "~/.claude already exists, skipping clone"
else
  msg "Cloning dot-claude → ~/.claude"
  git clone git@github.com:julien-jemxai/dot-claude.git ~/.claude
fi

# --- vault ----------------------------------------------------------------
if [[ -d ~/vault ]]; then
  msg "~/vault already exists, skipping clone"
else
  msg "Cloning vault → ~/vault"
  git clone git@github.com:julien-jemxai/vault.git ~/vault
fi

# --- Manual checklist -----------------------------------------------------
cat <<'EOF'

============================================================
 03-pull-configs.sh DONE — repos cloned.

 MANUAL STEPS REMAINING (cannot be scripted):

 1. Generate a new GitHub token (NOT the PC's):
      https://github.com/settings/tokens
      Scopes: repo, read:org
      Paste into ~/.claude/settings.json as GITHUB_TOKEN.

 2. Re-create ~/.claude/settings.json hooks block:
      - SessionStart      → ~/.claude/scripts/vault-session-context.sh
      - UserPromptSubmit  → ~/.claude/scripts/inject-time.sh
      - PostToolUse (Edit|Write|MultiEdit)
                          → ~/.claude/scripts/vault-autocommit.sh
      - Stop              → ~/.claude/scripts/vault-autopush.sh

 3. Open Claude Code and re-auth each MCP:
      Settings → Integrations → connect each one (~5-10 min)

 4. Sign into browser fresh — no sync needed, just sign into Google
    + password manager (if you use one).

 5. Run the MVP test sequence from the README.
============================================================
EOF
