(local fennel (require :fennel))

(local ESC "\27")
(local NL "\r\n")

(local colors {:reset "\27[0m"
               :dim "\27[2m"
               :reverse "\27[7m"
               :added "\27[32m"
               :modified "\27[33m"
               :deleted "\27[31m"
               :renamed "\27[36m"
               :copied "\27[35m"})

(fn color? []
  (not (os.getenv "NO_COLOR")))

(fn color [name text]
  (if (color?)
      (.. (. colors name) text colors.reset)
      text))

(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn shell-quote [s]
  (let [escaped (string.gsub (tostring s) "'" "'\\''")]
    (.. "'" escaped "'")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              (ok kind code) (f:close)]
          (values output ok kind code))
        (values "" false "open" 1))))

(fn read-file [path]
  (let [f (io.open path "r")]
    (when f
      (let [contents (f:read "*a")]
        (f:close)
        contents))))

(fn config-path []
  (let [xdg (os.getenv "XDG_CONFIG_HOME")
        home (os.getenv "HOME")]
    (if (and xdg (> (length xdg) 0))
        (.. xdg "/gdiff/config.fnl")
        (.. (or home ".") "/.config/gdiff/config.fnl"))))

(fn load-config []
  (let [path (config-path)
        source (read-file path)]
    (if source
        (let [(ok result) (pcall fennel.eval source
                                 {:filename path :allowedGlobals []})]
          (if ok
              (or result {})
              (error (.. "Could not load " path ": " result))))
        {})))

(fn editor-command [config]
  (or config.editor (os.getenv "GDIFF_EDITOR") (os.getenv "VISUAL")
      (os.getenv "EDITOR") "vim"))

(fn command-for-editor [editor path]
  (if (= (type editor) "table")
      (let [parts []]
        (each [_ part (ipairs editor)]
          (table.insert parts (shell-quote part)))
        (table.insert parts (shell-quote path))
        (table.concat parts " "))
      (.. editor " " (shell-quote path))))

(fn usage []
  (io.stderr:write "Usage: gdiff [--editor <command>] <branch-or-revision-range>\n")
  (io.stderr:write "Example: gdiff --editor nvim main...HEAD\n"))

(fn next-arg [argv i option]
  (let [value (. argv (+ i 1))]
    (if value
        (values value (+ i 2) nil)
        (values nil i (.. option " needs a value")))))

(fn parse-editor-option [arg]
  (arg:match "^%-%-editor=(.+)$"))

(fn parse-revision [revision arg]
  (if revision
      (values revision (.. "Unexpected extra argument: " arg))
      (values arg nil)))

(fn parse-args [argv]
  (let [options {}]
    (var revision nil)
    (var err nil)
    (var i 1)
    (while (and (not err) (<= i (length argv)))
      (let [arg (. argv i)
            editor (parse-editor-option arg)]
        (if editor
            (do
              (set options.editor editor)
              (set i (+ i 1)))
            (or (= arg "--editor") (= arg "-e"))
            (let [(value next-i next-err) (next-arg argv i arg)]
              (set options.editor value)
              (set i next-i)
              (set err next-err))
            (= arg "--")
            (let [(value next-i next-err) (next-arg argv i "--")]
              (set revision value)
              (set i next-i)
              (set err next-err))
            (and (= (arg:sub 1 1) "-") (not (= arg "-")))
            (set err (.. "Unknown option: " arg))
            (let [(next-revision next-err) (parse-revision revision arg)]
              (set revision next-revision)
              (set err next-err)
              (set i (+ i 1))))))
    (values options revision err)))

(fn split-tabs [line]
  (icollect [part (string.gmatch line "([^\t]+)")]
    part))

(fn entry [status path ?old-path]
  {:status status
   :kind (status:sub 1 1)
   :path path
   :old_path ?old-path
   :reviewed false})

(fn entry-from-name-status-line [line]
  (let [parts (split-tabs line)
        status (. parts 1)
        kind (and status (status:sub 1 1))]
    (case kind
      "A" (entry status (. parts 2))
      "M" (entry status (. parts 2))
      "D" (entry status (. parts 2))
      "R" (entry status (. parts 3) (. parts 2))
      "C" (entry status (. parts 3) (. parts 2))
      _ nil)))

(fn parse-name-status [text]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (entry-from-name-status-line line)))

(fn diff-command [revision]
  (.. "git diff --name-status --find-renames --find-copies "
      (shell-quote revision) " 2>&1"))

(fn diff-entries [revision]
  (let [(output ok _kind _code) (read-command (diff-command revision))]
    (if ok
        (values (parse-name-status output) nil)
        (values nil (trim output)))))

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

(fn status-color [entry]
  (case entry.kind
    "A" :added
    "M" :modified
    "D" :deleted
    "R" :renamed
    "C" :copied
    _ :reset))

(fn status-text [entry]
  (color (status-color entry) (.. "[" entry.status "]")))

