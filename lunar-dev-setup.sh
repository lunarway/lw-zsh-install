#!/usr/bin/env zsh
# ============================================================================
#
#   LUNAR DEVELOPER ONBOARDING
#   One-command setup for a fresh Mac
#
#   Usage (one-liner):
#     /bin/zsh -c "$(curl -fsSL <HOSTED_URL>)"
#
#   Or if you have the file locally:
#     zsh lunar-dev-setup.sh
#
#   This script is idempotent — safe to run multiple times.
#   It will skip steps that are already completed.
#
#   Questions? → #empower on Slack
#
# ============================================================================

set -e

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

step()   { echo "\n${BLUE}${BOLD}==> $1${NC}" }
ok()     { echo "  ${GREEN}OK${NC} $1" }
warn()   { echo "  ${YELLOW}!!${NC} $1" }
fail()   { echo "  ${RED}ERROR${NC} $1" }
info()   { echo "  ${BOLD}$1${NC}" }
manual() { echo "  ${YELLOW}MANUAL STEP${NC} $1" }

pause_for_user() {
  echo ""
  echo "  ${YELLOW}▸ Press Enter when you have completed the step above...${NC}"
  read -r
}

# ---------------------------------------------------------------------------
# Phase 0 — Collect developer info
# ---------------------------------------------------------------------------
echo ""
echo "${BOLD}============================================${NC}"
echo "${BOLD}  Welcome to Lunar! Let's get you set up.${NC}"
echo "${BOLD}============================================${NC}"
echo ""

# Ask for email
LUNAR_EMAIL=""
while [[ -z "$LUNAR_EMAIL" || "$LUNAR_EMAIL" != *"@lunar.app" ]]; do
  echo -n "  Your Lunar email (e.g. jda@lunar.app): "
  read -r LUNAR_EMAIL
  if [[ "$LUNAR_EMAIL" != *"@lunar.app" ]]; then
    warn "Email must end with @lunar.app"
  fi
done

# Ask for full name
LUNAR_NAME=""
while [[ -z "$LUNAR_NAME" ]]; do
  echo -n "  Your full name: "
  read -r LUNAR_NAME
done

echo ""
ok "Email: $LUNAR_EMAIL"
ok "Name:  $LUNAR_NAME"

# ---------------------------------------------------------------------------
# Phase 1 — System prerequisites
# ---------------------------------------------------------------------------
step "Phase 1/10 — System prerequisites"

# 1a. Rosetta 2 (Apple Silicon only)
if [[ "$(uname -m)" == "arm64" ]]; then
  if /usr/bin/pgrep -q oahd 2>/dev/null; then
    ok "Rosetta 2 already installed"
  else
    info "Installing Rosetta 2 (needed for some Lunar tools)..."
    softwareupdate --install-rosetta --agree-to-license 2>/dev/null
    ok "Rosetta 2 installed"
  fi
fi

# 1b. Homebrew
if command -v brew &>/dev/null; then
  ok "Homebrew already installed"
else
  info "Installing Homebrew (this may take a few minutes)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add to PATH for this session (Apple Silicon vs Intel)
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Persist for future shells
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew installed"
fi

# Ensure brew is in PATH for this session
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# Phase 2 — Core tools
# ---------------------------------------------------------------------------
step "Phase 2/10 — Installing core tools"

for pkg in git gh go; do
  if command -v "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    info "Installing $pkg..."
    brew install "$pkg"
    ok "$pkg installed"
  fi
done

# ---------------------------------------------------------------------------
# Phase 3 — SSH key setup
# ---------------------------------------------------------------------------
step "Phase 3/10 — SSH key setup"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

SSH_KEY_PATH="$HOME/.ssh/github"

if [[ -f "$SSH_KEY_PATH" ]]; then
  ok "SSH key already exists at $SSH_KEY_PATH"
else
  info "Generating SSH key pair at $SSH_KEY_PATH"
  info "(No passphrase — required for headless Docker builds with shuttle)"
  ssh-keygen -t rsa -b 4096 -m pem -f "$SSH_KEY_PATH" -N "" -C "$LUNAR_EMAIL"
  ok "SSH key generated"
fi

# SSH config — support both traditional key AND 1Password agent
ONEPASSWORD_AGENT="~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EXPANDED_AGENT="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
HAS_1PASSWORD_AGENT=false

