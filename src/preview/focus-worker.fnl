(local focus-server (require :preview.focus-server))

(focus-server.serve (. arg 1) (tonumber (. arg 2)))
