(local ansi (require :tui.ansi))

(fn search-input? [state]
  (and state state.search state.search.active?))

(fn escape-key [sequence ?b]
  (let [sequence (if ?b (.. (or sequence "") (or ?b "")) (or sequence ""))]
    (case sequence
      "[A" :up
      "[B" :down
      "[200~" :paste-start
      "[201~" :paste-end
      _ :escape)))

(fn decode [state c ?sequence ?b]
  (if (not c) :tick
      (= c ansi.esc) (if (search-input? state) :escape
                         (escape-key ?sequence ?b))
      (= c "\r") :enter
      (= c "\n") :enter
      (= c "\3") :quit
      c))

{: decode : escape-key : search-input?}