if [[ -S "$EXPANDED_AGENT" ]]; then
  HAS_1PASSWORD_AGENT=true
fi

# Write SSH config
if [[ -f ~/.ssh/config ]] && grep -q "Host github.com" ~/.ssh/config; then
  ok "SSH config for github.com already exists"
else
  if $HAS_1PASSWORD_AGENT; then
    cat >> ~/.ssh/config <<SSHEOF

# 1Password SSH agent for day-to-day terminal use (recommended)
Host *
  IdentityAgent "$ONEPASSWORD_AGENT"

# GitHub: also reference the local key for shuttle Docker builds
Host github.com
  IdentityAgent "$ONEPASSWORD_AGENT"
  IdentityFile $SSH_KEY_PATH
  ForwardAgent yes
SSHEOF
    ok "SSH config updated (1Password agent + local key fallback)"
  else
    cat >> ~/.ssh/config <<SSHEOF

Host github.com
  IdentityFile $SSH_KEY_PATH
  ForwardAgent yes
  UseKeychain yes
  AddKeysToAgent yes
SSHEOF
    ok "SSH config updated (local key)"
  fi
  chmod 600 ~/.ssh/config
fi

# Add key to local agent
ssh-add "$SSH_KEY_PATH" 2>/dev/null || true

# 1Password agent.toml — enable SSH keys from shared vaults (e.g. Employee)
if $HAS_1PASSWORD_AGENT; then
  AGENT_TOML="$HOME/.config/1Password/ssh/agent.toml"
  if [[ -f "$AGENT_TOML" ]]; then
    ok "1Password agent config already exists at $AGENT_TOML"
  else
    mkdir -p "$(dirname "$AGENT_TOML")"
    cat > "$AGENT_TOML" <<'TOMLEOF'
# Allow SSH keys from shared 1Password vaults to be used by the SSH agent.
# Without this, only keys in Personal/Private vaults are auto-discovered.
# See: https://developer.1password.com/docs/ssh/agent/config/

[[ssh-keys]]
vault = "Employee"
TOMLEOF
    ok "Created $AGENT_TOML (enables SSH keys from Employee vault)"
    info "Restart 1Password for this to take effect."
  fi
fi

# ---------------------------------------------------------------------------
# Phase 4 — GitHub CLI authentication
# ---------------------------------------------------------------------------
step "Phase 4/10 — GitHub CLI authentication"

if gh auth status &>/dev/null; then
  ok "GitHub CLI already authenticated"
else
  info "Authenticating to GitHub..."
  info "This will open your browser. Authorize the app when prompted."
  echo ""
  gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --web
  ok "GitHub CLI authenticated"
fi

# Configure git to use SSH for all GitHub URLs
git config --global url."git@github.com:".insteadOf "https://github.com/"
ok "Git configured to use SSH for GitHub"

# ---------------------------------------------------------------------------
# Phase 5 — Upload SSH key to GitHub
# ---------------------------------------------------------------------------
step "Phase 5/10 — Upload SSH key to GitHub"

# Check if our key is already on GitHub
EXISTING_KEYS=$(gh ssh-key list 2>/dev/null || echo "")

if echo "$EXISTING_KEYS" | grep -q "Lunar"; then
  ok "SSH key already on GitHub"
else
  info "Uploading SSH key as authentication key..."
  gh ssh-key add "${SSH_KEY_PATH}.pub" --title "Lunar Dev Key" --type authentication 2>/dev/null && \
    ok "Authentication key uploaded" || warn "Key may already exist"

  info "Uploading SSH key as signing key..."
  gh ssh-key add "${SSH_KEY_PATH}.pub" --title "Lunar Dev Key (signing)" --type signing 2>/dev/null && \
    ok "Signing key uploaded" || warn "Key may already exist"
fi

# --- SSO Authorization (CANNOT be automated) ---
# Skip if SSH already works (keys already authorized from a previous run)
SSH_PRE_CHECK=$(ssh -T git@github.com 2>&1 || true)
if [[ "$SSH_PRE_CHECK" =~ "^Hi " ]]; then
  GITHUB_USER=$(echo "$SSH_PRE_CHECK" | sed 's/Hi \(.*\)!.*/\1/')
  ok "SSH already works — authenticated as $GITHUB_USER, skipping SSO step"
