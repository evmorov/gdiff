(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              (ok kind code) (f:close)]
          (values output ok kind code))
        (values "" false "open" 1))))

(fn parse-size [output]
  (let [output (or output "")
        (rows cols) (output:match "^(%d+)%s+(%d+)")]
    (values (or (tonumber rows) 24) (or (tonumber cols) 80))))

(fn terminal-size []
  (parse-size (read-command "stty size 2>/dev/null")))

(fn saved-stty []
  (trim (read-command "stty -g 2>/dev/null")))

{: parse-size : read-command : saved-stty : terminal-size : trim}
