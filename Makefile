#!/usr/bin/env make
# Makefile for Worktree Tools Installation

# Configuration paths
CONFIG_DIR = $(HOME)/.config/worktree-tools
CONFIG_FILE = $(CONFIG_DIR)/config.zsh
OH_MY_ZSH_CUSTOM = $(HOME)/.oh-my-zsh/custom
CURRENT_DIR = $(shell pwd)

# Plugin files to symlink
PLUGINS = git-worktree-helper.zsh ci-helper.zsh

.PHONY: help install uninstall check-install check-uninstall

help:
	@echo "Worktree Tools Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  install    - Install worktree tools (config + oh-my-zsh plugins)"
	@echo "  uninstall  - Uninstall worktree tools (backup config, remove symlinks)"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Installation creates:"
	@echo "  - $(CONFIG_FILE)"
	@echo "  - Symlinks in $(OH_MY_ZSH_CUSTOM)/"
	@echo ""
	@echo "Uninstall backs up config and removes installation."

check-install:
	@echo "🔍 Checking installation status..."
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "❌ Config file already exists: $(CONFIG_FILE)"; \
		echo "❌ Installation aborted - worktree tools appear to already be installed"; \
		echo "💡 Run 'make uninstall' first if you want to reinstall"; \
		exit 1; \
	fi
	@for plugin in $(PLUGINS); do \
		if [ -L "$(OH_MY_ZSH_CUSTOM)/$$plugin" ]; then \
			echo "❌ Symlink already exists: $(OH_MY_ZSH_CUSTOM)/$$plugin"; \
			echo "❌ Installation aborted - worktree tools appear to already be installed"; \
			echo "💡 Run 'make uninstall' first if you want to reinstall"; \
			exit 1; \
		fi; \
	done
	@if [ ! -d "$(OH_MY_ZSH_CUSTOM)" ]; then \
		echo "❌ Oh My Zsh custom directory not found: $(OH_MY_ZSH_CUSTOM)"; \
		echo "💡 Please install Oh My Zsh first: https://ohmyz.sh/"; \
		exit 1; \
	fi
	@echo "✅ Installation checks passed"

check-uninstall:
	@echo "🔍 Checking uninstall prerequisites..."
	@if [ ! -f "$(CONFIG_FILE)" ] && [ ! -d "$(CONFIG_DIR)" ]; then \
		found_symlinks=0; \
		for plugin in $(PLUGINS); do \
			if [ -L "$(OH_MY_ZSH_CUSTOM)/$$plugin" ]; then \
				found_symlinks=1; \
				break; \
			fi; \
		done; \
		if [ $$found_symlinks -eq 0 ]; then \
			echo "❌ No installation found - nothing to uninstall"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Uninstall checks passed"

install: check-install
	@echo "🚀 Installing worktree tools..."
	@echo ""
	
	# Create config directory
	@echo "📁 Creating config directory: $(CONFIG_DIR)"
	@mkdir -p "$(CONFIG_DIR)"
	
	# Copy example config to actual config
	@echo "📋 Copying config template: config.zsh.example -> $(CONFIG_FILE)"
	@cp "$(CURRENT_DIR)/config.zsh.example" "$(CONFIG_FILE)"
	
	# Create symlinks for oh-my-zsh plugins
	@echo "🔗 Creating oh-my-zsh plugin symlinks:"
	@for plugin in $(PLUGINS); do \
		echo "  🔗 $(CURRENT_DIR)/$$plugin -> $(OH_MY_ZSH_CUSTOM)/$$plugin"; \
		ln -sf "$(CURRENT_DIR)/$$plugin" "$(OH_MY_ZSH_CUSTOM)/$$plugin"; \
	done
	
	@echo ""
	@echo "✅ Installation complete!"
	@echo ""
	@echo "📝 Next steps:"
	@echo "1. Customize your configuration:"
	@echo "   📝 Edit: $(CONFIG_FILE)"
	@echo "   💡 Update GIT_USERNAME, BRANCH_PREFIX, paths, and repository mappings"
	@echo ""
	@echo "2. Reload your shell to activate the plugins:"
	@echo "   🔄 Run: exec zsh"
	@echo "   🆕 Or open a new terminal window"
	@echo ""
	@echo "3. Verify installation:"
	@echo "   🧪 Test: wt-add --help"
	@echo "   📋 Help: git_worktree help"
	@echo ""
	@echo "🎉 Happy worktree-ing!"

uninstall: check-uninstall
	@echo "🗑️  Uninstalling worktree tools..."
	@echo ""
	
	# Backup config if it exists
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "💾 Backing up your config: $(CONFIG_FILE) -> $(CURRENT_DIR)/config.zsh.old"; \
		cp "$(CONFIG_FILE)" "$(CURRENT_DIR)/config.zsh.old"; \
	else \
		echo "ℹ️  No config file found to backup"; \
	fi
	
	# Remove symlinks
	@echo "🔗 Removing oh-my-zsh plugin symlinks:"
	@for plugin in $(PLUGINS); do \
		if [ -L "$(OH_MY_ZSH_CUSTOM)/$$plugin" ]; then \
			echo "  🗑️  Removing: $(OH_MY_ZSH_CUSTOM)/$$plugin"; \
			rm -f "$(OH_MY_ZSH_CUSTOM)/$$plugin"; \
		else \
			echo "  ℹ️  Not found: $(OH_MY_ZSH_CUSTOM)/$$plugin"; \
		fi; \
	done
	
	# Remove config directory
	@if [ -d "$(CONFIG_DIR)" ]; then \
		echo "🗂️  Removing config directory: $(CONFIG_DIR)"; \
		rm -rf "$(CONFIG_DIR)"; \
	else \
		echo "ℹ️  Config directory not found: $(CONFIG_DIR)"; \
	fi
	
	@echo ""
	@echo "✅ Uninstall complete!"
	@echo ""
	@echo "📝 Summary:"
	@if [ -f "$(CURRENT_DIR)/config.zsh.old" ]; then \
		echo "💾 Your config has been backed up to: $(CURRENT_DIR)/config.zsh.old"; \
	fi
	@echo "🗑️  Custom scripts are no longer installed"
	@echo "🔄 Restart your shell or run 'exec zsh' to complete removal"
	@echo ""
	@echo "💡 To reinstall: make install"