(local faith (require :faith))
(local sys (require :platform.core))

(fn test-background-shell-command-detaches-from-terminal []
  (faith.= "( printf hi ) </dev/null >/dev/null 2>&1 &"
           (sys.background-shell-command "printf hi")))

{: test-background-shell-command-detaches-from-terminal}
