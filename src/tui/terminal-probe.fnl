(local sys (require :platform.core))
(local str (require :util.string))

(local read-command sys.read-command)

(local trim str.trim)

(fn parse-size [output]
  (let [output (or output "")
        (rows cols) (output:match "^(%d+)%s+(%d+)")]
    (values (or (tonumber rows) 24) (or (tonumber cols) 80))))

(fn terminal-size []
  (parse-size (read-command "stty size 2>/dev/null")))

(fn saved-stty []
  (trim (read-command "stty -g 2>/dev/null")))

{: parse-size : read-command : saved-stty : terminal-size : trim}
