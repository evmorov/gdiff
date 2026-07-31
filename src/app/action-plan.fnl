(local math-util (require :util.math))

(fn selected-target [view-mode selected-row selected-entry]
  (if (and (= view-mode :tree) selected-row (= selected-row.type :folder))
      {:kind :folder :path selected-row.path}
      (and (= view-mode :tree) selected-row selected-row.unchanged)
      {:kind :file :path selected-row.path}
      selected-entry
      {:kind :file :path selected-entry.path :entry selected-entry}))

(fn base-source-path [target]
  (let [entry (and target target.entry)]
    (if (and entry entry.old_path (< 0 (length entry.old_path)))
        entry.old_path
        (and target target.path))))

(fn open-plan [target pr?]
  (when target
    (if (= target.kind :folder) {:action :folder :path target.path} pr?
        {:action :head-snapshot :path target.path}
        {:action :editor :entry (or target.entry {:path target.path})})))

(fn copy-path [target]
  (when target
    (if (= target.kind :folder)
        (.. target.path "/")
        target.path)))

(fn copy-full-path [target ?root]
  (let [relative (copy-path target)]
    (when relative
      (if (and ?root (< 0 (length ?root)))
          (.. ?root "/" relative)
          relative))))

(fn fenced-snippet [path text]
  (let [fenced (.. "```\n" text "\n```")]
    (if (and path (< 0 (length path)))
        (.. path "\n\n" fenced)
        fenced)))

(fn split-ratio [current delta]
  (math-util.clamp (+ (or current 0.4) delta) 0.1 0.9))

{: base-source-path
 : copy-full-path
 : copy-path
 : fenced-snippet
 : open-plan
 : selected-target
 : split-ratio}
