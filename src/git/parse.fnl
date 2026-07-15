(local str (require :util.string))

(local trim str.trim)

(fn split-tabs [line]
  (icollect [part (string.gmatch line "([^\t]+)")]
    part))

(fn entry [status path ?old-path]
  {: status :kind (status:sub 1 1) : path :old_path ?old-path :reviewed false})

(fn entry-from-name-status-line [line]
  (let [parts (split-tabs line)
        status (. parts 1)
        kind (and status (status:sub 1 1))
        path (. parts 2)
        new-path (. parts 3)
        path-entry #(entry status path)]
    (case kind
      "A" (path-entry)
      "M" (path-entry)
      "D" (path-entry)
      "R" (entry "R" new-path path)
      "C" (entry "R" new-path path)
      _ nil)))

(fn parse-name-status [text]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (entry-from-name-status-line line)))

(fn parse-untracked [text]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (doto (entry "A" line)
      (tset :unstaged? true)
      (tset :untracked? true))))

(fn parse-path-set [text]
  (collect [line (string.gmatch (or text "") "[^\r\n]+")]
    (values line true)))

(fn mark-unstaged [entries staged]
  (each [_ entry (ipairs entries)]
    (when (not (. staged entry.path))
      (set entry.unstaged? true)))
  entries)

(fn parse-working [name-status-text staged-text untracked-text]
  (let [staged (parse-path-set staged-text)
        entries (mark-unstaged (parse-name-status name-status-text) staged)]
    (each [_ untracked (ipairs (parse-untracked untracked-text))]
      (table.insert entries untracked))
    entries))

(fn insert-unique [items value]
  (when (and value (< 0 (length value)))
    (var found? false)
    (each [_ item (ipairs items)]
      (when (= item value)
        (set found? true)))
    (when (not found?)
      (table.insert items value))))

(fn rename-target-path [path]
  (let [(prefix _before after suffix) (path:match "^(.-){(.-) => (.-)}(.*)$")]
    (if prefix
        (.. prefix after suffix)
        (let [target (path:match "^.- => (.-)$")]
          (and target (trim target))))))

(fn numstat-paths [path]
  (let [paths []]
    (insert-unique paths path)
    (insert-unique paths (rename-target-path path))
    paths))

(fn add-file-stats [files path additions deletions]
  (each [_ path (ipairs (numstat-paths path))]
    (tset files path {: additions : deletions})))

(fn markdown-path? [path]
  (let [lower (and path (path:lower))]
    (and lower (or (lower:match "%.md$") (lower:match "%.markdown$")) true)))

(fn code-path? [path]
  (not (markdown-path? (or (rename-target-path path) path))))

(fn parse-numstat [text]
  (accumulate [stats {:additions 0
                      :deletions 0
                      :code_additions 0
                      :code_deletions 0
                      :files {}} line (string.gmatch (or text
                                                                              "")
                                                                          "[^\r\n]+")]
    (let [parts (split-tabs line)
          additions (tonumber (. parts 1))
          deletions (tonumber (. parts 2))
          path (. parts 3)
          code? (code-path? path)]
      (when additions
        (set stats.additions (+ stats.additions additions))
        (when code?
          (set stats.code_additions (+ stats.code_additions additions))))
      (when deletions
        (set stats.deletions (+ stats.deletions deletions))
        (when code?
          (set stats.code_deletions (+ stats.code_deletions deletions))))
      (when (and path additions deletions)
        (add-file-stats stats.files path additions deletions))
      stats)))

{: entry
 : entry-from-name-status-line
 : parse-name-status
 : parse-numstat
 : parse-path-set
 : parse-untracked
 : parse-working
 : rename-target-path
 : split-tabs}
