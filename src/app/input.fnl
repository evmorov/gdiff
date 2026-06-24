(local search (require :app.pane-search))
(local messages (require :app.messages))

(fn event-key [key]
  (case key
    :up :up
    :down :down
    :left :preview-left
    :right :preview-right
    :enter :open
    :quit :quit
    :tick :tick
    "\t" :toggle-focus
    "k" :up
    "j" :down
    "h" :preview-left
    "l" :preview-right
    "o" :open
    " " :toggle-reviewed
    "a" :toggle-all-reviewed
    "\4" :preview-down
    "\21" :preview-up
    "/" :search
    "n" :search-next
    "N" :search-previous
    "r" :refresh
    "w" :toggle-wrap
    "f" :toggle-full-context
    "`" :toggle-tree
    "e" :toggle-expand
    "E" :expand-all
    "y" :copy-path
    "Y" :copy-full-path
    "v" :toggle-line-selection
    "p" :open-pr
    "[" :split-left
    "]" :split-right
    "G" :bottom
    "q" :clear-search
    "?" :toggle-help
    _ key))

(fn next-key [?pending-key key]
  (let [key (event-key key)]
    (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
        (= key "g") (values "g" nil)
        (values nil key))))

(fn read-msg [state raw-key]
  (let [(pending-key action) (next-key state.pending-key raw-key)]
    (if (= raw-key :quit) (messages.quit) state.show_help?
        (if (or (= raw-key "q") (= raw-key :escape) (= action :toggle-help))
            (messages.action :toggle-help nil)
            (messages.ignore)) (= raw-key :tick)
        (messages.action :tick pending-key) (= action :toggle-tree)
        (messages.action :toggle-tree pending-key) (search.active? state)
        (messages.search-input raw-key) action
        (messages.action action pending-key) (messages.pending-key pending-key))))

;; Side-effect-free navigation keys whose repeats can be folded into one repaint.
(local coalescible-keys {:j true :k true :G true :g true})

(fn coalesce? [state raw-key]
  (and (. coalescible-keys raw-key) (not (search.active? state)) true))

{: coalesce? : event-key : next-key : read-msg}
