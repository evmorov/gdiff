(local math-util (require :util.math))

(fn round [n]
  (math.floor (+ n 0.5)))

(fn parse-hex-channel [s]
  (let [value (tonumber s 16)
        max-value (- (^ 16 (length s)) 1)]
    (when (and value (< 0 max-value))
      (round (* (/ value max-value) 255)))))

(fn parse-background-response [response]
  (let [response (or response "")
        (r g b) (response:match "rgb:([%x]+)/([%x]+)/([%x]+)")]
    (when (and r g b)
      {:r (parse-hex-channel r)
       :g (parse-hex-channel g)
       :b (parse-hex-channel b)})))

(fn luminance [rgb]
  (/ (+ (* rgb.r 0.2126) (* rgb.g 0.7152) (* rgb.b 0.0722)) 255))

(fn mix-channel [channel target amount]
  (math-util.clamp (round (+ channel (* (- target channel) amount))) 0 255))

(fn nearby-background [rgb ?amount]
  (when rgb
    (let [target (if (< (luminance rgb) 0.5) 255 0)
          amount (or ?amount 0.08)]
      {:r (mix-channel rgb.r target amount)
       :g (mix-channel rgb.g target amount)
       :b (mix-channel rgb.b target amount)})))

(fn selected-background [rgb]
  (nearby-background rgb 0.08))

(fn background-code [bg]
  (.. "\27[48;2;" bg.r ";" bg.g ";" bg.b "m"))

(fn background-style [rgb ?amount]
  (let [bg (nearby-background rgb ?amount)]
    (when bg
      (background-code bg))))

(fn mix-toward [rgb target amount]
  {:r (mix-channel rgb.r target.r amount)
   :g (mix-channel rgb.g target.g amount)
   :b (mix-channel rgb.b target.b amount)})

(fn tint-style [rgb target amount]
  (when rgb
    (background-code (mix-toward rgb target amount))))

{: background-style
 : mix-toward
 : nearby-background
 : parse-background-response
 : selected-background
 : tint-style}
