.DEFAULT_GOAL := test
.PHONY: check-syntax test

check-syntax:
	zsh -f -n jev-fzf.plugin.zsh

test: check-syntax
	zsh -f tests/plugin.zsh
	zsh -f tests/interactive.zsh
