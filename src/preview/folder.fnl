(local sys (require :platform.core))
(local symbols (require :tui.symbols))
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
       : rest})))

(fn child-status-kind [entry rest]
  (if (and (rest:find "/" 1 true) (= entry.kind "D"))
      "M"
      entry.kind))

(local status-rank {"C" 1 "M" 2 "A" 3 "R" 4 "D" 5})

(fn stronger-kind [left right]
  (if (< (or (. status-rank left) 0) (or (. status-rank right) 0))
      right
      left))

(fn record-order [orders counts info]
  (when (not (. orders info.name))
    (let [section (if info.folder? 2 1)]
      (tset counts section (+ (. counts section) 1))
      (tset orders info.name {: section :order (. counts section)}))))

(fn record-status [statuses entry info]
  (tset statuses info.name
        (stronger-kind (. statuses info.name)
                       (child-status-kind entry info.rest))))

(fn record-deleted-status [deleted entry info]
  (let [status (or (. deleted info.name)
                   {:folder? info.folder? :all-deleted? true})]
    (set status.folder? (or status.folder? info.folder?))
    (when (not (= entry.kind "D"))
      (set status.all-deleted? false))
    (tset deleted info.name status)))

(fn folder-status-kind [entries]
  (let [first-kind (and (. entries 1) (. (. entries 1) :kind))]
    (if (not first-kind) nil
        (accumulate [same? true _ entry (ipairs entries)]
          (and same? (= first-kind entry.kind))) first-kind
        "M")))

(fn folder-plan [folder entries]
  (let [statuses {}
        deleted {}
        orders {}
        counts {1 0 2 0}
        children []]
    (each [_ entry (ipairs (or entries []))]
      (let [info (child-info folder entry.path)]
        (when info
          (table.insert children {: entry : info})
          (record-order orders counts info)
          (record-status statuses entry info)
          (record-deleted-status deleted entry info))))
    {: statuses
     : deleted
     : orders
     : children
     :folder-kind (folder-status-kind entries)}))

(fn direct-statuses [folder entries]
  (. (folder-plan folder entries) :statuses))

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

(fn split-lines [output]
  (icollect [line (string.gmatch (or output "") "[^\r\n]+")]
    line))

(fn listing-entry [line]
  (let [mode (line:sub 1 1)
        name (or (line:match "^%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(.+)$")
                 "")]
    (when (and (< 0 (length name)) (not (= name ".")) (not (= name "..")))
      (let [name (or (name:match "^(.-) %-> ") name)]
        {: name :folder? (= mode "d")}))))

(fn display-name [entry]
  (if entry.folder?
      (.. entry.name "/")
      entry.name))

(fn listing-entries [output]
  (let [seen {}
        entries []]
    (each [_ line (ipairs (split-lines output))]
      (when (not (line:match "^total "))
        (let [entry (listing-entry line)]
          (when entry
            (tset seen entry.name true)
            (table.insert entries entry)))))
    (values entries seen)))

(fn copy-listing-entries [entries]
  (icollect [_ entry (ipairs (or entries []))]
    {:name entry.name :folder? entry.folder? :deleted? entry.deleted?}))

(fn copy-seen [seen]
  (collect [name value (pairs (or seen {}))]
    (values name value)))

(fn parsed-listing [record]
  (when record.ok?
    (when (not record.listing)
      (let [(entries seen) (listing-entries record.output)]
        (set record.listing {: entries : seen})))
    (values (copy-listing-entries record.listing.entries)
            (copy-seen record.listing.seen))))

(fn add-missing-deleted [entries seen deleted]
  (each [name status (pairs deleted)]
    (when (and status.all-deleted? (not (. seen name)))
      (tset seen name true)
      (table.insert entries {: name :folder? status.folder? :deleted? true})))
  entries)

(fn entries-from-plan [plan]
  (let [entries []
        seen {}]
    (each [_ child (ipairs (or plan.children []))]
      (let [info child.info]
        (when (and info (not (. seen info.name)))
          (tset seen info.name true)
          (let [status (. plan.deleted info.name)
                deleted? (and status status.all-deleted?)]
            (table.insert entries
                          {:name info.name :folder? info.folder? : deleted?})))))
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

(fn display-entries [record plan]
  (if record.ok?
      (let [(entries seen) (parsed-listing record)]
        (add-missing-deleted entries seen plan.deleted))
      (entries-from-plan plan)))

(fn empty-message [state record]
  (let [message (if record.ok? "No folder entries." "Folder not found.")]
    (.. (marker state nil) (tui.color state.theme :muted message))))

(fn render-entry-lines [state record plan]
  (let [entries (sort-entries (display-entries record plan) plan.orders)]
    (if (= 0 (length entries))
        [(empty-message state record)]
        (icollect [_ entry (ipairs entries)]
          (render-entry state plan.statuses entry)))))

(fn header-lines [state folder entries ?kind]
  (let [header (.. (marker state (or ?kind (folder-status-kind entries)))
                   folder "/")
        divider (string.rep symbols.line.horizontal (tui.visible-length header))]
    [header (tui.color state.theme :muted divider)]))

(fn with-header [lines state row plan]
  (let [out []]
    (each [_ line (ipairs (header-lines state row.path
                                        (or row.entries state.entries)
                                        plan.folder-kind))]
      (table.insert out line))
    (each [_ line (ipairs lines)]
      (table.insert out line))
    out))

(fn plan-entries [state row]
  (or row.entries state.entries))

(fn folder-plan-for [state row]
  (if row.entries
      (or row.folder_plan (let [plan (folder-plan row.path row.entries)]
                            (set row.folder_plan plan)
                            plan))
      (folder-plan row.path state.entries)))

(fn render-lines [state row record]
  (let [plan (folder-plan-for state row)
        lines (render-entry-lines state record plan)]
    (with-header lines state row plan)))

(fn ensure-cache [state]
  (when (not state.folder_preview_cache)
    (set state.folder_preview_cache {}))
  state.folder_preview_cache)

(fn load-record [path]
  (let [(output ok _kind _code) (sys.read-command (command path))]
    {:ok? ok : output}))

(fn cached-record [cache path]
  (. cache path))

(fn cache-record [cache path record]
  (tset cache path record)
  record)

(fn record-for [state path]
  (let [cache (ensure-cache state)
        cached (cached-record cache path)]
    (or cached (cache-record cache path (load-record path)))))

(fn lines [state row]
  (render-lines state row (record-for state row.path)))

{: command
 : cached-record
 : cache-record
 : child-status-kind
 : direct-child
 : direct-file-child
 : direct-statuses
 : folder-status-kind
 : folder-plan-for
 : listing-entry
 : parsed-listing
 : load-record
 : lines
 : plan-entries
 : record-for
 : render-lines
 : with-header}
