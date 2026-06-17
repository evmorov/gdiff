(local ansi (require :tui.ansi))
(local keys (require :tui.keys))
(local osc (require :tui.terminal_osc))
(local probe (require :tui.terminal_probe))

(local saved-stty probe.saved-stty)
(local terminal-size probe.terminal-size)

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

(fn csi-final? [ch]
  (let [byte (and ch (string.byte ch))]
    (and byte (<= 64 byte 126))))

(fn read-escape-sequence []
  (let [first (io.read 1)]
    (if (= first "[")
        (let [limit 16]
          (var out "[")
          (var done? false)
          (for [_ 1 limit]
            (when (not done?)
              (let [ch (io.read 1)]
                (if ch
                    (do
                      (set out (.. out ch))
                      (when (csi-final? ch)
                        (set done? true)))
                    (set done? true)))))
          out)
        (or first ""))))

(fn paste-end? [buffer]
  (= buffer (.. ansi.esc "[201~")))

(fn tail [s width]
  (if (> (length s) width)
      (s:sub (- (length s) width -1))
      s))

(fn drain-paste []
  (var buffer "")
  (var done? false)
  (while (not done?)
    (let [ch (io.read 1)]
      (if ch
          (do
            (set buffer (tail (.. buffer ch) 6))
            (when (paste-end? buffer)
              (set done? true)))
          (set done? true)))))

(fn read-key [state]
  (let [c (io.read 1)]
    (if (= c ansi.esc)
        (let [key (keys.decode state c (read-escape-sequence))]
          (if (= key :paste-start)
              (do
                (drain-paste)
                :tick)
              key))
        (keys.decode state c))))

(fn raw-terminal [stty-state]
  (os.execute "stty raw -echo min 0 time 1 2>/dev/null")
  (let [background-rgb (osc.query-background-rgb)]
    (os.execute "stty raw -echo min 0 time 10 2>/dev/null")
    (io.write ansi.esc "[?1049h" ansi.esc "[?25l" ansi.esc "[?2004h")
    (clear-screen)
    (io.flush)
    (values stty-state background-rgb)))

(fn restore-terminal [stty-state]
  (io.write ansi.esc "[?2004l" ansi.esc "[?25h" ansi.esc "[?1049l" ansi.esc
            "[0m")
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
