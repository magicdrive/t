t
====

NAME
----
t - Lazy tmux wrapper

USAGE
----
```
 * t session_name [TMUX_OPTIONS]                # Find or create tmux-session, and detach any other client then attach this.
 *     [-A|-a|--attach] session_name            # Find or create tmux-session, and attach this.
 *     [--ad|--attach-with-detach] session_name # Find or create tmux-session, and attach this.
 *     [-S|-s|--sock] socket_path               # Find or create socket, And attach this session.
 *     [-l|--list] [session|window]             # Show alive tmux sessions.
 *     [-k|--kill] session_name                 # Kill session. (default is current)
 *     [-f|--prefix] [key]                      # Rebind tmux prefix-key.
 *     [-d|--detach]                            # Detach current session.
 *     [-m|--mouse]                             # Mouse mode on/off toggle.
```

ENVIRONMENTS
---
```
 T_DEFAULT_SESSIONNAME             # Default use session_name (default: "main")
 T_DEFAULT_SOCKPATH                # Default use socket_path (default: "~/tmp//tmux-socket")
 T_DEFAULT_TMUX_OPTION             # Default tmux cmd optoin (default: "")
 T_DEFAULT_TMUX_ATTACH_WITH_DETACH # Each other tty detach then attach session, when using `t` without specification. (default "on")
```


Author

Copyright (c) 2015 - 2021 Hiroshi IKEGAMI

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
