(local config-store (require :config))
(local git (require :git))
(local reviews (require :reviews))
(local sync (require :sync))
(local sys (require :sys))
(local tui (require :tui))

(fn command-for-editor [editor path]
  (if (= (type editor) "table")
      (let [parts []]
        (each [_ part (ipairs editor)]
          (table.insert parts (sys.shell-quote part)))
        (table.insert parts (sys.shell-quote path))
        (table.concat parts " "))
      (.. editor " " (sys.shell-quote path))))

(fn editor-program [editor]
  (let [program (if (= (type editor) "table")
                    (. editor 1)
                    (string.match (tostring editor) "^%s*(%S+)"))]
    (or (and program (program:match "([^/]+)$")) "")))

(fn gui-editor? [editor]
  (let [program (editor-program editor)]
    (or (= program "idea") (= program "code") (= program "cursor")
        (= program "subl") (= program "mate") (= program "open"))))

(fn detached-editor? [config editor]
  (if (not (= config.detached nil))
      config.detached
      (gui-editor? editor)))

(fn run-detached [cmd]
  (os.execute (.. cmd " >/dev/null 2>&1 &")))

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

(fn preview-key [revision entry]
  (.. revision "\0" entry.status "\0" (or entry.old_path "") "\0" entry.path))

(fn preview-line-color [line]
  (let [first (line:sub 1 1)]
    (if (or (line:match "^diff ") (line:match "^index ")
            (line:match "^%-%-%- ") (line:match "^%+%+%+ "))
        :dim
        (= first "+")
        :added
        (= first "-")
        :deleted
        (= first "@")
        :renamed
        nil)))

(fn color-preview-line [line]
  (let [line (or line "")
        color (preview-line-color line)]
    (if color
        (tui.color color line)
        line)))

(fn preview-lines-from-output [output filtered?]
  (let [lines (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
                (if filtered?
                    line
                    (color-preview-line line)))]
    (if (> (length lines) 0)
        lines
        [(tui.color :dim "No preview for this file.")])))

(fn selected-entry [state]
  (. state.entries state.selected))

(fn clamp [n low high]
  (math.max low (math.min high n)))

(fn preview-lines [state]
  (let [entry (selected-entry state)]
    (if (not entry)
        [(tui.color :dim "No file selected.")]
        (let [key (preview-key state.revision entry)
              cached (. state.preview_cache key)]
          (if cached
              cached
              (let [(output ok filtered?) (git.preview-output state.preview_context
                                                              state.revision
                                                              entry)
                    lines (if ok
                              (preview-lines-from-output output filtered?)
                              [(tui.color :deleted (sys.trim output))])]
                (tset state.preview_cache key lines)
                lines))))))

(fn preview-row-count [state]
  (or state.preview_rows 1))

(fn preview-page-step [state]
  (math.max 1 (math.floor (/ (preview-row-count state) 2))))

(fn max-preview-scroll [state]
  (math.max 0 (- (length (preview-lines state)) (preview-row-count state))))

(fn set-preview-scroll [state scroll]
  (set state.preview_scroll (clamp scroll 0 (max-preview-scroll state))))

(fn reset-preview-scroll [state]
  (set state.preview_scroll 0))

(fn scroll-preview [state delta]
  (set-preview-scroll state (+ (or state.preview_scroll 0) delta)))

(fn scroll-preview-page-down [state]
  (scroll-preview state (preview-page-step state)))

(fn scroll-preview-page-up [state]
  (scroll-preview state (- (preview-page-step state))))

(fn visible-preview-lines [state rows]
  (let [usable (math.max 1 (- rows 3))
        lines (preview-lines state)]
    (set state.preview_rows usable)
    (set-preview-scroll state (or state.preview_scroll 0))
    (let [first (+ state.preview_scroll 1)
          last (math.min (length lines) (+ state.preview_scroll usable))]
      (if (> first last)
          []
          (fcollect [i first last]
            (. lines i))))))

(fn reviewed-count [entries]
  (accumulate [count 0 _ entry (ipairs entries)]
    (if entry.reviewed (+ count 1) count)))

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
        " | C-d/C-u preview | r refresh | y copy | space check | a check+next | A all/none | enter/o open | q quit")))

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
     :preview (visible-preview-lines state rows)
     :warning (sync.warning state.sync)
     :notice state.notice}))

