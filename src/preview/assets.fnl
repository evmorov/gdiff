(local extensions {".avif" true
                   ".bmp" true
                   ".gif" true
                   ".heic" true
                   ".ico" true
                   ".jpeg" true
                   ".jpg" true
                   ".pdf" true
                   ".png" true
                   ".svg" true
                   ".tif" true
                   ".tiff" true
                   ".webp" true})

(fn extension [path]
  (let [path (string.lower (or path ""))]
    (path:match "(%.[^%.\\/]+)$")))

(fn asset? [entry]
  (if (. extensions (extension (and entry entry.path)))
      true
      false))

{: asset? : extension}
