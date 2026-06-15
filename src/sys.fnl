(fn shell-quote [s]
  (let [escaped (string.gsub (tostring s) "'" "'\\''")]
    (.. "'" escaped "'")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              (ok kind code) (f:close)]
          (values output ok kind code))
        (values "" false "open" 1))))

(fn trim [s]
  (let [s (or s "")]
    (or (s:match "^%s*(.-)%s*$") "")))

(fn read-file [path]
  (let [f (io.open path "r")]
    (when f
      (let [contents (f:read "*a")]
        (f:close)
        contents))))

(fn write-file [path contents]
  (let [f (io.open path "w")]
    (if f
        (do
          (f:write contents)
          (f:close)
          true)
        false)))

(fn ensure-dir [path]
  (let [(ok _kind _code) (os.execute (.. "mkdir -p " (shell-quote path)
                                         " 2>/dev/null"))]
    ok))

{: ensure-dir : read-command : read-file : shell-quote : trim : write-file}