else
  echo ""
  echo "  ${RED}${BOLD}ACTION REQUIRED — Authorize your SSH keys for SAML SSO${NC}"
  echo ""
  echo "  GitHub requires you to authorize SSH keys for the lunarway org."
  echo "  This step cannot be automated and must be done in your browser."
  echo ""
  echo "  1. Open: ${BLUE}https://github.com/settings/keys${NC}"
  echo "  2. Find your '${BOLD}Lunar Dev Key${NC}' entries (auth + signing)"
  echo "  3. Click '${BOLD}Configure SSO${NC}' next to each key"
  echo "  4. Click '${BOLD}Authorize${NC}' next to '${BOLD}lunarway${NC}'"
  echo "  5. Do this for BOTH the authentication key AND the signing key"
  echo ""

  # Open the page for them
  open "https://github.com/settings/keys" 2>/dev/null || true

  pause_for_user

  # Verify SSH access after user completes SSO
  info "Verifying SSH access to GitHub..."
  SSH_TEST=$(ssh -T git@github.com 2>&1 || true)
  if [[ "$SSH_TEST" =~ "^Hi " ]]; then
    GITHUB_USER=$(echo "$SSH_TEST" | sed 's/Hi \(.*\)!.*/\1/')
    ok "SSH works — authenticated as $GITHUB_USER"
  else
    fail "SSH to GitHub failed. Output: $SSH_TEST"
    echo ""
    echo "  Common fixes:"
    echo "  - Did you authorize SSO for BOTH keys? (auth + signing)"
    echo "  - Is 1Password open and unlocked? (if using 1Password SSH agent)"
    echo "  - Try: ssh-add $SSH_KEY_PATH"
    echo ""
    echo "  You can continue and fix SSH later, or press Ctrl-C to abort."
    pause_for_user
  fi
fi

# ---------------------------------------------------------------------------
# Phase 6 — lw-zsh (Lunar terminal setup)
# ---------------------------------------------------------------------------
step "Phase 6/10 — Installing lw-zsh (Lunar terminal setup)"

if [[ -d "$HOME/.zplug/repos/lunarway/lw-zsh" ]]; then
  ok "lw-zsh already installed"
else
  # Clean up a partial zplug install (from a previous failed run) so zplug
  # can clone itself fresh. zplug refuses to install if ~/.zplug already exists.
  if [[ -d "$HOME/.zplug" && ! -f "$HOME/.zplug/init.zsh" ]]; then
    warn "Removing incomplete ~/.zplug from a previous run..."
    rm -rf "$HOME/.zplug"
  fi

  # Install zplug directly via git clone if needed.
  # The upstream zplug installer (zplug/installer/master/installer.zsh) is flaky
  # and fails silently in non-interactive shells. Cloning directly is reliable.
  if [[ ! -f "$HOME/.zplug/init.zsh" ]]; then
    info "Installing zplug..."
    git clone https://github.com/zplug/zplug.git "$HOME/.zplug" 2>&1
    if [[ -f "$HOME/.zplug/init.zsh" ]]; then
      ok "zplug installed"
    else
      fail "Failed to install zplug"
      echo "  Try manually: git clone https://github.com/zplug/zplug.git ~/.zplug"
    fi
  else
    ok "zplug already installed"
  fi

  info "Downloading lw-zsh installer..."
  curl -sL -o /tmp/install-lw-zsh.zsh \
    https://raw.githubusercontent.com/lunarway/lw-zsh-install/master/install.sh

  # Patch the installer to skip interactive prompts (vared can't read from pipes)
  # The installer uses vared for 3 inputs: email, LW_PATH, GOPATH
  # We replace the vared calls with direct variable assignments
  sed -i '' "s|vared -p \"Please specify your Lunar email: \" -c email|email=\"${LUNAR_EMAIL}\"|" /tmp/install-lw-zsh.zsh
  # LW_PATH and GOPATH are already set to defaults before vared; just remove the vared lines
  sed -i '' '/vared -p "Please specify the path to where all Lunar repositories will be stored: " -c lwPath/d' /tmp/install-lw-zsh.zsh
  sed -i '' '/vared -p "Please specify the Go path: " -c goPath/d' /tmp/install-lw-zsh.zsh

  info "Running lw-zsh installer (this installs shuttle, hamctl, kubectl, etc.)..."
  # Explicitly pass Homebrew's PATH and TERM so git and tput work in subshells.
  # Set ZPLUG_HOME so the installer takes the "update" path (zplug already cloned above).
  BREW_BIN=""
  if [[ -f /opt/homebrew/bin/brew ]]; then
    BREW_BIN="/opt/homebrew/bin:/opt/homebrew/sbin"
  elif [[ -f /usr/local/bin/brew ]]; then
    BREW_BIN="/usr/local/bin"
  fi

  PATH="${BREW_BIN}:${PATH}" TERM="${TERM:-xterm-256color}" ZPLUG_HOME="$HOME/.zplug" zsh /tmp/install-lw-zsh.zsh

  # Don't trust the exit code — the upstream installer returns 0 on failure.
  # Verify that lw-zsh was actually installed.
  if [[ -d "$HOME/.zplug/repos/lunarway/lw-zsh" ]]; then
    ok "lw-zsh installed"
  else
    fail "lw-zsh installation failed"
    echo ""
    echo "  Try manually in a new terminal:"
    echo "  curl -sL -o install-lw-zsh.zsh https://raw.githubusercontent.com/lunarway/lw-zsh-install/master/install.sh && zsh install-lw-zsh.zsh"
    echo ""
  fi

  rm -f /tmp/install-lw-zsh.zsh
