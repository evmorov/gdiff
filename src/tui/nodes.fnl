(import-macros {: defnode} :tui.macros)

(defnode row [text ?selected?] :row :text text :selected? ?selected?)

(defnode list [rows ?scroll] :list :rows rows :scroll ?scroll)

(defnode lines [lines ?scroll] :lines :lines lines :scroll ?scroll)

(defnode split [left right ?ratio] :split :left left :right right :ratio ?ratio)

(fn footer [kind text]
  (when text
    {:type kind :text text}))

(defnode screen [header body ?footer] :screen :header header :body body :footer
  ?footer)

{: footer : lines : list : row : screen : split}
