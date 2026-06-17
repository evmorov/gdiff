(local faith (require :faith))
(local probe (require :tui.terminal_probe))

(fn test-parse_size_reads_stty_size_output []
  (let [(rows cols) (probe.parse-size "42 120\n")]
    (faith.= 42 rows)
    (faith.= 120 cols)))

(fn test-parse_size_falls_back_to_default_size []
  (let [(rows cols) (probe.parse-size "")]
    (faith.= 24 rows)
    (faith.= 80 cols)))

(fn test-trim_removes_surrounding_whitespace []
  (faith.= "abc" (probe.trim "  abc\n")))

{: test-parse_size_falls_back_to_default_size
 : test-parse_size_reads_stty_size_output
 : test-trim_removes_surrounding_whitespace}
