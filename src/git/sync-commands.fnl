(local sys (require :platform.core))

(fn shell-lines [...]
  (table.concat [...] " "))

(fn shell-block [...]
  (.. "( " (shell-lines ...) " )"))

(fn assign-label [target]
  (.. "label=" (sys.shell-quote target) ";"))

(fn resolve-head-script []
  (shell-lines "if [ \"$label\" = HEAD ]; then"
               "branch=$(git branch --show-current 2>/dev/null);"
               "if [ -z \"$branch\" ]; then printf '%s\\t%s\\n' detached HEAD; exit 0; fi;"
               "label=\"$branch\";" "fi;"))

(fn require-local-branch-script []
  (shell-lines "if ! git show-ref --verify --quiet \"refs/heads/$label\"; then"
               "printf '%s\\t%s\\n' skip \"$label\"; exit 0;" "fi;"))

(fn load-upstream-script []
  (shell-lines "upstream=$(git rev-parse --abbrev-ref \"$label@{upstream}\" 2>/dev/null);"
               "if [ -z \"$upstream\" ]; then"
               "printf '%s\\t%s\\n' no-upstream \"$label\"; exit 0; fi;"))

(fn load-ahead-behind-script []
  (shell-lines "counts=$(git rev-list --left-right --count \"$upstream...$label\" 2>/dev/null);"
               "if [ -z \"$counts\" ]; then printf '%s\\t%s\\n' error \"$label\"; exit 0; fi;"
               "set -- $counts;"))

(fn print-branch-status-script []
  "printf '%s\\t%s\\t%s\\t%s\\t%s\\n' branch \"$label\" \"$upstream\" \"$2\" \"$1\";")

(fn target-status-command [target]
  (shell-block (assign-label target) (resolve-head-script)
               (require-local-branch-script) (load-upstream-script)
               (load-ahead-behind-script) (print-branch-status-script)))

(fn fetch-command []
  (shell-lines "GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true"
               "GIT_SSH_COMMAND='ssh -o BatchMode=yes'"
               "nice -n 20 git fetch --quiet --prune </dev/null >/dev/null 2>&1"))

(fn branch-status-command [path targets]
  (let [tmp (.. path ".tmp")
        commands (icollect [_ target (ipairs targets)]
                   (target-status-command target))
        checks (table.concat commands "; ")]
    (.. "( " (fetch-command) "; gdiff_fetch_status=$?; "
        "if [ \"$gdiff_fetch_status\" -ne 0 ]; then "
        "printf '%s\\t%s\\n' fetch-error \"$gdiff_fetch_status\"; " "else "
        checks "; fi ) > " (sys.shell-quote tmp) " && mv " (sys.shell-quote tmp)
        " " (sys.shell-quote path))))

{: branch-status-command : fetch-command : target-status-command}