(fn event-key [key]
  (case key
    :up :up
    :down :down
    :enter :open
    :quit :quit
    :tick :tick
    "k" :up
    "j" :down
    "o" :open
    " " :toggle-reviewed
    "a" :toggle-reviewed-and-advance
    "A" :toggle-all-reviewed
    "\4" :preview-down
    "\21" :preview-up
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
  (let [editor (config-store.editor-command config)
        cmd (command-for-editor editor entry.path)]
    (if (detached-editor? config editor)
        (run-detached cmd)
        (tui.suspend stty-state #(os.execute cmd)))))

(fn copy-text [text]
  (let [f (io.popen "pbcopy" "w")]
    (if f
        (do
          (f:write text)
          (let [(ok _kind _code) (f:close)]
            ok))
        false)))

(fn move-selection [state delta]
  (let [entries state.entries
        before state.selected]
    (if (= (length entries) 0)
        (set state.selected 1)
        (set state.selected (clamp (+ state.selected delta) 1 (length entries))))
    (when (not (= before state.selected))
      (reset-preview-scroll state))))

(fn set-notice [state action path]
  (set state.notice (.. action ": " path)))

(fn persist-reviewed [state]
  (when (not (reviews.persist state.review_store state.review_scope
                              state.entries))
    (set state.notice "Could not save reviewed marks")))

(fn reviewed-action [entry]
  (if entry.reviewed "Marked reviewed" "Unmarked reviewed"))

(fn toggle-reviewed [state]
  (let [entry (selected-entry state)]
    (when entry
      (set entry.reviewed (not entry.reviewed))
      (set-notice state (reviewed-action entry) entry.path)
      (persist-reviewed state))))

(fn toggle-reviewed-and-advance [state]
  (toggle-reviewed state)
  (move-selection state 1))

(fn toggle-all-reviewed [state]
  (let [entries state.entries
        reviewed (reviewed-count entries)
        review? (< reviewed (length entries))]
    (each [_ entry (ipairs entries)]
      (set entry.reviewed review?))
    (set state.notice (if review?
                          "Marked all reviewed"
                          "Unmarked all reviewed"))
    (persist-reviewed state)))

(fn jump-top [state]
  (when (not (= state.selected 1))
    (set state.selected 1)
    (reset-preview-scroll state)))

(fn jump-bottom [state]
  (let [last (length state.entries)]
    (when (not (= state.selected last))
      (set state.selected last)
      (reset-preview-scroll state))))

(fn refresh-state [state]
  (let [reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries state.revision)]
    (when (not err)
      (set state.entries (reviews.apply entries reviewed))
      (set state.preview_cache {})
      (reset-preview-scroll state)
      (move-selection state 0)
      (persist-reviewed state)
      (sync.start state.sync))))

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

(fn continue-after [f]
  (f)
  true)

(fn handle-action [state config key]
  (case key
    :up (continue-after #(move-selection state -1))
    :down (continue-after #(move-selection state 1))
    :open (continue-after #(open-selected state config))
    :toggle-reviewed (continue-after #(toggle-reviewed state))
    :toggle-reviewed-and-advance
    (continue-after #(toggle-reviewed-and-advance state))
    :toggle-all-reviewed (continue-after #(toggle-all-reviewed state))
    :preview-down (continue-after #(scroll-preview-page-down state))
    :preview-up (continue-after #(scroll-preview-page-up state))
    :top (continue-after #(jump-top state))
    :bottom (continue-after #(jump-bottom state))
    :refresh (continue-after #(refresh-state state))
    :copy-path (continue-after #(copy-selected-path state))
    :tick (continue-after #nil)
    :quit false
    _ true))

(fn handle-key [state config raw-key]
  (sync.update state.sync)
  (let [(pending-key key) (next-key state.pending-key raw-key)]
    (set state.pending-key pending-key)
    (if key
        (handle-action state config key)
        true)))

(fn picker [revision entries config review-store review-scope]
  (let [state {:revision revision
               :entries entries
               :selected 1
               :preview_scroll 0
               :preview_rows 1
               :preview_cache {}
               :preview_context (git.preview-context)
               :review_store review-store
               :review_scope review-scope
               :sync (sync.new-state)
               :pending-key nil}]
    (sync.start state.sync)
    (tui.run-loop state view #(handle-key $1 config $2))))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options]
  (let [config (merge-options (config-store.load) options)
        (entries err) (git.diff-entries revision)]
    (if err (exit-with-error err) (= (length entries) 0)
        (print "No changed files.")
        (let [review-store (reviews.load-store)
              scope (reviews.scope (git.repo-root) revision)
              entries (reviews.apply entries (reviews.marks review-store scope))]
          (picker revision entries config review-store scope)))))

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
