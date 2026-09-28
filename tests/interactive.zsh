#!/usr/bin/env zsh
# Exercise real terminal job control with synthetic history and no API requests.
emulate -LR zsh
setopt errexit pipefail
cd -- ${0:A:h:h}
(( $+commands[fzf] )) || { print -u2 'fzf is required'; exit 1; }
zmodload zsh/zpty
zmodload zsh/datetime
zmodload zsh/zselect

zpty -b terminal env TERM=xterm-256color HISTFILE= JEV_FZF_NO_RANK=1 zsh -f
trap 'zpty -d terminal 2>/dev/null' EXIT
pending=''

expect() {
  local needle=$1 chunk
  local -F deadline=$(( EPOCHREALTIME + 8 ))
  while (( EPOCHREALTIME < deadline )); do
    if [[ $pending == *"$needle"* ]]; then
      pending=${pending#*"$needle"}
      return 0
    fi
    if zpty -r terminal chunk; then
      pending+=$chunk
      # Respond to fzf's cursor-position query as a terminal emulator would.
      if [[ $pending == *$'\e[6n'* ]]; then
        pending=${pending//$'\e[6n'/}
        zpty -w -n terminal $'\e[1;1R'
      fi
    else
      zselect -t 1 || true
    fi
  done
  print -ru2 -- "FAIL: expected ${(qqq)needle}; received ${(qqq)pending}"
  return 1
}

zpty -w terminal 'stty rows 30 columns 100; HISTFILE=; HISTSIZE=100; PROMPT="TEST> "; source ./jev-fzf.plugin.zsh; print -sr -- "printf widget-smoke"; inspect-buffer() { print -r -- "BUFFER_RESULT=${(qqq)BUFFER}"; BUFFER=""; zle reset-prompt; }; zle -N inspect-buffer; bindkey "^X" inspect-buffer; print JEV_FZF_READY'
expect $'\r\nJEV_FZF_READY\r\n'
# ZLE enables bracketed paste after entering raw terminal mode.
expect $'\e[?2004h'
zpty -w -n terminal $'widget-smoke\x12'
expect 'history>'
zpty -w -n terminal $'\e'
expect 'TEST> widget-smoke'
zpty -w -n terminal $'\x18'
expect 'BUFFER_RESULT="widget-smoke"'
expect 'TEST> '

# The anchored query excludes the setup command from the result list.
zpty -w -n terminal $'^printf widget-smoke$\x12'
expect 'history>'
zpty -w -n terminal $'\r'
expect 'TEST> printf widget-smoke'
zpty -w -n terminal $'\x18'
expect 'BUFFER_RESULT="printf widget-smoke"'
expect 'TEST> '
zpty -w terminal exit
print 'PASS: real Ctrl+R opens fzf; Escape preserves text; selection inserts without execution'
