(local ansi (require :tui.ansi))
(local keys (require :tui.keys))
(local osc (require :tui.terminal-osc))
(local probe (require :tui.terminal-probe))

(local saved-stty probe.saved-stty)
(local terminal-size probe.terminal-size)

(fn input-mode [time]
  (os.execute (.. "stty raw -echo min 0 time " time " 2>/dev/null")))

(fn blocking-mode []
  (input-mode 10))

(fn nonblocking-mode []
  (input-mode 0))

(fn escape-mode []
  (input-mode 1))

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
        (let [_ (escape-mode)
              sequence (read-escape-sequence)
              _ (blocking-mode)
              key (keys.decode state c sequence)]
          (if (= key :paste-start)
              (paste-key state)
              key))
        (keys.decode state c))))

(fn poll-key [state]
  ;; Uses a short escape timeout while assembling a sequence so a split arrow
  ;; key or bracketed paste can't be misread or leak paste as commands, while a
  ;; lone Escape still resolves promptly instead of stalling.
  (let [c (io.read 1)]
    (when c
      (if (= c ansi.esc)
          (do
            (escape-mode)
            (let [key (keys.decode state c (read-escape-sequence))]
              (if (= key :paste-start)
                  (paste-key state)
                  key)))
          (keys.decode state c)))))

(fn drain [state coalesce? apply]
  ;; Returns running? and any non-coalescible key read for the caller to handle
  ;; next. Restores blocking mode.
  (nonblocking-mode)
  (var running true)
  (var held nil)
  (var done? false)
  (while (not done?)
    (let [key (poll-key state)]
      (if (not key) (set done? true) (coalesce? key)
          (do
            (set running (apply key))
            (when (not running)
              (set done? true)))
          (do
            (set held key)
            (set done? true)))))
  (blocking-mode)
  (values running held))

(fn raw-terminal [stty-state]
  (os.execute "stty raw -echo min 0 time 1 2>/dev/null")
  (let [background-rgb (osc.query-background-rgb)]
    (blocking-mode)
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
 : drain
 : end-frame
 : raw-terminal
 : read-key
 : restore-terminal
 : saved-stty
 : suspend
 : terminal-size}
