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

(fn remove-file [path]
  (os.remove path))

(fn remove-dir [path]
  (os.execute (.. "rm -rf " (shell-quote path) " 2>/dev/null")))

(fn background-command [cmd]
  (os.execute (.. cmd " >/dev/null 2>&1 &")))

(fn temp-path []
  (os.tmpname))

(fn ensure-dir [path]
  (let [(ok _kind _code) (os.execute (.. "mkdir -p " (shell-quote path)
                                         " 2>/dev/null"))]
    ok))

{: background-command
 : ensure-dir
 : read-command
 : read-file
 : remove-dir
 : remove-file
 : shell-quote
 : temp-path
 : trim
 : write-file}
