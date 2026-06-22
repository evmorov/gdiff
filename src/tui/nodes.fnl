(import-macros {: defnode} :tui.macros)

(defnode row [text ?selected?] :row
  [:text text]
  [:selected? ?selected?])

(defnode list [rows ?scroll ?x-scroll ?x-max-scroll] :list
  [:rows rows]
  [:scroll ?scroll]
  [:x-scroll ?x-scroll]
  [:x-max-scroll ?x-max-scroll])

(defnode lines [lines ?scroll ?x-scroll ?x-max-scroll] :lines
  [:lines lines]
  [:scroll ?scroll]
  [:x-scroll ?x-scroll]
  [:x-max-scroll ?x-max-scroll])

(defnode split [left right ?ratio] :split
  [:left left]
  [:right right]
  [:ratio ?ratio])

(fn footer [kind text ?right]
  (when (or text ?right)
    {:type kind : text :right ?right}))

(defnode modal [title lines] :modal
  [:title title]
  [:lines lines])

(defnode screen [header body ?footer ?overlay] :screen
  [:header header]
  [:body body]
  [:footer ?footer]
  [:overlay ?overlay])

{: footer : lines : list : modal : row : screen : split}