fi

# Set env vars for the rest of this script
export LW_PATH=~/lunar
export GOPATH=~/go
export PATH="$GOPATH/bin:$PATH"
mkdir -p "$LW_PATH" "$GOPATH"

# ---------------------------------------------------------------------------
# Phase 7 — Git identity + signed commits
# ---------------------------------------------------------------------------
step "Phase 7/10 — Git identity and signed commits"

GITCONFIG_LW="$HOME/.gitconfig_lw"
GITCONFIG="$HOME/.gitconfig"

# Create ~/.gitconfig_lw with identity + signing config
# (This does what lw-git-config does, PLUS sets up signed commits)
cat > "$GITCONFIG_LW" <<GITLWEOF
[user]
    name = $LUNAR_NAME
    email = $LUNAR_EMAIL
    signingkey = ${SSH_KEY_PATH}.pub
[commit]
    gpgsign = true
[gpg]
    format = ssh
GITLWEOF

ok "Created $GITCONFIG_LW (identity + signed commits)"

# Add includeIf directives to ~/.gitconfig (if not already present)
if grep -q "gitconfig_lw" "$GITCONFIG" 2>/dev/null; then
  ok "includeIf for Lunar repos already in .gitconfig"
else
  cat >> "$GITCONFIG" <<GITEOF

[includeIf "gitdir/i:~/lunar/"]
  path = .gitconfig_lw
[includeIf "gitdir/i:~/go/src/github.com/lunarway/"]
  path = .gitconfig_lw
GITEOF
  ok "Added includeIf directives to .gitconfig"
fi

# ---------------------------------------------------------------------------
# Phase 8 — hamctl login
# ---------------------------------------------------------------------------
step "Phase 8/10 — hamctl login (Okta authentication)"

echo ""
echo "  hamctl authenticates via Okta using a browser-based device flow."
echo "  This step ${BOLD}cannot be automated${NC} — it will open your browser."
echo "  Just click '${BOLD}Submit${NC}' when the Okta page opens."
echo ""

# Try to source lw-zsh to get hamctl in PATH
if [[ -f "$HOME/.zshrc" ]]; then
  # Source minimally to get PATH set up
  export PATH="$GOPATH/bin:$HOME/.zplug/repos/lunarway/lw-zsh/bin:$PATH"
fi

if command -v hamctl &>/dev/null; then
  hamctl login || {
    warn "hamctl login failed or was skipped."
    manual "Run 'hamctl login' in a new terminal later."
  }
else
  warn "hamctl not in PATH yet (needs a new terminal after lw-zsh install)."
  manual "Open a new terminal and run: hamctl login"
fi

# ---------------------------------------------------------------------------
# Phase 9 — AI agent skills (lunarctl agent)
# ---------------------------------------------------------------------------
step "Phase 9/10 — AI agent skills"

# lunarctl needs LUNARCTL_REGISTRY to find extensions
export LUNARCTL_REGISTRY="$HOME/.lunarctl/registry"

# Try to get lunarctl in PATH
LUNARCTL_BIN=""
if command -v lunarctl &>/dev/null; then
  LUNARCTL_BIN="lunarctl"
