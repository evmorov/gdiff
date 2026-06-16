(local clipboard (require :clipboard))
(local config-store (require :config))
(local editor (require :editor))
(local entry-view (require :entry))
(local git (require :git))
(local preview (require :preview))
(local preview-warm (require :preview_warm))
(local reviews (require :reviews))
(local search (require :search))
(local sync (require :sync))
(local tui (require :tui))

(fn usage []
  (io.stderr:write "Usage: gdiff [--editor <command>] [branch-or-revision-range]\n")
  (io.stderr:write "Without a revision, gdiff tries main first, then master.\n")
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
    (fn parse-from [i revision]
      (if (> i (length argv))
          (values options revision nil)
          (let [arg (. argv i)
                editor (parse-editor-option arg)]
            (if editor
                (do
                  (set options.editor editor)
                  (parse-from (+ i 1) revision))
                (or (= arg "--editor") (= arg "-e"))
                (let [(value next-i err) (next-arg argv i arg)]
                  (set options.editor value)
                  (if err
                      (values options revision err)
                      (parse-from next-i revision)))
                (= arg "--")
                (let [(value next-i err) (next-arg argv i "--")]
                  (if err
                      (values options revision err)
                      (parse-from next-i value)))
                (and (= (arg:sub 1 1) "-") (not (= arg "-")))
                (values options revision (.. "Unknown option: " arg))
                (let [(next-revision err) (parse-revision revision arg)]
                  (if err
                      (values options next-revision err)
                      (parse-from (+ i 1) next-revision)))))))

    (parse-from 1 nil)))

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

(fn selected-entry [state]
  (. state.entries state.selected))

(fn set-selection [state selected]
  (let [before state.selected]
    (set state.selected selected)
    (when (not (= before state.selected))
      (preview.reset-scroll state))))

(fn clamp [n low high]
  (math.max low (math.min high n)))

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
    (.. "gdiff " state.revision_label " | " count " file" (plural-s count)
        " | " reviewed "/" count " reviewed"
        " | / search | C-d/C-u preview | r refresh | y copy | space check | a all/none | enter/o open | Ctrl-C quit")))

(fn row-prefix [selected?]
  (if selected? "> " "  "))

(fn row-text [state entry selected?]
  (.. (row-prefix selected?) (reviewed-text entry) " " (status-text entry) " "
      (search.highlight state (entry-view.path-text entry))))

(fn visible-rows [state rows]
  (let [entries state.entries
        selected state.selected
        count (length entries)
        (first-row last-row) (viewport selected count rows)]
    (fcollect [i first-row last-row]
      (let [entry (. entries i)
            selected? (= i selected)]
        {:text (row-text state entry selected?) :selected? selected?}))))

(fn warm-preview-cache [state]
  (preview-warm.start state.preview_warm state.src_dir state.revision
                      state.entries))

(fn view [state rows _cols]
  (preview-warm.update state.preview_warm state.preview_cache)
  (let [count (length state.entries)]
    {:header (header-line state count)
     :rows (visible-rows state rows)
     :preview (preview.visible-lines state (selected-entry state) rows)
     :prompt (search.status state)
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
    "a" :toggle-all-reviewed
    "\4" :preview-down
    "\21" :preview-up
    "/" :search
    "n" :search-next
    "N" :search-previous
    "r" :refresh
    "y" :copy-path
    "G" :bottom
    "q" :clear-search
    _ key))

(fn next-key [?pending-key key]
  (let [key (event-key key)]
    (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
        (= key "g") (values "g" nil)
        (values nil key))))

(fn move-selection [state delta]
  (let [entries state.entries
        selected (if (= (length entries) 0)
                     1
                     (clamp (+ state.selected delta) 1 (length entries)))]
    (set-selection state selected)))

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
  (set-selection state 1))

(fn jump-bottom [state]
  (let [last (length state.entries)]
    (set-selection state last)))

(fn refresh-state [state]
  (let [reviewed (reviews.paths state.entries)
        (entries err) (git.diff-entries state.revision)]
    (when (not err)
      (set state.entries (reviews.apply entries reviewed))
      (set state.preview_cache {})
      (warm-preview-cache state)
      (preview.reset-scroll state)
      (move-selection state 0)
      (persist-reviewed state)
      (sync.start state.sync))))

(fn open-selected [state config]
  (let [entry (selected-entry state)]
    (when entry
      (set-notice state "Opened" entry.path)
      (editor.run config entry state.stty-state))))

(fn copy-selected-path [state]
  (let [entry (selected-entry state)]
    (when entry
      (if (clipboard.copy entry.path)
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
    :toggle-all-reviewed (continue-after #(toggle-all-reviewed state))
    :preview-down
    (continue-after #(preview.scroll-page-down state (selected-entry state)))
    :preview-up
    (continue-after #(preview.scroll-page-up state (selected-entry state)))
    :search (continue-after #(search.start state))
    :search-next (continue-after #(search.next state))
    :search-previous (continue-after #(search.previous state))
    :clear-search (continue-after #(search.clear state))
    :top (continue-after #(jump-top state))
    :bottom (continue-after #(jump-bottom state))
    :refresh (continue-after #(refresh-state state))
    :copy-path (continue-after #(copy-selected-path state))
    :tick (continue-after #nil)
    :quit false
    _ true))

(fn handle-key [state config raw-key]
  (sync.update state.sync)
  (if (= raw-key :quit)
      false
      (search.active? state)
      (search.handle-input state raw-key)
      (let [(pending-key key) (next-key state.pending-key raw-key)]
        (set state.pending-key pending-key)
        (if key
            (handle-action state config key)
            true))))

(fn new-state [revision entries review-store review-scope src-dir]
  {:revision revision
   :src_dir src-dir
   :revision_label (git.comparison-label revision)
   :entries entries
   :selected 1
   :preview_scroll 0
   :preview_rows 1
   :preview_cache {}
   :preview_context (git.preview-context)
   :preview_warm (preview-warm.new-state)
   :review_store review-store
   :review_scope review-scope
   :search (search.new-state)
   :sync (sync.new-state)
   :pending-key nil})

(fn picker [revision entries config review-store review-scope src-dir]
  (let [state (new-state revision entries review-store review-scope src-dir)]
    (warm-preview-cache state)
    (sync.start state.sync)
    (tui.run-loop state view #(handle-key $1 config $2))))

(fn exit-with-error [message]
  (io.stderr:write message "\n")
  (os.exit 1))

(fn merge-options [config options]
  (when options.editor
    (set config.editor options.editor))
  config)

(fn run [revision options src-dir]
  (let [config (merge-options (config-store.load) options)
        (entries err) (git.diff-entries revision)]
    (if err (exit-with-error err) (= (length entries) 0)
        (print "No changed files.")
        (let [review-store (reviews.load-store)
              scope (reviews.scope (git.repo-root) revision)
              entries (reviews.apply entries (reviews.marks review-store scope))]
          (picker revision entries config review-store scope src-dir)))))

(fn main [argv src-dir]
  (let [(options revision err) (parse-args argv)]
    (if err (do
              (io.stderr:write err "\n")
              (usage)
              (os.exit 1)) revision (run revision options src-dir)
        (let [(revision err) (git.default-revision)]
          (if err
              (do
                (io.stderr:write err "\n")
                (usage)
                (os.exit 1))
              (run revision options src-dir))))))

{: main}
