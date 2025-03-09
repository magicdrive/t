# Bash and Zsh completion for `t` command

_t_complete() {
    local cur prev opts raw_sessions sessions display_sessions

    opts="-a --attach -S -s --sock -l --list -k --kill -f --prefix -d --detach -m --mouse"

    # `t --list session`
    raw_sessions=$(t --list session 2>/dev/null)

    sessions=()
    display_sessions=()
    while IFS= read -r line; do
        display_sessions+=("$line")
        session_name=$(echo "$line" | awk -F':' '{print $1}')
        sessions+=("$session_name")
    done <<< "$raw_sessions"

    if [ -n "$ZSH_VERSION" ]; then
        # Zsh completion
        case "${words[CURRENT-1]}" in
            -a|--attach|-k|--kill)
                compadd -d "${(F)display_sessions}" -- $sessions
                ;;
            -l|--list)
                compadd -X "List options" -- "session" "window"
                ;;
            -f|--prefix)
                compadd -X "Prefix key"
                ;;
            *)
                if [[ ${words[CURRENT]} == -* ]]; then
                    compadd -X "Available options" -- ${(s: :)opts}
                else
                    compadd -d "${(F)display_sessions}" -- $sessions
                fi
                ;;
        esac
    else
        # Bash completion
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        case "${prev}" in
            -a|--attach|-k|--kill)
                COMPREPLY=( $(compgen -W "${sessions[*]}" -- "${cur}") )
                ;;
            -S|-s|--sock)
                COMPREPLY=( $(compgen -o default -- "${cur}") )
                ;;
            -l|--list)
                COMPREPLY=( $(compgen -W "session window" -- "${cur}") )
                ;;
            -f|--prefix)
                COMPREPLY=()
                ;;
            *)
                if [[ ${cur} == -* ]]; then
                    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
                else
                    COMPREPLY=( $(compgen -W "${sessions[*]}" -- "${cur}") )
                fi
                ;;
        esac
    fi
}

if [ -n "$ZSH_VERSION" ]; then
    compdef _t_complete t
elif [ -n "$BASH_VERSION" ]; then
    complete -F _t_complete t
fi

