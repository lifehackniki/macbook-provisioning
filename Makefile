PWD := $(shell pwd)
HOSTNAME := $(shell hostname -s)

.PHONY: link unlink link/home link/config copy/claude setup package/install package/cleanup package/check package/dump yazi/install npm/install bettertouchtool/export bettertouchtool/import

link: link/home link/config copy/claude

link/home:
	ln -Fs $(PWD)/zsh/zshrc $(HOME)/.zshrc
	ln -Fs $(PWD)/git/gitconfig $(HOME)/.gitconfig
	ln -Fs $(PWD)/vim/vimrc $(HOME)/.vimrc
	ln -Fs $(PWD)/aerospace/aerospace.$(HOSTNAME).toml $(HOME)/.aerospace.toml
	mkdir -p $(HOME)/bin
	ln -Fs $(PWD)/bin/takt $(HOME)/bin/takt
	ln -Fs $(PWD)/bin/mdview $(HOME)/bin/mdview
	ln -Fs $(PWD)/tmux/tmux.conf $(HOME)/.tmux.conf

link/config:
	mkdir -p $(HOME)/.codex
	ln -Fs $(PWD)/codex/config.toml $(HOME)/.codex/config.toml
	mkdir -p $(HOME)/.config/ghostty
	ln -Fs $(PWD)/ghostty/config $(HOME)/.config/ghostty/config
	mkdir -p $(HOME)/.config/borders
	ln -Fs $(PWD)/borders/bordersrc $(HOME)/.config/borders/bordersrc
	mkdir -p $(HOME)/.config/karabiner
	ln -Fs $(PWD)/karabiner/karabiner.json $(HOME)/.config/karabiner/karabiner.json
	mkdir -p $(HOME)/.config/peco
	ln -Fs $(PWD)/peco/config.json $(HOME)/.config/peco/config.json
	mkdir -p $(HOME)/.config/yazi
	ln -Fs $(PWD)/yazi/yazi.toml $(HOME)/.config/yazi/yazi.toml
	ln -Fs $(PWD)/yazi/keymap.toml $(HOME)/.config/yazi/keymap.toml
	ln -Fs $(PWD)/yazi/init.lua $(HOME)/.config/yazi/init.lua
	ln -Fs $(PWD)/yazi/package.toml $(HOME)/.config/yazi/package.toml
	mkdir -p $(HOME)/.config/lazygit
	ln -Fs $(PWD)/lazygit/config.yml $(HOME)/.config/lazygit/config.yml

copy/claude:
	mkdir -p $(HOME)/.claude
	rsync -a --delete --exclude='skills/' --exclude='projects/' --exclude='memory/' --exclude='teams/' --exclude='tasks/' --exclude='todos/' --exclude='.credentials' --exclude='statsig/' $(PWD)/claude/ $(HOME)/.claude/

unlink:
	rm -f $(HOME)/.zshrc $(HOME)/.gitconfig $(HOME)/.vimrc $(HOME)/.aerospace.toml
	rm -f $(HOME)/bin/takt
	rm -f $(HOME)/.tmux.conf
	rm -f $(HOME)/.config/ghostty/config
	rm -f $(HOME)/.config/borders/bordersrc
	rm -f $(HOME)/.config/karabiner/karabiner.json
	rm -f $(HOME)/.config/peco/config.json
	rm -rf $(HOME)/.config/yazi
	rm -f $(HOME)/.codex/config.toml
	rm -f $(HOME)/.claude/CLAUDE.md $(HOME)/.claude/settings.json $(HOME)/.claude/statusline.sh $(HOME)/.claude/notify.sh
	rm -rf $(HOME)/.claude/agents

setup:
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

package/install:
	brew bundle

package/cleanup:
	brew bundle cleanup

package/check:
	brew bundle check

package/dump:
	brew bundle dump --force

yazi/install:
	ya pkg install

npm/install:
	cat npm/global-packages.txt | xargs npm install -g

bettertouchtool/export:
	osascript -e 'tell application "BetterTouchTool" to export_preset "Default" outputPath "$(PWD)/bettertouchtool/default.bttpreset"'

bettertouchtool/import:
	osascript -e 'tell application "BetterTouchTool" to import_preset "$(PWD)/bettertouchtool/default.bttpreset"'

