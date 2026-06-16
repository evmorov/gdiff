(local ansi (require :tui.ansi))
(local terminal (require :tui.terminal))

(fn move [row col]
  (terminal.cursor row col))

(fn clear-line []
  (terminal.clear-line))

(fn clear-row [row]
  (move row 1)
  (clear-line))

(fn write [text]
  (io.write (or text "")))

(fn newline []
  (io.write ansi.nl))

(fn writeln [text]
  (write text)
  (newline))

(fn write-at [row col text]
  (move row col)
  (write text))

(fn write-row [row text ?clear?]
  (move row 1)
  (when ?clear?
    (clear-line))
  (write text))

{: clear-line
 : clear-row
 : move
 : newline
 : write
 : write-at
 : write-row
 : writeln}
