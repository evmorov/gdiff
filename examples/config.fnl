{:editor "nvim"}

;; You can also use a command with fixed args:
;; {:editor "idea --wait"}

;; Use a list when the editor executable path itself needs shell quoting:
;; {:editor ["/Applications/IntelliJ IDEA.app/Contents/MacOS/idea" "--wait"]}

;; Syntax highlighting uses bat when it is installed. S toggles it while gdiff runs.
;; Start with it off:
;; {:syntax false}

;; bat renders with its "ansi" theme by default so colors follow the terminal palette.
;; Pick another bat theme with:
;; {:bat-theme "Monokai Extended"}
