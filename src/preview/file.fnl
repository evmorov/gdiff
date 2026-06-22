(local sys (require :platform.core))

(fn split-lines [output]
  (let [text (or output "")
        len (length text)
        lines []]
    (var pos 1)
    (while (<= pos len)
      (let [nl (string.find text "\n" pos true)
            stop (if nl (- nl 1) len)
            raw (string.sub text pos stop)
            line (or (raw:match "^(.-)\r$") raw)]
        (table.insert lines line)
        (set pos (if nl (+ nl 1) (+ len 1)))))
    lines))

(fn binary? [content]
  (if (string.find (string.sub (or content "") 1 8000) "\0" 1 true)
      true
      false))

(fn read [path]
  (sys.read-file path))

{: binary? : read : split-lines}
