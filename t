#! /bin/bash

#
# t
# ====
#
# NAME
# ----
# t -- easy tmux wrapper
#
# USAGE
# ----
#     * t session_name [TMUX_OPTIONS]  # Find or create tmux-session, and detach any other client then attach this.
#     * t [-a|--attach] session_name   # Find or create tmux-session, and attach this.
#     * t [-S|-s|--sock] socket_path   # Find or create socket, And attach this session.
#     * t [-l|--list] [session|window] # Show alive tmux sessions.
#     * t [-k|--kill] session_name     # Kill session. (default is current)
#     * t [-f|--prefix] [key]          # Rebind tmux prefix-key.
#     * t [-d|--detach]                # Detach current session.
#     * t [-m|--mouse]                 # Mouse mode on/off toggle.
#
# Author
#
# Copyright (c) 2015 - 2020 Hiroshi IKEGAMI
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#
#

set -e
export LANG=C
export TMUX_DEFAULT_SESSIONNAME="main"
export TMUX_DEFAULT_SOCKPATH="~/tmp//tmux-socket"
export TMUX_DEFAULT_SUPPORT_COLOURS=256


__usage_exit() {
    cat << HELP
USAGE:
    * t session_name                 # Find or create tmux-session, and detach any other client then attach this.
    * t [-a|--attach] session_name   # Find or create tmux-session, and attach this.
    * t [-S|-s|--sock] socket_path   # Find or create socket, And attach this session.
    * t [-l|--list] [session|window] # Show alive tmux sessions.
    * t [-k|--kill] session_name     # Kill session. (default is current)
    * t [-f|--prefix] [key]          # Rebind tmux prefix-key.
    * t [-d|--detach]                # Detach current session.
    * t [-m|--mouse]                 # Mouse mode on/off toggle.
HELP
    exit 1
}

__tmux_rebind_prefix() {
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

__tmux_attach_simple() {
    if [ ! -z ${TMUX} ];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local session_name="${1:-"${TMUX_DEFAULT_SESSIONNAME}"}";
    if [ "$#" != 0 ];then
        shift
    fi
    session_exists=$(tmux ls 2>&1 | cut -d ':' -f 1 | grep -e "^${session_name}$" | wc -l | perl -pe "s/\s//g")
    if [ "${session_exists}" = 0 ]; then
        tmux new-session -s "${session_name}"
    else
        tmux attach -t "${session_name}"
    fi
}

__tmux_attach() {
    if [ ! -z ${TMUX} ];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local session_name="${1:-"${TMUX_DEFAULT_SESSIONNAME}"}";
    if [ "$#" != 0 ];then
        shift
    fi
    session_exists=$(tmux ls 2>&1 | cut -d ':' -f 1 | grep -e "^${session_name}$" | wc -l | perl -pe "s/\s//g")
    if [ "${session_exists}" = 0 ]; then
        tmux new-session -s "${session_name}" $@
    else
        tmux attach -d -t "${session_name}" $@
    fi
}

__tmux_sock() {
    if [ ! -z ${TMUX} ];then
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

    [ "${TMUX_MOUSEMODE}" = '' ] && export TMUX_MOUSEMODE="$(tmux show -g | grep mouse-resize-pane | perl -p -e 's/mouse-resize-pane //')";

    if [ "${TMUX_MOUSEMODE}" == 'on' ];then
        local switch=off
    else
        local switch=on
    fi

    tmux set-option -g mouse-select-pane ${switch}
    tmux set-option -g mode-mouse ${switch}
    tmux set-option -g mouse-resize-pane ${switch}
    tmux set-option -g mouse-select-pane ${switch}
    export TMUX_MOUSEMODE=${switch}

}


optspec=":a:f:s:k:-:hldm"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                attach)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    __tmux_attach_simple "${val}"; exit 0
                    ;;
                detach)
                    \tmux detach-client; exit 1
                    ;;
                kill)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    \tmux kill-session -t "${val}"; exit 1
                    ;;
                mouse)
                    __tmux_mouse; exit 0
                    ;;
                prefix)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    __tmux_rebind_prefix "${val}"; exit 0
                    ;;
                sock)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    __tmux_sock "${val}"; exit 0
                    ;;
                list)
                    \tmux ls; exit 0
                    ;;
                help)
                    __usage_exit; exit 1
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        h)
            __usage_exit; exit 1
            ;;
        l)
            \tmux ls; exit 0
            ;;
        a)
            __tmux_attach_simple "${OPTARG}"; exit 0
            ;;
        d)
            \tmux detach-client; exit 1
            ;;
        k)
            \tmux kill-session -t "${OPTARG}"; exit 1
            ;;
        s)
            __tmux_sock "${OPTARG}"; exit 0
            ;;
        m)
            __tmux_mouse; exit 0
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            exit 1
            ;;
    esac
done

__tmux_attach $@
