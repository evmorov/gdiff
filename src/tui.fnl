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
               :notice "\27[90m"
               :search "\27[1;4m"
               :search-end "\27[22;24m"})

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn color [name text]
  (if (color?)
      (.. (. colors name) text colors.reset)
      text))

(fn reset-code []
  (if (color?) colors.reset ""))

(fn search-code []
  colors.search)

(fn search-end-code []
  colors.search-end)

(fn ansi-sequence-end [s i]
  (var j (+ i 2))
  (var done? false)
  (while (and (not done?) (<= j (length s)))
    (let [byte (string.byte s j)]
      (if (and byte (>= byte 64) (<= byte 126))
          (set done? true)
          (set j (+ j 1)))))
  (if done? j i))

(fn ansi-sequence? [s i]
  (and (= (s:sub i i) ESC) (= (s:sub (+ i 1) (+ i 1)) "[")))

(fn visible-length [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var len 0)
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (do
            (set len (+ len 1))
            (set i (+ i 1)))))
    len))

(fn strip-ansi [s]
  (let [s (tostring (or s ""))]
    (var i 1)
    (var out "")
    (while (<= i (length s))
      (if (ansi-sequence? s i)
          (set i (+ (ansi-sequence-end s i) 1))
          (do
            (set out (.. out (s:sub i i)))
            (set i (+ i 1)))))
    out))

(fn match-ranges [plain query]
  (let [ranges []]
    (when (> (length query) 0)
      (var start 1)
      (var searching? true)
      (while searching?
        (let [(first last) (plain:find query start true)]
          (if first
              (do
                (table.insert ranges {:first first :last last})
                (set start (+ last 1)))
              (set searching? false)))))
    ranges))

(fn highlight-matches [s query]
  (let [s (tostring (or s ""))
        ranges (match-ranges (strip-ansi s) (or query ""))]
    (if (= (length ranges) 0)
        s
        (let [start-code (search-code)
              end-code (search-end-code)]
          (var out "")
          (var i 1)
          (var visible 1)
          (var range-index 1)
          (while (<= i (length s))
            (let [range (. ranges range-index)]
              (when (and range (= visible range.first))
                (set out (.. out start-code)))
              (if (ansi-sequence? s i)
                  (let [last (ansi-sequence-end s i)]
                    (set out (.. out (s:sub i last)))
                    (set i (+ last 1)))
                  (do
                    (set out (.. out (s:sub i i)))
                    (when (and range (= visible range.last))
                      (set out (.. out end-code))
                      (set range-index (+ range-index 1)))
                    (set visible (+ visible 1))
                    (set i (+ i 1))))))
          out))))

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
    (if (<= (visible-length s) width)
        s
        (let [suffix (if (> width 3) "..." "")
              limit (- width (length suffix))]
          (var i 1)
          (var visible 0)
          (var out "")
          (while (and (< visible limit) (<= i (length s)))
            (if (ansi-sequence? s i)
                (let [last (ansi-sequence-end s i)]
                  (set out (.. out (s:sub i last)))
                  (set i (+ last 1)))
                (do
                  (set out (.. out (s:sub i i)))
                  (set visible (+ visible 1))
                  (set i (+ i 1)))))
          (.. out suffix (reset-code))))))

(fn cursor [row col]
  (io.write ESC "[" row ";" col "H"))

(fn write-row [line selected? ?newline]
  (if selected?
      (io.write (color :reverse line) ESC "[0m")
      (io.write line))
  (when ?newline
    (io.write NL)))

(fn draw-header [view cols]
  (io.write ESC "[2J" ESC "[H")
  (io.write (truncate view.header cols) NL)
  (io.write (color :dim (string.rep "-" cols)) NL))

(fn draw-rows [rows cols]
  (each [_ row (ipairs rows)]
    (write-row (truncate row.text cols) row.selected? true)))

(fn split-widths [cols]
  (let [left-cols (math.max 1 (math.floor (* (- cols 1) 0.4)))
        right-cols (math.max 1 (- cols left-cols 1))
        divider-col (+ left-cols 1)]
    (values left-cols right-cols divider-col)))

(fn draw-split-row [screen-row
                    left-row
                    right-line
                    left-cols
                    right-cols
                    divider-col]
  (cursor screen-row 1)
  (when left-row
    (write-row (truncate left-row.text left-cols) left-row.selected?))
  (cursor screen-row divider-col)
  (io.write (color :dim "|"))
  (cursor screen-row (+ divider-col 1))
  (when right-line
    (io.write (truncate right-line right-cols))))

(fn draw-split-rows [rows preview screen-rows cols]
  (let [(left-cols right-cols divider-col) (split-widths cols)]
    (for [i 1 screen-rows]
      (draw-split-row (+ i 2) (. rows i) (. preview i) left-cols right-cols
                      divider-col))))

(fn draw-content [view rows cols]
  (let [screen-rows (math.max 1 (- rows 3))]
    (if view.preview
        (draw-split-rows view.rows view.preview screen-rows cols)
        (draw-rows view.rows cols))))

(fn draw-notice [notice rows cols]
  (when notice
    (io.write ESC "[" rows ";1H")
    (io.write (color :notice (truncate notice cols)))))

(fn draw-warning [warning rows cols]
  (when warning
    (io.write ESC "[" rows ";1H")
    (io.write colors.deleted (truncate warning cols) colors.reset)))

(fn draw-footer [view rows cols]
  (if view.prompt (draw-notice view.prompt rows cols)
      view.warning (draw-warning view.warning rows cols)
      (draw-notice view.notice rows cols)))

(fn draw [view-fn state]
  (let [(rows cols) (terminal-size)]
    (local view (view-fn state rows cols))
    (draw-header view cols)
    (draw-content view rows cols)
    (draw-footer view rows cols)
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
    (if (not c) :tick
        (= c ESC) (escape-key)
        (= c "\r") :enter
        (= c "\n") :enter
        (= c "\3") :quit
        c)))

(fn saved-stty []
  (trim (read-command "stty -g 2>/dev/null")))

(fn raw-terminal [stty-state]
  (os.execute "stty raw -echo min 0 time 10 2>/dev/null")
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

{: color
 : draw
 : highlight-matches
 : read-key
 : run-loop
 : strip-ansi
 : suspend
 : terminal-size
 : truncate}
