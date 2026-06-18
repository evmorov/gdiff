(local sys (require :platform.core))
(local tui (require :tui.core))

(fn command-path [path]
  (if (= (path:sub 1 1) "-")
      (.. "./" path)
      path))

(fn command [path]
  (.. "ls -la " (sys.shell-quote (command-path path)) " 2>&1"))

(fn rest-under [folder path]
  (let [prefix (.. folder "/")]
    (when (= (path:sub 1 (length prefix)) prefix)
      (let [rest (path:sub (+ (length prefix) 1))]
        (when (< 0 (length rest))
          rest)))))

(fn direct-child [folder path]
  (let [rest (rest-under folder path)]
    (when rest
      (or (rest:match "^([^/]+)/") rest))))

(fn direct-file-child [folder path]
  (let [rest (rest-under folder path)]
    (when (and rest (not (rest:find "/" 1 true)))
      rest)))

(fn child-info [folder path]
  (let [rest (rest-under folder path)]
    (when rest
      {:name (or (rest:match "^([^/]+)/") rest)
       :folder? (not (= nil (rest:find "/" 1 true)))
       :rest rest})))

(fn child-status-kind [entry rest]
  (if (and (rest:find "/" 1 true) (= entry.kind "D"))
      "M"
      entry.kind))

(local status-rank {"C" 1 "M" 2 "A" 3 "R" 4 "D" 5})

(fn stronger-kind [left right]
  (if (< (or (. status-rank left) 0) (or (. status-rank right) 0))
      right
      left))

(fn direct-statuses [folder entries]
  (let [statuses {}]
    (each [_ entry (ipairs (or entries []))]
      (let [info (child-info folder entry.path)]
        (when info
          (tset statuses info.name
                (stronger-kind (. statuses info.name)
                               (child-status-kind entry info.rest))))))
    statuses))

(fn deleted-children [folder entries]
  (let [statuses {}]
    (each [_ entry (ipairs (or entries []))]
      (let [info (child-info folder entry.path)]
        (when info
          (let [status (or (. statuses info.name)
                           {:folder? info.folder? :all-deleted? true})]
            (set status.folder? (or status.folder? info.folder?))
            (when (not (= entry.kind "D"))
              (set status.all-deleted? false))
            (tset statuses info.name status)))))
    statuses))

(fn child-orders [folder entries]
  (let [orders {}
        counts {1 0 2 0}]
    (each [_ entry (ipairs (or entries []))]
      (let [info (child-info folder entry.path)]
        (when (and info (not (. orders info.name)))
          (let [section (if info.folder? 2 1)]
            (tset counts section (+ (. counts section) 1))
            (tset orders info.name {:section section :order (. counts section)})))))
    orders))

(fn status-color [kind]
  (case kind
    "A" :status-added
    "M" :status-modified
    "D" :status-deleted
    "R" :status-renamed
    "C" :status-copied
    _ nil))

(fn marker [state kind]
  (if kind
      (.. (tui.color state.theme (status-color kind) (.. "[" kind "]")) " ")
      "    "))

(fn folder-status-kind [entries]
  (let [first-kind (and (. entries 1) (. (. entries 1) :kind))]
    (if (not first-kind) nil
        (accumulate [same? true _ entry (ipairs entries)]
          (and same? (= first-kind entry.kind))) first-kind
        "M")))

(fn split-lines [output]
  (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
    line))

(fn listing-entry [line]
  (let [mode (line:sub 1 1)
        name (or (line:match "^%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(.+)$")
                 "")]
    (when (and (< 0 (length name)) (not (= name ".")) (not (= name "..")))
      (let [name (or (name:match "^(.-) %-> ") name)]
        {:name name :folder? (= mode "d")}))))

(fn display-name [entry]
  (if entry.folder?
      (.. entry.name "/")
      entry.name))

