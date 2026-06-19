(local ansi (require :tui.ansi))
(local colors (require :tui.colors))

(fn terminator? [buffer ch]
  (or (= ch "\7")
      (and (<= 2 (length buffer))
           (= (buffer:sub (- (length buffer) 1)) (.. ansi.esc "\\")))))

(fn read-response [read-char ?limit]
  (let [limit (or ?limit 128)]
    (var out "")
    (var done? false)
    (for [_ 1 limit]
      (when (not done?)
        (let [ch (read-char)]
          (if ch
              (do
                (set out (.. out ch))
                (when (terminator? out ch)
                  (set done? true)))
              (set done? true)))))
    out))

(fn read-io-response [?limit]
  (read-response #(io.read 1) ?limit))

(fn query-background-rgb []
  (io.write ansi.esc "]11;?\7")
  (io.flush)
  (colors.parse-background-response (read-io-response)))

{: query-background-rgb : read-io-response : read-response : terminator?}
