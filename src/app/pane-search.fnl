(local search (require :app.search))
(local preview-search (require :app.preview-search))

(fn focused [state]
  (if (= state.focus :right) preview-search search))

(fn active? [state]
  ((. (focused state) :active?) state))

(fn handle-input [state key]
  ((. (focused state) :handle-input) state key))

(fn start [state]
  ((. (focused state) :start) state))

(fn next [state]
  ((. (focused state) :next) state))

(fn previous [state]
  ((. (focused state) :previous) state))

(fn clear [state]
  ((. (focused state) :clear) state))

(fn status [state]
  ((. (focused state) :status) state))

(fn refresh-status [state]
  ((. (focused state) :refresh-status) state))

{: active?
 : clear
 : handle-input
 : next
 : previous
 : refresh-status
 : start
 : status}
