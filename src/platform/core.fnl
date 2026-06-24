(local str (require :util.string))

(local trim str.trim)

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

(fn first-number [s]
  (let [s (or s "")]
    (tonumber (s:match "([0-9]+)"))))

(fn cpu-count []
  (or (first-number (read-command "getconf _NPROCESSORS_ONLN 2>/dev/null"))
      (first-number (read-command "sysctl -n hw.ncpu 2>/dev/null")) 1))

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

(fn file-exists? [path]
  (let [f (io.open path "r")]
    (if f
        (do
          (f:close)
          true)
        false)))

(fn dir-exists? [path]
  (let [(ok _kind _code) (os.execute (.. "test -d " (shell-quote path)
                                         " 2>/dev/null"))]
    (= ok true)))

(fn remove-file [path]
  (os.remove path))

(fn rename [old new]
  (os.rename old new))

(fn remove-dir [path]
  (os.execute (.. "rm -rf " (shell-quote path) " 2>/dev/null")))

(fn background-shell-command [cmd]
  (.. "( " cmd " ) </dev/null >/dev/null 2>&1 &"))

(fn background-command [cmd]
  (os.execute (background-shell-command cmd)))

(fn temp-path []
  (os.tmpname))

(fn ensure-dir [path]
  (let [(ok _kind _code) (os.execute (.. "mkdir -p " (shell-quote path)
                                         " 2>/dev/null"))]
    ok))

{: background-command
 : background-shell-command
 : cpu-count
 : dir-exists?
 : ensure-dir
 : file-exists?
 : read-command
 : read-file
 : remove-dir
 : remove-file
 : rename
 : shell-quote
 : temp-path
 : trim
 : write-file}
