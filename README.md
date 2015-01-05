t
====
t -- easy tmux wrapper
----------------------


    t -- easy tmux wrapper.
    USAGE:
        * t session_name                                        # Find or create tmux-session, and attach this.
        * t [-S|-s|--sock] socket_path                          # Find or create socket, And attach this session.
        * t [-l|--list] [session|window]                        # Show alive tmux sessions.
        * t [-k|--kill] session_name                            # Kill session. (default is current)
        * t [-f|--prefix] [key]                                 # Rebind tmux prefix-key.
        * t [-d|--detach]                                       # Detach current session.
        * t [-m|--mouse]                                        # Mouse mode on/off toggle.


Author

Copyright (c) 2015 Hiroshi IKEGAMI

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
