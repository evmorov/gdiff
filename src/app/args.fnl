(fn usage []
  (io.stderr:write "Usage: gdiff [--editor <command>] [branch-or-revision-range]\n")
  (io.stderr:write "Without a revision, gdiff tries main first, then master.\n")
  (io.stderr:write "Example: gdiff --editor nvim main...HEAD\n"))

(fn next-arg [argv i option]
  (let [value (. argv (+ i 1))]
    (if value
        (values value (+ i 2) nil)
        (values nil i (.. option " needs a value")))))

(fn parse-editor-option [arg]
  (arg:match "^%-%-editor=(.+)$"))

(fn parse-revision [revision arg]
  (if revision
      (values revision (.. "Unexpected extra argument: " arg))
      (values arg nil)))

(fn parse [argv]
  (let [options {}]
    (fn parse-from [i revision]
      (if (> i (length argv))
          (values options revision nil)
          (let [arg (. argv i)
                editor (parse-editor-option arg)]
            (if editor
                (do
                  (set options.editor editor)
                  (parse-from (+ i 1) revision))
                (or (= arg "--editor") (= arg "-e"))
                (let [(value next-i err) (next-arg argv i arg)]
                  (set options.editor value)
                  (if err
                      (values options revision err)
                      (parse-from next-i revision)))
                (= arg "--")
                (let [(value next-i err) (next-arg argv i "--")]
                  (if err
                      (values options revision err)
                      (parse-from next-i value)))
                (and (= (arg:sub 1 1) "-") (not (= arg "-")))
                (values options revision (.. "Unknown option: " arg))
                (let [(next-revision err) (parse-revision revision arg)]
                  (if err
                      (values options next-revision err)
                      (parse-from (+ i 1) next-revision)))))))

    (parse-from 1 nil)))

{: parse : usage}
