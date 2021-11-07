#! /bin/bash

#
# t - Easy tmux wrapper
#
# USAGE
# ----
#     * t session_name [TMUX_OPTIONS]                # Find or create tmux-session, and detach any other client then attach this.
#     *     [-A|-a|--attach] session_name            # Find or create tmux-session, and attach this.
#     *     [--ad|--attach-with-detach] session_name # Find or create tmux-session, and attach this.
#     *     [-S|-s|--sock] socket_path               # Find or create socket, And attach this session.
#     *     [-l|--list] [session|window]             # Show alive tmux sessions.
#     *     [-k|--kill] session_name                 # Kill session. (default is current)
#     *     [-f|--prefix] [key]                      # Rebind tmux prefix-key.
#     *     [-d|--detach]                            # Detach current session.
#     *     [-m|--mouse]                             # Mouse mode on/off toggle.
#
# Author
#
# Copyright (c) 2015 - 2021 Hiroshi IKEGAMI
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
export T_DEFAULT_SESSIONNAME="${T_DEFAULT_SESSIONNAME:-"$(whoami)"}"
export T_DEFAULT_SOCKPATH="${T_DEFAULT_SOCKPATH:-"~/tmp//tmux-socket"}"
export T_DEFAULT_TMUX_OPTION="${T_DEFAULT_TMUX_OPTION:-""}"
export T_DEFAULT_TMUX_ATTACH_WITH_DETACH="${T_DEFAULT_TMUX_OPTION:-"on"}"


t::usage_exit() {
    cat << HELP >&2
USAGE:
    * t session_name [TMUX_OPTIONS]                # Find or create tmux-session, and detach any other client then attach this.
    *     [-A|-a|--attach] session_name            # Find or create tmux-session, and attach this.
    *     [--ad|--attach-with-detach] session_name # Find or create tmux-session, and attach this.
    *     [-S|-s|--sock] socket_path               # Find or create socket, And attach this session.
    *     [-l|--list] [session|window]             # Show alive tmux sessions.
    *     [-k|--kill] session_name                 # Kill session. (default is current)
    *     [-f|--prefix] [key]                      # Rebind tmux prefix-key.
    *     [-d|--detach]                            # Detach current session.
    *     [-m|--mouse]                             # Mouse mode on/off toggle.
HELP
    exit 1
}

t::tmux_rebind_prefix() {
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

t::tmux_attach() {
    if [ ! -z ${TMUX} ];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local session_name="${1:-"${T_DEFAULT_SESSIONNAME}"}";
    if [ "$#" != 0 ];then
        shift
    fi
    session_exists=$(tmux ls 2>&1 | cut -d ':' -f 1 | grep -e "^${session_name}$" | wc -l | perl -pe "s/\s//g")
    if [ "${session_exists}" = 0 ]; then
        tmux new-session -s "${session_name}" $@ ${T_DEFAULT_TMUX_OPTION}
    else
        if [ ${T_TMUX_ATTACH_WITH_DETACH} = "on" ];then
            tmux attach -d -t "${session_name}" $@ ${T_DEFAULT_TMUX_OPTION}
        else
            tmux attach -t "${session_name}" $@ ${T_DEFAULT_TMUX_OPTION}
        fi
    fi
}

t::tmux_sock() {
    if [[ ! -z ${TMUX} ]];then
        echo 'sessions should be nested with care, unset $TMUX to force';
        return 1;
    fi
    local socket_path="${T_DEFAULT_SOCKPATH}";
    [ $# -ne '0' ] && socket_path="$1";
    if [ -e "${socket_path}" ]; then
        mkdir -p "$(dirname "${socket_path}")"
        tmux -S "${socket_path}" ${T_DEFAULT_TMUX_OPTION}
    else
        tmux -S "${socket_path}" attach ${T_DEFAULT_TMUX_OPTION}
    fi
}

t::tmux_mouse() {

    [ "${T_TMUX_MOUSEMODE}" = '' ] && \
        export T_TMUX_MOUSEMODE="$(tmux show -g | \
        grep mouse-resize-pane | \
        perl -p -e 's/mouse-resize-pane //')";

    if [ "${TMUX_MOUSEMODE}" == 'on' ];then
        local switch="off"
    else
        local switch="on"
    fi

    tmux set-option -g mouse-select-pane ${switch}
    tmux set-option -g mode-mouse ${switch}
    tmux set-option -g mouse-resize-pane ${switch}
    tmux set-option -g mouse-select-pane ${switch}
    export T_TMUX_MOUSEMODE=${switch}

}


optspec=":A:a:f:S:s:k:-:hldm"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                attach)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    env T_TMUX_ATTACH_WITH_DETACH=0 t::tmux_attach "${val}"; exit 0
                    ;;
                ad|attach-with-detach)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    env T_TMUX_ATTACH_WITH_DETACH=1 t::tmux_attach "${val}"; exit 0
                    ;;
                detach)
                    \tmux detach-client; exit 1
                    ;;
                kill)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    \tmux kill-session -t "${val}"; exit 1
                    ;;
                mouse)
                    t::tmux_mouse; exit 0
                    ;;
                prefix)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    t::tmux_rebind_prefix "${val}"; exit 0
                    ;;
                sock)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    t::tmux_sock "${val}"; exit 0
                    ;;
                list)
                    \tmux ls; exit 0
                    ;;
                help)
                    t::usage_exit; exit 1
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        h)
            t::usage_exit; exit 1
            ;;
        l)
            \tmux ls; exit 0
            ;;
        A|a)
            t::tmux_attach "${OPTARG}"; exit 0
            ;;
        d)
            \tmux detach-client; exit 1
            ;;
        k)
            \tmux kill-session -t "${OPTARG}"; exit 1
            ;;
        S|s)
            t::tmux_sock "${OPTARG}"; exit 0
            ;;
        m)
            t::tmux_mouse; exit 0
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            exit 1
            ;;
    esac
done

export T_TMUX_ATTACH_WITH_DETACH="${T_DEFAULT_TMUX_ATTACH_WITH_DETACH}" && \
    t::tmux_attach $@ && exit 0;

