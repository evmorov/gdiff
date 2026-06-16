(fn row [text ?selected?]
  {:type :row :text text :selected? ?selected?})

(fn list [rows]
  {:type :list :rows rows})

(fn lines [lines]
  {:type :lines :lines lines})

(fn split [left right ?ratio]
  {:type :split :left left :right right :ratio ?ratio})

(fn footer [kind text]
  (when text
    {:type kind :text text}))

(fn screen [header body ?footer]
  {:type :screen :header header :body body :footer ?footer})

{: footer : lines : list : row : screen : split}
