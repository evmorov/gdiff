(local commands (require :git.commands))
(local sys (require :platform.core))

(local git-env (.. "GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true "
                   "GIT_SSH_COMMAND='ssh -o BatchMode=yes'"))

(fn shell-lines [...]
  (table.concat [...] " "))

(fn load-info-script [url]
  (shell-lines (.. "out=$(" (commands.pr-info-command url) ");")
               "if [ -z \"$out\" ]; then"
               "printf '%s\\tCould not read PR info\\n' error; exit 0; fi;"
               "base=$(printf '%s\\n' \"$out\" | sed -n 1p);"
               "head=$(printf '%s\\n' \"$out\" | sed -n 2p);"
               "oid=$(printf '%s\\n' \"$out\" | sed -n 3p);"))

(fn fetch-refs-script [number]
  (shell-lines (.. git-env " git fetch origin \"$head\" >/dev/null 2>&1;")
               "if ! git rev-parse --verify --quiet \"$oid^{commit}\" >/dev/null 2>&1; then"
               (.. git-env " git fetch origin "
                   (sys.shell-quote (.. "pull/" number "/head"))
                   " >/dev/null 2>&1;") "fi;"
               (.. git-env " git fetch origin \"$base\" >/dev/null 2>&1;")))

(fn print-info-script []
  "printf '%s\\t%s\\t%s\\t%s\\n' info \"$base\" \"$head\" \"$oid\";")

(fn refresh-command [path pr]
  "Fetch fresh PR info and refs in the background, then publish the PR info
lines for the app to pick up by polling `path`."
  (let [tmp (.. path ".tmp")]
    (.. "( " (load-info-script pr.url) " " (fetch-refs-script pr.number) " "
        (print-info-script) " ) > " (sys.shell-quote tmp) " && mv "
        (sys.shell-quote tmp) " " (sys.shell-quote path))))

(fn parse-output [text]
  (var result nil)
  (each [line (string.gmatch (or text "") "[^\r\n]+")]
    (when (not result)
      (let [(kind a b c) (line:match "^([^\t]+)\t([^\t]*)\t?([^\t]*)\t?([^\t]*)$")]
        (case kind
          :info (set result {:info {:base-branch a :head-branch b :head-oid c}})
          :error (set result {:error a})))))
  (or result {:error "Could not refresh PR"}))

(fn spawn-refresh [path pr]
  (sys.remove-file path)
  (sys.remove-file (.. path ".tmp"))
  (sys.background-command (refresh-command path pr)))

(fn new-state [?pr]
  {:path (sys.temp-path) :running? false :info nil :error nil :pr ?pr})

(fn start [state ?spawn]
  (when (and state.pr (not state.running?))
    (let [spawn (or ?spawn spawn-refresh)]
      (set state.info nil)
      (set state.error nil)
      (set state.running? true)
      (spawn state.path state.pr)
      true)))

(fn finish [state output]
  (let [result (parse-output output)]
    (set state.info result.info)
    (set state.error result.error))
  (set state.running? false)
  (sys.remove-file state.path))

(fn update [state]
  (when state.running?
    (let [output (sys.read-file state.path)]
      (when output
        (finish state output)))))

{: new-state : parse-output : refresh-command : start : update}
