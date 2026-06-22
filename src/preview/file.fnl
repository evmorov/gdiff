(local sys (require :platform.core))

(fn bat-command [path]
  (.. "bat --color=always --style=plain --paging=never -- "
      (sys.shell-quote path) " 2>&1"))

(fn cat-command [path]
  (.. "cat -- " (sys.shell-quote path) " 2>&1"))

(fn preview-command [path bat?]
  (if bat? (bat-command path) (cat-command path)))

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

(fn output [path bat?]
  (sys.read-command (preview-command path bat?)))

{: bat-command : cat-command : preview-command : split-lines : output}
