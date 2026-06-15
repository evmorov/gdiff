(local ESC "\27")
(local NL "\r\n")

(local colors {:reset "\27[0m"
               :dim "\27[2m"
               :reverse "\27[7m"
               :added "\27[32m"
               :modified "\27[33m"
               :deleted "\27[31m"
               :renamed "\27[36m"
               :copied "\27[35m"
               :notice "\27[90m"})

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn color [name text]
  (if (color?)
      (.. (. colors name) text colors.reset)
      text))

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

(fn truncate [s width]
  (let [s (tostring (or s ""))]
    (if (<= (length s) width)
        s
        (if (> width 1)
            (.. (s:sub 1 (- width 1)) "...")
            ""))))

(fn write-row [line selected?]
  (if selected?
      (io.write (color :reverse line) ESC "[0m" NL)
      (io.write line NL)))

(fn draw-header [view cols]
  (io.write ESC "[2J" ESC "[H")
  (io.write view.header NL)
  (io.write (color :dim (string.rep "-" cols)) NL))

(fn draw-rows [rows cols]
  (each [_ row (ipairs rows)]
    (write-row (truncate row.text cols) row.selected?)))

(fn draw-notice [notice rows cols]
  (when notice
    (io.write ESC "[" rows ";1H")
    (io.write (color :notice (truncate notice cols)))))

(fn draw [view-fn state]
  (let [(rows cols) (terminal-size)]
    (local view (view-fn state rows cols))
    (draw-header view cols)
    (draw-rows view.rows cols)
    (draw-notice view.notice rows cols)
    (io.flush)))

(fn escape-key []
  (let [a (io.read 1)
        b (io.read 1)]
    (case (.. (or a "") (or b ""))
      "[A" :up
      "[B" :down
      _ :escape)))

(fn read-key []
  (let [c (io.read 1)]
    (if (not c) :quit
        (= c ESC) (escape-key)
        (= c "\r") :enter
        (= c "\n") :enter
        (= c "\3") :quit
        c)))

(fn saved-stty []
  (trim (read-command "stty -g 2>/dev/null")))

(fn raw-terminal [stty-state]
  (os.execute "stty raw -echo 2>/dev/null")
  (io.write ESC "[?1049h" ESC "[?25l")
  (io.flush)
  stty-state)

(fn restore-terminal [stty-state]
  (io.write ESC "[?25h" ESC "[?1049l" ESC "[0m")
  (io.flush)
  (when (and stty-state (> (length stty-state) 0))
    (os.execute (.. "stty " stty-state " 2>/dev/null"))))

(fn suspend [stty-state f]
  (restore-terminal stty-state)
  (f)
  (raw-terminal stty-state))

(fn run-loop [state view handle-key]
  (let [stty-state (saved-stty)]
    (raw-terminal stty-state)
    (let [(ok err) (pcall (fn []
                            (set state.stty-state stty-state)
                            (var running true)
                            (while running
                              (draw view state)
                              (set running (handle-key state (read-key))))))]
      (restore-terminal stty-state)
      (when (not ok)
        (error err)))))

{: color : draw : read-key : run-loop : suspend : terminal-size : truncate}
