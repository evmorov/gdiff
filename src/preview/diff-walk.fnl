;; Shared diff walking bookkeeping on top of diff-parse. Tracks hunk
;; numbering and old/new line counters so preview renderers share one
;; implementation of the scan.

(local diff-parse (require :preview.diff-parse))

(fn walk [text handlers]
  (let [acc {:old-no 1 :new-no 1 :hunk-no 0 :old-path nil :new-path nil}]
    (diff-parse.parse text
                      {:hunk (fn [line]
                               (set acc.hunk-no (+ acc.hunk-no 1))
                               (when handlers.hunk
                                 (handlers.hunk acc line))
                               (let [(old new) (diff-parse.hunk-start line)]
                                 (when old (set acc.old-no old))
                                 (when new (set acc.new-no new))))
                       :context (fn [text]
                                  (when handlers.context
                                    (handlers.context acc text))
                                  (set acc.old-no (+ acc.old-no 1))
                                  (set acc.new-no (+ acc.new-no 1)))
                       :change (fn [removed added]
                                 (when handlers.change
                                   (handlers.change acc removed added))
                                 (set acc.old-no
                                      (+ acc.old-no (length removed)))
                                 (set acc.new-no (+ acc.new-no (length added))))
                       :meta (fn [line]
                               (when handlers.meta
                                 (handlers.meta acc line)))
                       :old-path (fn [path] (set acc.old-path path))
                       :new-path (fn [path] (set acc.new-path path))})
    acc))

{: walk}
