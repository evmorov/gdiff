(local fennel (require :fennel))
(local tui (require :tui))

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

(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

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

(fn status-color [entry]
  (case entry.kind
    "A" :added
    "M" :modified
    "D" :deleted
    "R" :renamed
    "C" :copied
    _ :reset))

(fn status-text [entry]
  (tui.color (status-color entry) (.. "[" entry.status "]")))

(fn reviewed-text [entry]
  (if entry.reviewed
      (tui.color :added "[x]")
      (tui.color :dim "[ ]")))

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
        " | r refresh | y copy | space check | a check+next | enter/o open | q quit")))

(fn row-prefix [selected?]
  (if selected? "> " "  "))

(fn row-text [entry selected?]
  (.. (row-prefix selected?) (reviewed-text entry) " " (status-text entry) " "
      (display-path entry)))

(fn visible-rows [state rows]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (first-row last-row) (viewport selected count rows)]
    (fcollect [i first-row last-row]
      (let [entry (. entries i)
            selected? (= i selected)]
        {:text (row-text entry selected?) :selected? selected?}))))

(fn view [state rows _cols]
  (let [count (length state.entries)]
    {:header (header-line state count)
     :rows (visible-rows state rows)
     :notice state.notice}))

(fn event-key [key]
  (case key
    :up :up
    :down :down
    :enter :open
    :quit :quit
    "k" :up
    "j" :down
    "o" :open
    " " :toggle-reviewed
    "a" :toggle-reviewed-and-advance
    "r" :refresh
    "y" :copy-path
    "G" :bottom
    "q" :quit
    _ key))

(fn next-key [?pending-key key]
  (let [key (event-key key)]
    (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
        (= key "g") (values "g" nil)
        (values nil key))))

(fn run-editor [config entry stty-state]
  (tui.suspend stty-state (fn []
                            (let [editor (editor-command config)
                                  cmd (command-for-editor editor entry.path)]
                              (os.execute cmd)))))

(fn copy-text [text]
  (let [f (io.popen "pbcopy" "w")]
    (if f
        (do
          (f:write text)
          (let [(ok _kind _code) (f:close)]
            ok))
        false)))

(fn move-selection [state delta]
  (let [entries state.entries]
    (if (= (length entries) 0)
        (set state.selected 1)
        (set state.selected (clamp (+ state.selected delta) 1 (length entries))))))

(fn selected-entry [state]
  (. state.entries state.selected))

(fn set-notice [state action path]
  (set state.notice (.. action ": " path)))

(fn reviewed-action [entry]
  (if entry.reviewed "Marked reviewed" "Unmarked reviewed"))

(fn toggle-reviewed [state]
  (let [entry (selected-entry state)]
    (when entry
      (set entry.reviewed (not entry.reviewed))
      (set-notice state (reviewed-action entry) entry.path))))

(fn toggle-reviewed-and-advance [state]
  (toggle-reviewed state)
  (move-selection state 1))

(fn jump-top [state]
  (set state.selected 1))

(fn jump-bottom [state]
  (set state.selected (length state.entries)))

(fn reviewed-paths [entries]
  (collect [_ entry (ipairs entries)]
    (if entry.reviewed
        (values entry.path true))))

(fn apply-reviewed [entries reviewed]
  (each [_ entry (ipairs entries)]
    (when (. reviewed entry.path)
      (set entry.reviewed true)))
  entries)

(fn refresh-state [state]
  (let [reviewed (reviewed-paths state.entries)
        (entries err) (diff-entries state.revision)]
    (when (not err)
      (set state.entries (apply-reviewed entries reviewed))
      (move-selection state 0))))

(fn open-selected [state config]
  (let [entry (selected-entry state)]
    (when entry
      (set-notice state "Opened" entry.path)
      (run-editor config entry state.stty-state))))

(fn copy-selected-path [state]
  (let [entry (selected-entry state)]
    (when entry
      (if (copy-text entry.path)
          (set-notice state "Copied" entry.path)
          (set-notice state "Copy failed" entry.path)))))

(fn keep-going [f]
  (f)
  true)

(fn handle-key [state config raw-key]
  (let [(pending-key key) (next-key state.pending-key raw-key)]
    (set state.pending-key pending-key)
    (if key
        (case key
          :up (keep-going #(move-selection state -1))
          :down (keep-going #(move-selection state 1))
          :open (keep-going #(open-selected state config))
          :toggle-reviewed (keep-going #(toggle-reviewed state))
          :toggle-reviewed-and-advance (keep-going #(toggle-reviewed-and-advance state))
          :top (keep-going #(jump-top state))
          :bottom (keep-going #(jump-bottom state))
          :refresh (keep-going #(refresh-state state))
          :copy-path (keep-going #(copy-selected-path state))
          :quit false
          _ true)
        true)))

(fn picker [revision entries config]
  (let [state {:revision revision
               :entries entries
               :selected 1
               :pending-key nil}]
    (tui.run-loop state view #(handle-key $1 config $2))))

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

{: main}
