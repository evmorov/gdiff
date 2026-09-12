;; Width math shared by the unified and split preview gutters.

(local tui (require :tui.core))

(fn max-text-width [entries]
  (accumulate [width 0 _ entry (ipairs (or entries []))]
    (math.max width (if entry (tui.visible-length (tostring entry)) 0))))

{: max-text-width}
