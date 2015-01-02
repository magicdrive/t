#! /bin/bash

set -e
export LANG=C
export TMUX_DEFAULT_SESSIONNAME="main"
export TMUX_DEFAULT_SOCKPATH="~/tmp//tmux-socket"
export TMUX_DEFAULT_SUPPORT_COLOURS=256

usage_exit() {
    cat << HELP
t -- easy tmux wrapper.
USAGE:
    * t session_name                                        # Find or create tmux-session, and attach this.
    * t [-r|--rename] old_name new_name                     # Rename tmux-session.
    * t [-S|-s|--sock] socket_path                          # Find or create socket, And attach this session.
    * t [-l|--list] [session|window]                        # Show alive tmux sessions.
    * t [-k|--kill] session_name                            # Kill session. (default is current)
    * t [-f|--prefix] [key]                                 # Rebind tmux prefix-key.
    * t [-b|--bind-key] [bind_name] [key]                   # Rebind to [key] tmux-bind name.
    * t [-x|--close] [window|pane] [win_name or pane_index] # Close this tmux window or pane. (default is current)
    * t [-w|--close-window] window_name                     # Close this tmux window. (default is current)
    * t [-p|--close-pane] pane_index                        # Close this tmux pane (default is current)
    * t [-d|--detach]                                       # Detach current session.
    * t [--mouse] [on|off]                                  # Mouse mode on/off.
    * t [--raw] command                                     # Execute tmux command
HELP
    exit 1
}

__rebind() {
    local _new_key_="C-${1}"
    local _old_key_="C-$(tmux list-key | grep send-prefix | perl -p -e "s/.*C-([\\w]).*/\$1/")"

    if [ "$_new_key_" != 'C-' -a ${_} != 'C-' ];then
        eval "tmux set-option -g prefix ${_new_key_} && tmux bind-key ${_new_key_} send-prefix"
        eval "tmux unbind-key ${_old_key_}"
    else
        cat << 'HELP'
rebind tmux prefix key
Usage:
t rebind [key]
HELP
        return;
    fi
}

__tmux_attach() {
    if [ -z ${TMUX} ];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local session_name="${TMUX_DEFAULT_SESSIONNAME}";
    [ $# -ne '0' ] && session_name="$1";
    session_exists=$(tmux ls 2>&1 | cut -d ':' -f 1 | grep -e "^${session_name}$" | wc -l | perl -pe "s/\s//g")
    if [ "${session_exists}" = 0 ]; then
        tmux new-session -s "${session_name}"
    else
        tmux attach -t "${session_name}"
    fi
}

__tmux_sock() {
    if [ -z ${TMUX} ];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local socket_path="${TMUX_DEFAULT_SOCKPATH}";
    [ $# -ne '0' ] && socket_path="$1";
    if [ -e "${socket_path}" ]; then
        mkdir -p "$(dirname "${socket_path}")"
        tmux -S "${socket_path}"
    else
        tmux -S "${socket_path}" attach
    fi
}

__tmux_mouse() {

    [ "${TMUX_MOUSEMODE}" = '' ] && export TMUX_MOUSE="$(tmux show -g | grep mouse-resize-pane | perl -p -e 's/mouse-resize-pane //')";

    if [ "${TMUX_MOUSEMODE}" == 'on' ];then
        local switch=off
    else
        local switch=on
    fi

    tmux set-option -g mouse-select-pane ${switch}
    tmux set-option -g mode-mouse ${switch}
    tmux set-option -g mouse-resize-pane ${switch}
    tmux set-option -g mouse-select-pane ${switch}
    export TMUX_MOUSE=${switch}

}


