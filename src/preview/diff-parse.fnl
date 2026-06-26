(fn diff-path [line]
  (let [stripped (line:sub 5)
        (trimmed _) (stripped:gsub "%s+$" "")]
    (if (= trimmed "/dev/null")
        nil
        (or (trimmed:match "^[ab]/(.+)$") trimmed))))

(fn hunk-start [line]
  (let [(old new) (line:match "^@@ %-(%d+),?%d* %+(%d+)")]
    (values (tonumber old) (tonumber new))))

(fn classify [line in-hunk?]
  (let [first (line:sub 1 1)]
    (if (line:match "^diff ") :file
        (line:match "^@@") :hunk
        (not in-hunk?) :meta
        (= first "+") :added
        (= first "-") :removed
        (= first "\\") :marker
        :context)))

(fn call [handlers key ...]
  (let [handler (. handlers key)]
    (when handler
      (handler ...))))

(fn meta-step [handlers line]
  (if (line:match "^%-%-%- ") (call handlers :old-path (diff-path line))
      (line:match "^%+%+%+ ") (call handlers :new-path (diff-path line))
      (line:match "^index ") nil
      (call handlers :meta line)))

(fn parse [text handlers]
  (let [acc {:removed [] :added [] :in-hunk? false}
        flush (fn []
                (when (or (next acc.removed) (next acc.added))
                  (call handlers :change acc.removed acc.added))
                (set acc.removed [])
                (set acc.added []))]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (case (classify line acc.in-hunk?)
        :file (do
                (flush)
                (set acc.in-hunk? false))
        :hunk (do
                (flush)
                (set acc.in-hunk? true)
                (call handlers :hunk line))
        :meta (meta-step handlers line)
        :added (table.insert acc.added (line:sub 2))
        :removed (table.insert acc.removed (line:sub 2))
        :marker nil
        :context (do
                   (flush)
                   (call handlers :context (line:sub 2)))))
    (flush)))

{: parse : diff-path : hunk-start}
