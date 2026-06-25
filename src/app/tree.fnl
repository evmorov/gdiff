(local math-util (require :util.math))

(fn path-parts [path]
  (let [parts []]
    (each [part (string.gmatch (or path "") "[^/]+")]
      (table.insert parts part))
    parts))

(fn basename [path]
  (or (string.match (or path "") "([^/]+)$") path))

(fn new-node []
  {:dirs {} :dir-order [] :entries [] :files []})

(fn child-dir [node name]
  (let [child (. node.dirs name)]
    (if child
        child
        (let [next (new-node)]
          (tset node.dirs name next)
          (table.insert node.dir-order name)
          next))))

(fn add-entry [root entry index]
  (let [parts (path-parts entry.path)
        count (length parts)]
    (when (< 0 count)
      (var node root)
      (for [i 1 (- count 1)]
        (set node (child-dir node (. parts i)))
        (table.insert node.entries entry))
      (table.insert node.files
                    {: entry :entry-index index :name (. parts count)}))))

(fn single-dir-name [node]
  (and (= 0 (length node.files)) (= 1 (length node.dir-order))
       (. node.dir-order 1)))

(fn compact-dir [node name]
  (var label name)
  (var child (. node.dirs name))
  (var next-name (single-dir-name child))
  (while next-name
    (set label (.. label "/" next-name))
    (set child (. child.dirs next-name))
    (set next-name (single-dir-name child)))
  (values label child))

(fn old-name [entry]
  (basename entry.old_path))

(fn file-name [entry name]
  (case entry.kind
    "R" (.. name " <- " (old-name entry))
    "C" (.. name " <- " (old-name entry))
    _ name))

(fn node-entries [node]
  node.entries)

(fn join-path [prefix name]
  (if (and prefix (< 0 (length prefix)))
      (.. prefix "/" name)
      name))

(fn node-existing [node]
  (let [existing {}]
    (each [_ file (ipairs node.files)]
      (tset existing file.name true))
    (each [name (pairs node.dirs)]
      (tset existing name true))
    existing))

(fn listing-rows [depth prefix entries expanded existing rows]
  (each [_ entry (ipairs entries)]
    (when (not (and existing (. existing entry.name)))
      (let [path (join-path prefix entry.name)]
        (if entry.folder?
            (let [child (. expanded path)]
              (table.insert rows
                            {:type :folder
                             : depth
                             :name (.. entry.name "/")
                             : path
                             :expanded (not (= nil child))})
              (when child
                (listing-rows (+ depth 1) path child expanded nil rows)))
            (table.insert rows
                          {:type :file
                           : depth
                           :unchanged true
                           :folder-path prefix
                           : path
                           :name entry.name}))))))

(fn render-node [node depth rows ?prefix expanded]
  (each [_ file (ipairs node.files)]
    (table.insert rows
                  {:type :file
                   : depth
                   :entry file.entry
                   :entry-index file.entry-index
                   :folder-path ?prefix
                   :name (file-name file.entry file.name)}))
  (let [entries (and ?prefix (. expanded ?prefix))]
    (when entries
      (listing-rows depth ?prefix entries expanded (node-existing node) rows)))
  (each [_ dir-name (ipairs node.dir-order)]
    (let [(label child) (compact-dir node dir-name)
          path (join-path ?prefix label)]
      (table.insert rows
                    {:type :folder
                     : depth
                     :name (.. label "/")
                     : path
                     :expanded (not (= nil (. expanded path)))
                     :entries (node-entries child)})
      (render-node child (+ depth 1) rows path expanded))))

(fn rows [entries ?expanded ?visible?]
  (let [root (new-node)
        out []
        expanded (or ?expanded {})]
    (each [index entry (ipairs entries)]
      (when (or (not ?visible?) (?visible? entry))
        (add-entry root entry index)))
    (render-node root 0 out nil expanded)
    out))

(fn selected-row [rows selected]
  (var found nil)
  (each [index row (ipairs rows)]
    (when (and (not found) (= row.entry-index selected))
      (set found index)))
  (or found 1))

(fn row-at [rows row-index]
  (. rows row-index))

(fn entry-index-at-row [rows row-index]
  (let [row (row-at rows row-index)]
    (when (and row (= row.type :file))
      row.entry-index)))

(fn move-row [rows selected-row delta]
  (let [count (length rows)]
    (if (= count 0)
        1
        (math-util.clamp (+ (or selected-row 1) delta) 1 count))))

(fn first-row [_rows]
  1)

(fn last-row [rows]
  (math.max 1 (length rows)))

{: entry-index-at-row
 : first-row
 : last-row
 : move-row
 : rows
 : row-at
 : selected-row}
