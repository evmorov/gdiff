(local sys (require :platform.core))

(fn opener-command []
  (let [(uname ok _kind _code) (sys.read-command "uname -s 2>/dev/null")]
    (if (and ok (= (sys.trim uname) "Darwin"))
        "open"
        "xdg-open")))

(fn command [url ?opener]
  (.. (or ?opener (opener-command)) " " (sys.shell-quote url)))

(fn open [url]
  (sys.background-command (command url)))

{: command : open : opener-command}
