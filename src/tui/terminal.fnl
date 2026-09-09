(local ansi (require :tui.ansi))
(local keys (require :tui.keys))
(local osc (require :tui.terminal-osc))
(local probe (require :tui.terminal-probe))

(local saved-stty probe.saved-stty)
(local terminal-size probe.terminal-size)

(local read-timeout-tenths 1)

(fn input-mode []
  (os.execute (.. "stty raw -echo min 0 time " read-timeout-tenths
                  " 2>/dev/null")))

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

(fn printable-byte? [ch]
  (let [byte (string.byte ch)]
    (and byte (>= byte 32) (not (= byte 127)))))

(fn drain-paste []
  (var window "")
  (var line "")
  (var collecting? true)
  (var done? false)
  (while (not done?)
    (let [ch (io.read 1)]
      (if ch
          (do
            (set window (tail (.. window ch) 6))
            (when collecting?
              (if (or (= ch "\n") (= ch "\r") (= ch ansi.esc))
                  (set collecting? false)
                  (printable-byte? ch)
                  (set line (.. line ch))))
            (when (paste-end? window)
              (set done? true)))
          (set done? true))))
  line)

(fn paste-key [state]
  (let [line (drain-paste)]
    (if (and (keys.search-active? state) (< 0 (length line)))
        {:paste line}
        :tick)))

(fn read-key [state]
  (let [c (io.read 1)]
    (if (= c ansi.esc)
        (let [key (keys.decode state c (read-escape-sequence))]
          (if (= key :paste-start)
              (paste-key state)
              key))
        (keys.decode state c))))

(fn raw-terminal [stty-state]
  (input-mode)
  (let [background-rgb (osc.query-background-rgb)]
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
