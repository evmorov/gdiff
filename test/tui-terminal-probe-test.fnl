(local faith (require :faith))
(local probe (require :tui.terminal-probe))

(fn test-parse-size-reads-stty-size-output []
  (let [(rows cols) (probe.parse-size "42 120\n")]
    (faith.= 42 rows)
    (faith.= 120 cols)))

(fn test-parse-size-falls-back-to-default-size []
  (let [(rows cols) (probe.parse-size "")]
    (faith.= 24 rows)
    (faith.= 80 cols)))

(fn test-trim-removes-surrounding-whitespace []
  (faith.= "abc" (probe.trim "  abc\n")))

{: test-parse-size-falls-back-to-default-size
 : test-parse-size-reads-stty-size-output
 : test-trim-removes-surrounding-whitespace}
