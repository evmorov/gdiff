(local lua-data (require :util.lua-data))
(local str (require :util.string))

(local trim str.trim)

(fn shell-quote [s]
  (let [escaped (string.gsub (tostring s) "'" "'\\''")]
    (.. "'" escaped "'")))

(fn read-command [cmd]
  (let [f (io.popen cmd "r")]
    (if f
        (let [output (f:read "*a")
              ok (f:close)]
          (values output ok))
        (values "" false))))

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

(fn command-succeeds? [cmd]
  (let [(ok _kind _code) (os.execute cmd)]
    (= ok true)))

(fn getenv [name]
  (os.getenv name))

(fn dir-exists? [path]
  (command-succeeds? (.. "test -d " (shell-quote path) " 2>/dev/null")))

(fn remove-file [path]
  (os.remove path))

(fn rename [old new]
  (os.rename old new))

(fn remove-dir [path]
  (os.execute (.. "rm -rf " (shell-quote path) " 2>/dev/null")))

(fn load-data [source name]
  "Run Lua data `source` in text mode with an empty environment. Returns true
and the value, or false and an error."
  (let [setfenv (. _G :setfenv)
        loadstring (. _G :loadstring)
        (chunk err) (if setfenv
                        (let [(chunk err) (loadstring source name)]
                          (when chunk
                            (setfenv chunk {}))
                          (values chunk err))
                        (load source name "t" {}))]
    (if chunk
        (pcall chunk)
        (values false err))))

(fn read-data-file [path]
  "Load a file written by `write-data-file`. Returns true and the value, false
when the file cannot be loaded, or nil when it does not exist."
  (case (read-file path)
    source (load-data source path)
    _ nil))

(fn write-data-file [path value]
  (let [tmp (.. path ".tmp")]
    (and (write-file tmp (lua-data.serialize value)) (rename tmp path) true)))

(fn low-priority-command [cmd]
  (.. "nice -n 10 " cmd))

(fn process-id []
  (let [(out ok) (read-command "echo $PPID")]
    (when ok (first-number out))))

(fn process-alive? [pid]
  (command-succeeds? (.. "kill -0 " (tostring pid) " 2>/dev/null")))

(fn sleep [seconds]
  (os.execute (.. "sleep " seconds)))

(fn background-shell-command [cmd]
  (.. "( " cmd " ) </dev/null >/dev/null 2>&1 &"))

(fn background-command [cmd]
  (os.execute (background-shell-command cmd)))

(fn temp-path []
  (os.tmpname))

(fn command-exists? [program]
  (let [(ok _kind _code) (os.execute (.. "command -v " (shell-quote program)
                                         " >/dev/null 2>&1"))]
    (and ok true)))

(fn os-name []
  (let [(out ok) (read-command "uname -s 2>/dev/null")]
    (when ok (trim out))))

(fn ensure-dir [path]
  (let [(ok _kind _code) (os.execute (.. "mkdir -p " (shell-quote path)
                                         " 2>/dev/null"))]
    ok))

(fn make-temp-dir []
  (let [path (temp-path)]
    (remove-file path)
    (when (ensure-dir path)
      path)))

{: background-command
 : background-shell-command
 : command-exists?
 : command-succeeds?
 : cpu-count
 : dir-exists?
 : ensure-dir
 : file-exists?
 : getenv
 : load-data
 : low-priority-command
 : make-temp-dir
 : os-name
 : process-alive?
 : process-id
 : read-command
 : read-data-file
 : read-file
 : remove-dir
 : remove-file
 : rename
 : shell-quote
 : sleep
 : temp-path
 : trim
 : write-data-file
 : write-file}