(fn reviewed-text [entry]
  (if entry.reviewed
      (color :added "[x]")
      (color :dim "[ ]")))

(fn display-path [entry]
  (if (or (= entry.kind "R") (= entry.kind "C"))
      (.. entry.path " <- " entry.old_path)
      entry.path))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn plural-s [n]
  (if (= n 1) "" "s"))

(fn viewport [selected count rows]
  (let [usable (math.max 1 (- rows 3))
        top (clamp (- selected (math.floor (/ usable 2))) 1
                   (math.max 1 (- count usable -1)))
        bottom (math.min count (+ top usable -1))]
    (values top bottom)))

(fn header-line [state count]
  (let [reviewed (reviewed-count state.entries)]
    (.. "gdiff " state.revision " | " count " file" (plural-s count) " | "
        reviewed "/" count " reviewed"
        " | space check | a check+next | enter/o open | q quit")))

(fn row-prefix [selected?]
  (if selected? "> " "  "))

(fn row-text [entry selected? cols]
  (truncate (.. (row-prefix selected?) (reviewed-text entry) " "
                (status-text entry) " " (display-path entry)) cols))

(fn write-row [line selected?]
  (if selected?
      (io.write (color :reverse line) ESC "[0m" NL)
      (io.write line NL)))

(fn draw-header [state count cols]
  (io.write ESC "[2J" ESC "[H")
  (io.write (header-line state count) NL)
  (io.write (color :dim (string.rep "-" cols)) NL))

(fn draw-rows [entries selected top bottom cols]
  (for [i top bottom]
    (let [entry (. entries i)
          selected? (= i selected)
          line (row-text entry selected? cols)]
      (write-row line selected?))))

(fn draw [state]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (rows cols) (terminal-size)
        (top bottom) (viewport selected count rows)]
    (draw-header state count cols)
    (draw-rows entries selected top bottom cols)
    (io.flush)))

(fn escape-key []
  (let [a (io.read 1)
        b (io.read 1)]
    (case (.. (or a "") (or b ""))
      "[A" :up
      "[B" :down
      _ :escape)))

(fn char-key [c]
  (case c
    "k" :up
    "j" :down
    "o" :open
    " " :toggle-reviewed
    "a" :toggle-reviewed-and-advance
    "G" :bottom
    "\r" :open
    "\n" :open
    "q" :quit
    "\3" :quit
    _ c))

(fn read-key []
  (let [c (io.read 1)]
    (if (not c) :quit
        (= c ESC) (escape-key)
        (char-key c))))

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

(fn run-editor [config entry stty-state]
  (restore-terminal stty-state)
  (let [editor (editor-command config)
        cmd (command-for-editor editor entry.path)]
    (os.execute cmd))
  (raw-terminal stty-state))

(fn move-selection [state delta]
  (let [entries state.entries]
    (set state.selected (clamp (+ state.selected delta) 1 (length entries)))))

(fn toggle-reviewed [state]
  (let [entry (. state.entries state.selected)]
    (set entry.reviewed (not entry.reviewed))))

(fn toggle-reviewed-and-advance [state]
  (toggle-reviewed state)
  (move-selection state 1))

(fn jump-top [state]
  (set state.selected 1))

(fn jump-bottom [state]
  (set state.selected (length state.entries)))

(fn handle-key [state config stty-state key]
  (case key
    :up (do
          (move-selection state -1)
          true)
    :down (do
            (move-selection state 1)
            true)
    :open (do
            (run-editor config (. state.entries state.selected) stty-state)
            true)
    :toggle-reviewed (do
                       (toggle-reviewed state)
                       true)
    :toggle-reviewed-and-advance (do
                                   (toggle-reviewed-and-advance state)
                                   true)
    :top (do
           (jump-top state)
           true)
    :bottom (do
              (jump-bottom state)
              true)
    :quit false
    _ true))

(fn next-key [?pending-key key]
  (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
      (= key "g") (values "g" nil)
      (values nil key)))

(fn picker-loop [state config stty-state]
  (var running true)
  (var pending-key nil)
  (while running
    (draw state)
    (let [(next-pending key) (next-key pending-key (read-key))]
      (set pending-key next-pending)
      (when key
        (set running (handle-key state config stty-state key))))))

(fn picker [revision entries config]
  (let [state {:revision revision :entries entries :selected 1}
        stty-state (saved-stty)]
    (raw-terminal stty-state)
    (let [(ok err) (pcall picker-loop state config stty-state)]
      (restore-terminal stty-state)
      (when (not ok)
        (error err)))))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options]
  (let [config (merge-options (load-config) options)
        (entries err) (diff-entries revision)]
    (if err (exit-with-error err)
        (= (length entries) 0) (print "No changed files.")
        (picker revision entries config))))

(fn main [argv]
  (let [(options revision err) (parse-args argv)]
    (if err (do
              (io.stderr:write err "\n")
              (usage)
              (os.exit 1))
        (not revision) (do
                         (usage)
                         (os.exit 1))
        (run revision options))))

(main arg)
