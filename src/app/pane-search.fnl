(local search (require :app.search))
(local preview-search (require :app.preview-search))

(fn focused [state]
  (if (= state.focus :right) preview-search search))

(fn dispatch [method state]
  ((. (focused state) method) state))

(fn handle-input [state key]
  ((. (focused state) :handle-input) state key))

{:active? #(dispatch :active? $)
 :clear #(dispatch :clear $)
 : handle-input
 :next #(dispatch :next $)
 :previous #(dispatch :previous $)
 :refresh-status #(dispatch :refresh-status $)
 :start #(dispatch :start $)
 :status #(dispatch :status $)}