(fn collect-listing-entries [output]
  (let [seen {}
        entries []]
    (each [_ line (ipairs (split-lines output))]
      (when (not (line:match "^total "))
        (let [entry (listing-entry line)]
          (when entry
            (tset seen entry.name true)
            (table.insert entries entry)))))
    (values entries seen)))

(fn add-deleted-entries [entries seen folder source-entries]
  (each [name status (pairs (deleted-children folder source-entries))]
    (when (and status.all-deleted? (not (. seen name)))
      (tset seen name true)
      (table.insert entries {:name name :folder? status.folder? :deleted? true})))
  entries)

(fn synthetic-entries [folder source-entries]
  (let [entries []
        seen {}
        deleted (deleted-children folder source-entries)]
    (each [_ entry (ipairs (or source-entries []))]
      (let [info (child-info folder entry.path)]
        (when (and info (not (. seen info.name)))
          (tset seen info.name true)
          (let [status (. deleted info.name)
                deleted? (and status status.all-deleted?)]
            (table.insert entries
                          {:name info.name
                           :folder? info.folder?
                           :deleted? deleted?})))))
    entries))

(fn entry-sort-values [orders entry]
  (let [order (. orders entry.name)
        section (if order order.section
                    entry.folder? 2
                    1)
        position (if order order.order 999999)]
    (values section position entry.name)))

(fn sort-entries [entries orders]
  (table.sort entries (fn [left right]
                        (let [(left-section left-position left-name) (entry-sort-values orders
                                                                                        left)
                              (right-section right-position right-name) (entry-sort-values orders
                                                                                           right)]
                          (if (not (= left-section right-section))
                              (< left-section right-section)
                              (not (= left-position right-position))
                              (< left-position right-position)
                              (< left-name right-name)))))
  entries)

(fn render-entry [state statuses entry]
  (let [kind (. statuses entry.name)]
    (if entry.deleted?
        (.. (marker state "D") (display-name entry))
        (.. (marker state kind) (display-name entry)))))

(fn render-listing-lines [state folder output statuses orders]
  (let [(entries seen) (collect-listing-entries output)
        entries (sort-entries (add-deleted-entries entries seen folder
                                                   state.entries)
                              orders)]
    (if (= 0 (length entries))
        [(.. (marker state nil)
             (tui.color state.theme :muted "No folder entries."))]
        (icollect [_ entry (ipairs entries)]
          (render-entry state statuses entry)))))

(fn render-synthetic-lines [state folder statuses orders]
  (let [entries (sort-entries (synthetic-entries folder state.entries) orders)]
    (if (= 0 (length entries))
        [(.. (marker state nil)
             (tui.color state.theme :muted "Folder not found."))]
        (icollect [_ entry (ipairs entries)]
          (render-entry state statuses entry)))))

(fn render-lines [state row record]
  (let [folder row.path
        statuses (direct-statuses folder state.entries)
        orders (child-orders folder state.entries)
        lines (if record.ok?
                  (render-listing-lines state folder record.output statuses
                                        orders)
                  (render-synthetic-lines state folder statuses orders))]
    (table.insert lines 1 "")
    (table.insert lines 1 (.. (marker state
                                      (folder-status-kind (or row.entries
                                                              state.entries)))
                              folder "/"))
    lines))

(fn ensure-cache [state]
  (when (not state.folder_preview_cache)
    (set state.folder_preview_cache {}))
  state.folder_preview_cache)

(fn load-record [path]
  (let [(output ok _kind _code) (sys.read-command (command path))]
    {:ok? ok :output output}))

(fn lines [state row]
  (let [cache (ensure-cache state)
        path row.path
        cached (. cache path)
        record (or cached (load-record path))]
    (when (not cached)
      (tset cache path record))
    (render-lines state row record)))

{: command
 : child-status-kind
 : direct-child
 : direct-file-child
 : direct-statuses
 : folder-status-kind
 : listing-entry
 : lines
 : render-lines}
