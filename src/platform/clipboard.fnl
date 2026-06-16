(fn copy [text]
  (let [f (io.popen "pbcopy" "w")]
    (if f
        (do
          (f:write text)
          (let [(ok _kind _code) (f:close)]
            ok))
        false)))

{: copy}
