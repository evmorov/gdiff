(local tui (require :tui.core))

(local shortcuts [["↑ / k" "Move up"]
                  ["↓ / j" "Move down"]
                  ["gg" "Jump to top"]
                  ["G" "Jump to bottom"]
                  ["enter / o" "Open file or folder"]
                  ["← / h" "Scroll preview left"]
                  ["→ / l" "Scroll preview right"]
                  ["C-d / C-u" "Page preview down / up"]
                  ["[ / ]" "Resize split"]
                  ["space" "Toggle reviewed"]
                  ["A" "Toggle all reviewed"]
                  ["/" "Search"]
                  ["n / N" "Next / previous match"]
                  ["q" "Clear search / close help"]
                  ["`" "Toggle file tree"]
                  ["e" "Expand / collapse folder"]
                  ["w" "Toggle wrap"]
                  ["r" "Refresh and sync"]
                  ["y" "Copy path"]
                  ["p" "Open pull request"]
                  ["?" "Toggle this help"]
                  ["Ctrl-C" "Quit"]])

(fn key-width []
  (var width 0)
  (each [_ [keys] (ipairs shortcuts)]
    (set width (math.max width (tui.visible-length keys))))
  width)

(fn pad [text width]
  (let [missing (- width (tui.visible-length text))]
    (if (< 0 missing) (.. text (string.rep " " missing)) text)))

(fn modal [state]
  (let [width (key-width)
        lines (icollect [_ [keys label] (ipairs shortcuts)]
                (.. (tui.color state.theme :selected-marker (pad keys width))
                    "  " label))]
    (tui.modal "Keyboard shortcuts" lines)))

{: modal}
