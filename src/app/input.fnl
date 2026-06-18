(local search (require :app.search))
(local messages (require :app.messages))

(fn event-key [key]
  (case key
    :up :up
    :down :down
    :enter :open
    :quit :quit
    :tick :tick
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
    "`" :toggle-tree
    "y" :copy-path
    "p" :open-pr
    "[" :split-left
    "]" :split-right
    "G" :bottom
    "q" :clear-search
    _ key))

(fn next-key [?pending-key key]
  (let [key (event-key key)]
    (if (and (= ?pending-key "g") (= key "g")) (values nil :top)
        (= key "g") (values "g" nil)
        (values nil key))))

(fn read-msg [state raw-key]
  (let [(pending-key action) (next-key state.pending-key raw-key)]
    (if (= raw-key :quit) (messages.quit)
        (= action :toggle-tree) (messages.action :toggle-tree pending-key)
        (search.active? state) (messages.search-input raw-key)
        action (messages.action action pending-key)
        (messages.pending-key pending-key))))

{: event-key : next-key : read-msg}
