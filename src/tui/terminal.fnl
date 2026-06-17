(local ansi (require :tui.ansi))
(local colors (require :tui.colors))

(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              (ok kind code) (f:close)]
          (values output ok kind code))
        (values "" false "open" 1))))

(fn terminal-size []
  (let [output (read-command "stty size 2>/dev/null")
        (rows cols) (output:match "^(%d+)%s+(%d+)")]
    (values (or (tonumber rows) 24) (or (tonumber cols) 80))))

(fn cursor [row col]
  (io.write ansi.esc "[" row ";" col "H"))

(fn clear-line []
  (io.write ansi.esc "[2K"))

(fn clear-screen []
  (io.write ansi.esc "[2J" ansi.esc "[H"))

(fn begin-frame []
  (io.write ansi.esc "[?2026h"))

(fn end-frame []
  (io.write ansi.esc "[?2026l"))

(fn escape-key []
  (let [a (io.read 1)
        b (io.read 1)]
    (case (.. (or a "") (or b ""))
      "[A" :up
      "[B" :down
      _ :escape)))

(fn search-input? [state]
  (and state state.search state.search.active?))

(fn read-key [state]
  (let [c (io.read 1)]
    (if (not c) :tick
        (= c ansi.esc) (if (search-input? state) :escape (escape-key))
        (= c "\r") :enter
        (= c "\n") :enter
        (= c "\3") :quit
        c)))

(fn saved-stty []
  (trim (read-command "stty -g 2>/dev/null")))

(fn read-osc-response [?limit]
  (let [limit (or ?limit 128)]
    (var out "")
    (var done? false)
    (for [_ 1 limit]
      (when (not done?)
        (let [c (io.read 1)]
          (if c
              (do
                (set out (.. out c))
                (when (or (= c "\7")
                          (and (<= 2 (length out))
                               (= (out:sub (- (length out) 1))
                                  (.. ansi.esc "\\"))))
                  (set done? true)))
              (set done? true)))))
    out))

(fn query-background-rgb []
  (io.write ansi.esc "]11;?\7")
  (io.flush)
  (colors.parse-background-response (read-osc-response)))

(fn query-foreground-rgb []
  (io.write ansi.esc "]10;?\7")
  (io.flush)
  (colors.parse-background-response (read-osc-response)))

(fn raw-terminal [stty-state]
  (os.execute "stty raw -echo min 0 time 1 2>/dev/null")
  (let [foreground-rgb (query-foreground-rgb)
        background-rgb (query-background-rgb)]
    (os.execute "stty raw -echo min 0 time 10 2>/dev/null")
    (io.write ansi.esc "[?1049h" ansi.esc "[?25l")
    (clear-screen)
    (io.flush)
    (values stty-state background-rgb foreground-rgb)))

(fn restore-terminal [stty-state]
  (io.write ansi.esc "[?25h" ansi.esc "[?1049l" ansi.esc "[0m")
  (io.flush)
  (when (and stty-state (< 0 (length stty-state)))
    (os.execute (.. "stty " stty-state " 2>/dev/null"))))

(fn suspend [stty-state f]
  (restore-terminal stty-state)
  (f)
  (raw-terminal stty-state))

{: begin-frame
 : clear-line
 : clear-screen
 : cursor
 : end-frame
 : raw-terminal
 : read-key
 : restore-terminal
 : saved-stty
 : suspend
 : terminal-size}
