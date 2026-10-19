#!/bin/bash
# ============================================================
# The MOAM Powerhouse — Mac Installer
# One command installs everything you need.
# ============================================================

set -e

# When this script is run as `curl ... | bash`, stdin is the pipe rather than
# the keyboard. Homebrew then cannot prompt for a password and aborts with
# "Running in non-interactive mode because `stdin` is not a TTY" followed by
# "Need sudo access on macOS". Reattaching stdin to the terminal fixes it and
# keeps the simple one-line install command working.
# Found live on the first real install, Aug 5 2026.
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec < /dev/tty
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
doing() { echo -e "  ${YELLOW}→${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
step()  { echo -e "\n${BOLD}[$1 of 7] $2${NC}"; }

REPO="manonamission-coaching/moam-powerhouse"
FOLDER="moam-powerhouse"
WORKSPACE="$HOME/Documents/$FOLDER"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   The MOAM Powerhouse — Mac Installer    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "This sets up your AI agent in about 5-15 minutes."
echo "You'll interact twice (both times your browser will open)."
echo ""

# --- Step 1: Homebrew ---
step 1 "Checking Homebrew (the app installer)"
if command -v brew &>/dev/null; then
  pass "Homebrew already installed"
else
  doing "Installing Homebrew — this may ask for your Mac password"
  echo ""
  echo -e "  ${YELLOW}NOTE: When you type your password, nothing appears on screen.${NC}"
  echo -e "  ${YELLOW}No dots, no stars. That's normal. Type it and press Enter.${NC}"
  echo ""
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -q 'homebrew/bin/brew shellenv' ~/.zshrc 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  fi
  command -v brew &>/dev/null && pass "Homebrew installed" || { fail "Homebrew failed. Run the installer again."; exit 1; }
fi

# --- Step 2: GitHub CLI ---
step 2 "Checking GitHub CLI (connects to the skill library)"
if command -v gh &>/dev/null; then
  pass "GitHub CLI already installed"
else
  doing "Installing GitHub CLI..."
  brew install gh
  command -v gh &>/dev/null && pass "GitHub CLI installed" || { fail "GitHub CLI failed."; exit 1; }
fi

# --- Step 3: GitHub Auth ---
step 3 "Connecting to GitHub"
if gh auth status &>/dev/null; then
  GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
  pass "Already connected as ${BOLD}$GH_USER${NC}"
else
  doing "Opening your browser to connect to GitHub..."
  echo ""
  echo -e "  ${YELLOW}You'll see an 8-character code (like 3F47-3074).${NC}"
  echo -e "  ${YELLOW}Copy it, press Enter to open the browser, paste it, Authorize, come back.${NC}"
  echo ""
  gh auth login --hostname github.com --git-protocol https --web
  gh auth status &>/dev/null && pass "Connected" || { fail "GitHub connection failed. Try again."; exit 1; }
fi

# --- Step 4: Download the workspace ---
step 4 "Downloading your MOAM Powerhouse"
if [[ -d "$WORKSPACE" && -f "$WORKSPACE/CLAUDE.md" ]]; then
  pass "Workspace already exists at ~/Documents/$FOLDER"
  doing "Checking for updates..."
  if git -C "$WORKSPACE" pull --ff-only -q &>/dev/null; then pass "Up to date with the MOAM library"
  else doing "Kept your copy as it is. Inside Claude, say: get skills"; fi
else
  doing "Downloading from the MOAM skill library..."
  if ! gh api "repos/$REPO" --jq '.name' &>/dev/null; then
    fail "Can't access the MOAM Powerhouse library."
    echo ""
    echo -e "  ${YELLOW}This usually means you haven't accepted Matt's invitation yet.${NC}"
    echo -e "  ${YELLOW}Go to github.com/notifications, accept it, then run this again.${NC}"
    exit 1
  fi
  mkdir -p "$HOME/Documents"; cd "$HOME/Documents"
  gh repo clone "$REPO" "$FOLDER"
  [[ -f "$WORKSPACE/CLAUDE.md" ]] && pass "Workspace downloaded to ~/Documents/$FOLDER" || { fail "Download failed."; exit 1; }
fi

# --- Step 4b: Wire the skills (symlinks) ---
doing "Wiring your skills..."
cd "$WORKSPACE"
mkdir -p .claude/skills
for d in my-skills/*/; do
  name=$(basename "$d")
  ln -sfn "../../my-skills/$name" ".claude/skills/$name"
done
pass "Skills wired"

# --- Step 4c: Shortcuts that work from any folder ---
# Claude only sees my-skills when it opens inside the Powerhouse folder.
# These small shortcuts point back to it, so "/lets-wrap" works anywhere.
if [[ -d "$WORKSPACE/global-skills" ]]; then
  for d in "$WORKSPACE"/global-skills/*/; do
    name=$(basename "$d"); dest="$HOME/.claude/skills/$name"
    # never overwrite a skill the member made themselves
    if [[ ! -e "$dest" ]] || grep -q "MOAM-POWERHOUSE-SHORTCUT" "$dest/SKILL.md" 2>/dev/null; then
      mkdir -p "$dest"; cp "$d/SKILL.md" "$dest/SKILL.md"
    fi
  done
  pass "Shortcuts added (lets wrap works from any folder)"
fi

# --- Step 5: Claude Code ---
step 5 "Checking Claude Code (your AI agent)"
if command -v claude &>/dev/null; then
  pass "Claude Code already installed ($(claude --version 2>/dev/null || echo installed))"
else
  doing "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  grep -q '.local/bin' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  if command -v claude &>/dev/null; then pass "Claude Code installed"
  else source ~/.zshrc 2>/dev/null; command -v claude &>/dev/null && pass "Claude Code installed" || { fail "Installed, but Terminal can't find it yet."; echo -e "  ${YELLOW}Quit Terminal (Cmd+Q), reopen, then type: claude --version${NC}"; }
  fi
fi

# --- Step 6: Desktop launcher ---
step 6 "Creating Desktop launcher"
LAUNCHER="$HOME/Desktop/MOAM Powerhouse.command"
cat > "$LAUNCHER" << LAUNCHER_EOF
#!/bin/bash
cd ~/Documents/$FOLDER && claude
LAUNCHER_EOF
chmod +x "$LAUNCHER"
pass "Desktop launcher created — \"MOAM Powerhouse\" on your Desktop"

# --- Step 7: Activate Claude ---
step 7 "Activating Claude Code"
echo ""
echo -e "  ${YELLOW}Almost done. Claude needs to connect to your Claude account.${NC}"
echo -e "  ${YELLOW}Your browser will open — sign in with your Claude.ai account, then come back.${NC}"
echo ""
echo -e "  Press Enter to open your browser..."
# Drop any keystrokes buffered while the install was running. Without this a
# stray Enter pressed minutes ago satisfies the prompt below instantly, the
# browser never opens, and the man lands on "Setup Complete" thinking it failed.
read -r -t 0.1 -n 10000 -s _flush 2>/dev/null || true
read -r
cd "$WORKSPACE"; claude --version &>/dev/null || true

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          Setup Complete! 🎉               ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}HOW TO START:${NC}"
echo ""
echo "  1. Double-click \"MOAM Powerhouse\" on your Desktop"
echo "  2. Type: build my mission context"
echo "  3. Follow the guided interview (~50 minutes)"
echo ""
echo -e "${BOLD}If Claude asks about trusting project settings:${NC} type y"
echo -e "${BOLD}If Claude asks to register skills:${NC} say yes, register them all"
echo ""
echo -e "  ${GREEN}You're all set. Build the consistent leader. Then scale the business.${NC}"
echo ""
