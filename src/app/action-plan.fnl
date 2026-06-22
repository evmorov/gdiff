(local math-util (require :util.math))

(fn selected-target [view-mode selected-row selected-entry]
  (if (and (= view-mode :tree) selected-row (= selected-row.type :folder))
      {:kind :folder :path selected-row.path}
      (and (= view-mode :tree) selected-row selected-row.unchanged)
      {:kind :file :path selected-row.path}
      selected-entry
      {:kind :file :path selected-entry.path :entry selected-entry}))

(fn copy-path [target]
  (when target
    (if (= target.kind :folder)
        (.. target.path "/")
        target.path)))

(fn split-ratio [current delta]
  (math-util.clamp (+ (or current 0.4) delta) 0.1 0.9))

{: copy-path : selected-target : split-ratio}
