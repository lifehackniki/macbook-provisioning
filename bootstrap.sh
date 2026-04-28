#!/bin/bash
set -e

REPO_URL="https://github.com/lifehackniki/macbook-provisioning.git"
REPO_DIR="$HOME/ghq/github.com/lifehackniki/macbook-provisioning"

echo "==> macOS provisioning start"

# 1. Claude Code
if ! command -v claude &>/dev/null; then
  echo "==> Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 2. Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "==> ダイアログでインストールを進めてください。完了を待っています..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  echo "==> Xcode Command Line Tools installed"
fi

# 3. Homebrew
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# 4. Clone repository
if [ ! -d "$REPO_DIR" ]; then
  echo "==> Cloning repository..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "==> Repository already exists, pulling latest..."
  git -C "$REPO_DIR" pull
fi

cd "$REPO_DIR"

# 5. Brew bundle
echo "==> Installing packages via Homebrew..."
brew bundle || echo "==> Warning: brew bundle で一部失敗がありました。後で再実行してください: brew bundle"

# 6. Symlink configs
echo "==> Linking config files..."
make link

# 7. Yazi plugins
if command -v ya &>/dev/null; then
  echo "==> Installing yazi plugins..."
  ya pkg install
fi

# 8. macOS defaults
echo "==> Applying macOS defaults..."
bash macos/defaults.sh

echo ""
echo "==> Done! ターミナルを再起動してください"
