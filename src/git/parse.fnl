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

(fn strip-dir-prefix [path dir]
  (let [prefix (.. (dir:gsub "/+$" "") "/")]
    (when (= prefix (path:sub 1 (length prefix)))
      (path:sub (+ (length prefix) 1)))))

(fn join-path [dir rel]
  (.. (dir:gsub "/+$" "") "/" rel))

(fn hidden-dir-path? [path]
  (accumulate [found? false dir (string.gmatch path "([^/]+)/") &until found?]
    (= "." (dir:sub 1 1))))

(fn no-index-dir-entry [status path left right right-dir?]
  (let [rel (strip-dir-prefix path (if (= status "A") right left))]
    (when (and rel (not (hidden-dir-path? rel)))
      (case status
        "A" (doto (entry "A" rel)
              (tset :new_file path))
        "D" (doto (entry "D" rel)
              (tset :old_file path))
        "M" (doto (entry "M" rel)
              (tset :old_file path)
              (tset :new_file (if right-dir? (join-path right rel) right)))))))

(fn no-index-entry [status path left right right-dir?]
  (if (or (= path left) (= path right))
      (doto (entry "M" right (when (not= left right) left))
        (tset :old_file left)
        (tset :new_file right))
      (no-index-dir-entry status path left right right-dir?)))

(fn parse-no-index [text left right right-dir?]
  (icollect [line (string.gmatch (or text "") "[^\r\n]+")]
    (let [(status path) (line:match "^([AMD])\t(.*)$")]
      (when status
        (no-index-entry status path left right right-dir?)))))

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

(fn batch-record [kind content]
  (if (= kind "blob")
      {: content}
      {:missing true}))

(fn parse-cat-file-batch [output]
  "Parse `git cat-file --batch` output into ordered records, by byte offsets:
content may contain newlines and NUL bytes."
  (let [records []]
    (var pos 1)
    (while (<= pos (length output))
      (let [line-end (string.find output "\n" pos true)
            header (output:sub pos (if line-end (- line-end 1) -1))
            (_oid kind size) (header:match "^(%x+) (%S+) (%d+)$")]
        (if (and line-end kind)
            (let [content-start (+ line-end 1)
                  content-end (+ content-start (tonumber size) -1)]
              (table.insert records
                            (batch-record kind
                                          (output:sub content-start content-end)))
              (set pos (+ content-end 2)))
            (do
              (table.insert records {:missing true})
              (set pos (if line-end (+ line-end 1) (+ (length output) 1)))))))
    records))

(fn parse-numstat [text ?keep?]
  (accumulate [stats {:additions 0 :deletions 0 :files {}} line (string.gmatch (or text
                                                                                   "")
                                                                               "[^\r\n]+")]
    (let [parts (split-tabs line)
          additions (tonumber (. parts 1))
          deletions (tonumber (. parts 2))
          path (. parts 3)]
      (when (or (not ?keep?) (not path) (?keep? path))
        (when additions
          (set stats.additions (+ stats.additions additions)))
        (when deletions
          (set stats.deletions (+ stats.deletions deletions)))
        (when (and path additions deletions)
          (add-file-stats stats.files path additions deletions)))
      stats)))

(fn rename-source-path [path]
  (let [(prefix before _after suffix) (path:match "^(.-){(.-) => (.-)}(.*)$")]
    (if prefix
        (.. prefix before suffix)
        (let [source (path:match "^(.-) => .-$")]
          (and source (trim source))))))

(fn no-index-file-path [path]
  (let [target (rename-target-path path)]
    (if (not target) path
        (= target "/dev/null") (rename-source-path path)
        target)))

(fn unrooted [path]
  (path:match "^/*(.*)$"))

(fn no-index-visible? [left right]
  (fn [path]
    (let [file (unrooted (no-index-file-path path))
          rel (or (strip-dir-prefix file (unrooted right))
                  (strip-dir-prefix file (unrooted left)))]
      (or (not rel) (not (hidden-dir-path? rel))))))

{: entry
 : entry-from-name-status-line
 : hidden-dir-path?
 : parse-cat-file-batch
 : parse-name-status
 : no-index-visible?
 : parse-no-index
 : parse-numstat
 : parse-path-set
 : parse-untracked
 : parse-working
 : rename-target-path
 : split-tabs}
