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

(fn channel-distance [a b]
  (/ (math.abs (- a b)) 255))

(fn color-distance [a b]
  (/ (+ (channel-distance a.r b.r) (channel-distance a.g b.g)
        (channel-distance a.b b.b)) 3))

(fn nearby-background [rgb ?amount]
  (when rgb
    (let [target (if (< (luminance rgb) 0.5) 255 0)
          amount (or ?amount 0.08)]
      {:r (mix-channel rgb.r target amount)
       :g (mix-channel rgb.g target amount)
       :b (mix-channel rgb.b target amount)})))

(fn selected-background [rgb]
  (nearby-background rgb 0.08))

(fn background-style [rgb ?amount]
  (let [bg (nearby-background rgb ?amount)]
    (when bg
      (.. "\27[48;2;" bg.r ";" bg.g ";" bg.b "m"))))

(fn nearby-foreground [foreground-rgb background-rgb ?amount]
  (when (and foreground-rgb background-rgb)
    (let [amount (or ?amount 0.25)]
      {:r (mix-channel foreground-rgb.r background-rgb.r amount)
       :g (mix-channel foreground-rgb.g background-rgb.g amount)
       :b (mix-channel foreground-rgb.b background-rgb.b amount)})))

(fn readable-foreground [background-rgb]
  (when background-rgb
    (let [target (if (< (luminance background-rgb) 0.5) 255 0)
          amount 0.78]
      {:r (mix-channel background-rgb.r target amount)
       :g (mix-channel background-rgb.g target amount)
       :b (mix-channel background-rgb.b target amount)})))

(fn subtle-foreground [foreground-rgb background-rgb ?amount]
  (let [candidate (nearby-foreground foreground-rgb background-rgb ?amount)]
    (if (and candidate background-rgb
             (> (color-distance candidate background-rgb) 0.35))
        candidate
        (readable-foreground background-rgb))))

(fn foreground-style [foreground-rgb background-rgb ?amount]
  (let [fg (subtle-foreground foreground-rgb background-rgb ?amount)]
    (when fg
      (.. "\27[38;2;" fg.r ";" fg.g ";" fg.b "m"))))

{: background-style
 : foreground-style
 : nearby-background
 : nearby-foreground
 : parse-background-response
 : selected-background}
