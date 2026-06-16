(fn clamp [n low high]
  (math.max low (math.min high n)))

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
  (clamp (round (+ channel (* (- target channel) amount))) 0 255))

(fn selected-background [rgb]
  (when rgb
    (let [target (if (< (luminance rgb) 0.5) 255 0)
          amount 0.08]
      {:r (mix-channel rgb.r target amount)
       :g (mix-channel rgb.g target amount)
       :b (mix-channel rgb.b target amount)})))

(fn background-style [rgb]
  (let [bg (selected-background rgb)]
    (when bg
      (.. "\27[48;2;" bg.r ";" bg.g ";" bg.b "m"))))

{: background-style : parse-background-response : selected-background}
