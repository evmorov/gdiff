(local commands (require :git.commands))

(fn usage []
  (io.stderr:write "Usage: gdiff [--editor <command>] [left [right]]\n")
  (io.stderr:write "Without a revision, gdiff tries main first, then master.\n")
  (io.stderr:write "Use two revisions to compare them with ...\n")
  (io.stderr:write "Use 'working' or 'w' to review working changes.\n")
  (io.stderr:write "Use a GitHub PR URL to review that PR; gdiff fetches it when needed.\n")
  (io.stderr:write "Example: gdiff --editor nvim main HEAD\n"))

(fn next-arg [argv i option]
  (let [value (. argv (+ i 1))]
    (if value
        (values value (+ i 2) nil)
        (values nil i (.. option " needs a value")))))

(fn parse-editor-option [arg]
  (arg:match "^%-%-editor=(.+)$"))

(fn two-dot-range? [revision]
  (var found? false)
  (var i 1)
  (while (and revision i (not found?))
    (let [(start finish) (revision:find "%.%." i)]
      (if (not start)
          (set i nil)
          (let [before (revision:sub (- start 1) (- start 1))
                after (revision:sub (+ finish 1) (+ finish 1))]
            (if (and (not= before ".") (not= after "."))
                (set found? true)
                (set i (+ finish 1)))))))
  found?)

(fn pr-from-arg [arg]
  (let [(owner repo number rest) (arg:match "^https://github%.com/([^/]+)/([^/]+)/pull/(%d+)(.*)$")]
    (when (and owner (or (= rest "") (rest:match "^[/#?]")))
      {: owner
       : repo
       : number
       :url (.. "https://github.com/" owner "/" repo "/pull/" number)})))

(fn pr-from-positionals [positionals]
  (accumulate [found nil _ arg (ipairs positionals) &until found]
    (pr-from-arg arg)))

(fn revision-from-positionals [positionals]
  (case (length positionals)
    0 (values nil nil)
    1 (let [revision (. positionals 1)]
        (if (or (= revision "working") (= revision "w"))
            (values commands.working-revision nil)
            (two-dot-range? revision)
            (values revision "Two-dot ranges are not supported; use ...")
            (values revision nil)))
    2 (let [left (. positionals 1)
            right (. positionals 2)]
        (if (or (two-dot-range? left) (two-dot-range? right))
            (values nil "Two-dot ranges are not supported; use ...")
            (values (.. left "..." right) nil)))
    _ (values nil (.. "Unexpected extra argument: " (. positionals 3)))))

(fn parse [argv]
  (let [options {}
        positionals []]
    (fn add-positional [arg]
      (table.insert positionals arg))

    (var i 1)
    (var parse-error nil)
    (while (and (not parse-error) (<= i (length argv)))
      (let [arg (. argv i)
            editor (parse-editor-option arg)]
        (if editor
            (do
              (set options.editor editor)
              (set i (+ i 1)))
            (or (= arg "--editor") (= arg "-e"))
            (let [(value next-i err) (next-arg argv i arg)]
              (set options.editor value)
              (set i next-i)
              (set parse-error err))
            (= arg "--")
            (let [(value next-i err) (next-arg argv i "--")]
              (set i next-i)
              (set parse-error err)
              (when (not err)
                (add-positional value)))
            (and (= (arg:sub 1 1) "-") (not (= arg "-")))
            (set parse-error (.. "Unknown option: " arg))
            (do
              (add-positional arg)
              (set i (+ i 1))))))
    (if parse-error
        (values options nil parse-error)
        (let [?pr (pr-from-positionals positionals)]
          (if (and ?pr (= 1 (length positionals)))
              (values options nil nil ?pr)
              ?pr
              (values options nil
                      "A PR URL cannot be combined with other revisions")
              (let [(revision err) (revision-from-positionals positionals)]
                (values options revision err)))))))

{: parse : pr-from-arg : revision-from-positionals : usage}
