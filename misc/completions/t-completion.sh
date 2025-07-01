# t: Lazy tmux wrapper - Rich Bash/Zsh Completion Script
# Save as: misc/completion/t-completion.sh
# Usage: source this file in your .zshrc or .bashrc

_t_sessions() {
  command -v tmux >/dev/null || return
  tmux ls 2>/dev/null | awk -F: '{print $1}'
}

_t_prefixkeys() {
  echo a b c d e q r s t w x z
}

_t_complete() {
  local cur prev
  local -a opts
  opts=(-A -a --attach --ad --attach-with-detach -S -s --sock -l --list -k --kill -f --prefix -d --detach -m --mouse -h --help)

  if [ -n "$ZSH_VERSION" ]; then
    # -------------- Zsh Completion --------------
    _t_sessions_zsh() {
      local -a sessions
      sessions=("${(@f)$(tmux ls 2>/dev/null | awk -F: '{print $1}')}")
      _describe -t sessions 'tmux sessions' sessions
    }
    _t_prefixkeys_zsh() {
      local -a keys
      keys=(a b c d e q r s t w x z)
      _describe -t keys 'prefix key' keys
    }
    _arguments -s -S -C \
      '-A[attach/create session (no detach others)]:session name:_t_sessions_zsh' \
      '-a[attach/create session (no detach others)]:session name:_t_sessions_zsh' \
      '--attach[attach/create session (no detach others)]:session name:_t_sessions_zsh' \
      '--ad[attach and detach others (default)]:session name:_t_sessions_zsh' \
      '--attach-with-detach[attach and detach others (default)]:session name:_t_sessions_zsh' \
      '-S[use tmux socket]:socket:_files' \
      '-s[use tmux socket]:socket:_files' \
      '--sock[use tmux socket]:socket:_files' \
      '-l[list sessions/windows]:(session window)' \
      '--list[list sessions/windows]:(session window)' \
      '-k[kill session]:session name:_t_sessions_zsh' \
      '--kill[kill session]:session name:_t_sessions_zsh' \
      '-f[rebind tmux prefix-key]:key:_t_prefixkeys_zsh' \
      '--prefix[rebind tmux prefix-key]:key:_t_prefixkeys_zsh' \
      '-d[detach current session]' \
      '--detach[detach current session]' \
      '-m[toggle mouse mode]' \
      '--mouse[toggle mouse mode]' \
      '-h[show help]' \
      '--help[show help]'
    return
  fi

  # -------------- Bash Completion --------------
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    -a|--attach|-A|--ad|--attach-with-detach)
      COMPREPLY=( $(compgen -W "$(_t_sessions)" -- "$cur") )
      return 0 ;;
    -k|--kill)
      COMPREPLY=( $(compgen -W "$(_t_sessions)" -- "$cur") )
      return 0 ;;
    -l|--list)
      COMPREPLY=( $(compgen -W "session window" -- "$cur") )
      return 0 ;;
    -f|--prefix)
      COMPREPLY=( $(compgen -W "$(_t_prefixkeys)" -- "$cur") )
      return 0 ;;
    -S|-s|--sock)
      COMPREPLY=( $(compgen -o default -- "$cur") )
      return 0 ;;
    -m|--mouse|-d|--detach)
      COMPREPLY=()
      return 0 ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "${opts[@]}" -- "$cur") )
    return 0
  fi

  # Default: Complete session names
  COMPREPLY=( $(compgen -W "$(_t_sessions)" -- "$cur") )
}

if [ -n "$ZSH_VERSION" ]; then
  compdef _t_complete t
elif [ -n "$BASH_VERSION" ]; then
  complete -F _t_complete t
fi

# (Hint) Just source this file in your .zshrc or .bashrc to enable completion for `t`

