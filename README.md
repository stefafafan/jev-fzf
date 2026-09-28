# jev-fzf

A single-file zsh plugin that uses [stefafafan/jev](https://github.com/stefafafan/jev) to order your Ctrl+R history in [junegunn/fzf](https://github.com/junegunn/fzf).

> [!CAUTION]
> This will send some of your terminal history to specified providers such as TypeSafe AI, Cloudflare, or Vercel.
> Take extra caution if you enter credentials in your terminal.

## Setup

Install `stefafafan/jev`, `jq`, and `fzf`, and configure your [stefafafan/jev provider credentials](https://github.com/stefafafan/jev#providers).
Source the plugin after your existing fzf initialization in `~/.zshrc`:

```zsh
source /path/to/jev-fzf/jev-fzf.plugin.zsh
```

## What it does

Ctrl+R deduplicates history and asks Jev to rank the **50 most recent commands** using the current directory, prompt text, and five recent commands as context.

Each ranked command shows its Jev probability, rounded to one decimal place (for example, `72.4%`). Older commands and local/fallback results show `—`.
These are relative probabilities within the submitted shortlist, not calibrated predictions of your behavior.

```sh
$ <Ctrl+R>

  history>
    5/5
  > 62.4%  go test ./...
    24.1%  git diff
     9.8%  git status
     3.7%  go build ./...
        —  docker compose up
```
