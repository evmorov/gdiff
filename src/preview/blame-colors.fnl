(local theme (require :tui.theme))

(local palette-size 7)

(fn author [?label]
  "The author part of a `dd/mm/yyyy Author` blame label, or nil."
  (and ?label (?label:match "^%S+%s+(.+)$")))

(fn hash [text]
  (faccumulate [h 0 i 1 (length text)]
    (% (+ (* h 31) (string.byte text i)) 16777216)))

(fn preferred-slot [name]
  (+ 1 (% (hash name) palette-size)))

(fn free-slot [taken preferred]
  "The first free palette slot at or after `preferred`, wrapping around. Falls
back to `preferred` when every slot is taken."
  (var slot nil)
  (for [offset 0 (- palette-size 1) &until slot]
    (let [candidate (+ 1 (% (+ preferred offset -1) palette-size))]
      (when (not (. taken candidate))
        (set slot candidate))))
  (or slot preferred))

(fn assign [labels]
  "Map each author in `labels` to a palette slot. An author keeps the same
preferred slot across files unless another author in this file already holds
it, so up to seven authors per file get distinct colors."
  (let [slots {}
        taken {}]
    (each [_ label (ipairs labels)]
      (let [?author (author label)]
        (when (and ?author (not (. slots ?author)))
          (let [slot (free-slot taken (preferred-slot ?author))]
            (tset slots ?author slot)
            (tset taken slot true)))))
    slots))

(fn role [slots ?label]
  (let [?author (author ?label)
        ?slot (and ?author (. slots ?author))]
    (when ?slot
      (.. :blame- ?slot))))

(fn colorize [theme-table slots ?label]
  (case (role slots ?label)
    r (theme.color theme-table r ?label)
    _ ?label))

{: assign : author : colorize : palette-size : role}
