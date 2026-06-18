(local search (require :app.search))

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
    (if (= raw-key :quit) {:type :quit}
        (= action :toggle-tree) {:type :toggle-tree :pending-key pending-key}
        (search.active? state) {:type :search-input :key raw-key}
        action {:type action :pending-key pending-key}
        {:type :pending-key :pending-key pending-key})))

{: event-key : next-key : read-msg}