elif [[ -x "$GOPATH/bin/lunarctl" ]]; then
  LUNARCTL_BIN="$GOPATH/bin/lunarctl"
fi

if [[ -n "$LUNARCTL_BIN" ]]; then
  # Run doctor to check prerequisites
  info "Running lunarctl agent skills doctor..."
  if $LUNARCTL_BIN agent skills doctor 2>&1; then
    ok "AI agent skills prerequisites OK"
  else
    warn "Some prerequisites missing — run 'lunarctl agent skills doctor' in a new terminal"
  fi

  echo ""
  info "Launching AI skills picker — choose which skills to enable for your editors:"
  echo ""
  $LUNARCTL_BIN agent skills select 2>&1 || {
    warn "Skills selection skipped or failed."
    manual "Run 'lunarctl agent skills select' in a new terminal later."
  }
else
  warn "lunarctl not in PATH yet (needs a new terminal after lw-zsh install)."
  manual "Open a new terminal and run: lunarctl agent skills select"
fi

# ---------------------------------------------------------------------------
# Phase 10 — Final verification & summary
# ---------------------------------------------------------------------------
step "Phase 10/10 — Verification"

PASS=0
TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" &>/dev/null; then
    ok "$1"
    PASS=$((PASS + 1))
  else
    warn "$1 — may need a new terminal"
  fi
}

check "Homebrew"      "command -v brew"
check "Git"           "command -v git"
check "GitHub CLI"    "gh auth status"
check "Go"            "command -v go"
check "SSH to GitHub" "ssh -T git@github.com 2>&1 | grep -q '^Hi '"
check "SSH key file"  "test -f $SSH_KEY_PATH"
check "gitconfig_lw"  "test -f $HOME/.gitconfig_lw"
check "lw-zsh"        "test -d $HOME/.zplug/repos/lunarway/lw-zsh"

echo ""
echo "${GREEN}${BOLD}============================================${NC}"
echo "${GREEN}${BOLD}  Setup complete! ($PASS/$TOTAL checks passed)${NC}"
echo "${GREEN}${BOLD}============================================${NC}"
echo ""
echo "  ${BOLD}IMPORTANT: Close this terminal and open a new one.${NC}"
echo "  lw-zsh needs a fresh shell to activate all tools."
echo ""
echo "  After opening a new terminal, verify with:"
echo "    ${BLUE}shuttle version${NC}"
echo "    ${BLUE}hamctl version${NC}"
echo "    ${BLUE}lunarctl --help${NC}"
echo ""
echo "  ${BOLD}Remaining manual steps:${NC}"
echo ""
echo "  1. ${BOLD}GitHub email settings${NC} (needed for hamctl Slack notifications):"
echo "     Open: ${BLUE}https://github.com/settings/emails${NC}"
echo "     → Set your Lunar email as primary"
echo "     → UNCHECK 'Keep my email addresses private'"
echo ""
echo "  2. ${BOLD}GitHub Slack integration${NC} (recommended):"
echo "     Install: ${BLUE}https://slack.com/apps/A01BP7R4KNY-github${NC}"
echo "     Then run ${BLUE}/github signin${NC} in Slack"
echo ""
echo "  3. ${BOLD}VPN${NC}: Should be pre-configured via Kandji."
echo "     If missing, ask ${BLUE}#company-it${NC} in Slack."
echo ""

# 1Password SSH agent tip
if ! $HAS_1PASSWORD_AGENT; then
  echo "  ${BOLD}Tip: 1Password SSH Agent (recommended)${NC}"
  echo "  For a more secure SSH setup, enable the 1Password SSH agent:"
  echo "  → Open 1Password → Settings → Developer → 'Use the SSH agent'"
  echo "  This lets 1Password manage your SSH keys with biometric auth."
  echo "  Your generated key at ~/.ssh/github will still work for Docker builds."
  echo ""
fi

echo "  ${BOLD}Resources:${NC}"
echo "    Backstage:  ${BLUE}https://backstage.lunar.tech${NC}"
echo "    Help:       ${BLUE}#empower${NC} on Slack"
echo "    AI docs:    ${BLUE}https://github.com/lunarway/development-platform-docs/tree/master/docs/ai${NC}"
echo ""
echo "  Welcome to Lunar! 🚀"
echo ""
