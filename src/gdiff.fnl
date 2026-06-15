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
        (let [(lua-source compile-opts) (fennel.compileString source
                                                              {:filename path})]
          (if lua-source
              (let [(chunk load-error) (load lua-source (.. "@" path))]
                (if chunk
                    (let [(ok result) (pcall chunk)]
                      (if ok
                          (or result {})
                          (error (.. "Could not load " path ": " result))))
                    (error (.. "Could not load " path ": " load-error))))
              (error (.. "Could not compile " path ": " compile-opts))))
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
  (io.stderr:write "Usage: gdiff <branch-or-revision-range>\n")
  (io.stderr:write "Example: gdiff main...HEAD\n"))

(fn split-tabs [line]
  (let [parts []]
    (each [part (string.gmatch line "([^\t]+)")]
      (table.insert parts part))
    parts))

(fn entry [status path old-path]
  {:status status
   :kind (status:sub 1 1)
   :path path
   :old_path old-path
   :reviewed false})

(fn parse-name-status [text]
  (let [entries []]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (let [parts (split-tabs line)
            status (. parts 1)
            kind (and status (status:sub 1 1))]
        (case kind
          "A" (table.insert entries (entry status (. parts 2) nil))
          "M" (table.insert entries (entry status (. parts 2) nil))
          "D" (table.insert entries (entry status (. parts 2) nil))
          "R" (table.insert entries (entry status (. parts 3) (. parts 2)))
          "C" (table.insert entries (entry status (. parts 3) (. parts 2)))
          _ nil)))
    entries))

(fn diff-entries [revision]
  (let [cmd (.. "git diff --name-status --find-renames --find-copies "
                (shell-quote revision) " 2>&1")
        (output ok kind code) (read-command cmd)]
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
  (var count 0)
  (each [_ entry (ipairs entries)]
    (when entry.reviewed
      (set count (+ count 1))))
  count)

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn draw [state]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        reviewed (reviewed-count entries)
        (rows cols) (terminal-size)
        usable (math.max 1 (- rows 3))
        top (clamp (- selected (math.floor (/ usable 2))) 1
                   (math.max 1 (- count usable -1)))
        bottom (math.min count (+ top usable -1))]
    (io.write ESC "[2J" ESC "[H")
    (io.write (.. "gdiff " state.revision " | " count " file"
                  (if (= count 1) "" "s") " | " reviewed "/" count " reviewed"
                  " | space check | enter/o open | q quit" NL))
    (io.write (color :dim (string.rep "-" cols)) NL)
    (for [i top bottom]
      (let [entry (. entries i)
            prefix (if (= i selected) "> " "  ")
            line (truncate (.. prefix (reviewed-text entry) " "
                               (status-text entry) " " (display-path entry))
                           cols)]
        (if (= i selected)
            (io.write (color :reverse line) ESC "[0m" NL)
            (io.write line NL))))
    (io.flush)))

(fn read-key []
  (let [c (io.read 1)]
    (if (not c)
        :quit
        (= c ESC)
        (let [a (io.read 1)
              b (io.read 1)]
          (case (.. (or a "") (or b ""))
            "[A" :up
            "[B" :down
            _ :escape))
        (case c
          "k" :up
          "j" :down
          "o" :open
          " " :toggle-reviewed
          "\r" :open
          "\n" :open
          "q" :quit
          "\3" :quit
          _ c))))

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

(fn picker [revision entries config]
  (let [state {:revision revision :entries entries :selected 1}
        stty-state (saved-stty)]
    (raw-terminal stty-state)
    (let [(ok err) (pcall (fn []
                            (var running true)
                            (while running
                              (draw state)
                              (case (read-key)
                                :up (set state.selected
                                         (clamp (- state.selected 1) 1
                                                (length entries)))
                                :down (set state.selected
                                           (clamp (+ state.selected 1) 1
                                                  (length entries)))
                                :open (run-editor config
                                                  (. entries state.selected)
                                                  stty-state)
                                :toggle-reviewed (let [entry (. entries
                                                                state.selected)]
                                                   (set entry.reviewed
                                                        (not entry.reviewed))
                                                   (set state.selected
                                                        (clamp (+ state.selected
                                                                  1)
                                                               1
                                                               (length entries))))
                                :quit (set running false)
                                _ nil))))]
      (restore-terminal stty-state)
      (when (not ok)
        (error err)))))

(fn main [argv]
  (let [revision (. argv 1)]
    (if (not revision)
        (do
          (usage)
          (os.exit 1))
        (let [config (load-config)
              (entries err) (diff-entries revision)]
          (if err
              (do
                (io.stderr:write err "\n")
                (os.exit 1))
              (if (= (length entries) 0)
                  (print "No changed files.")
                  (picker revision entries config)))))))

(main arg)
