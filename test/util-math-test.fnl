(local faith (require :faith))
(local math-util (require :util.math))

(fn test-clamp-keeps-values-inside-range []
  (faith.= 5 (math-util.clamp 5 1 10))
  (faith.= 1 (math-util.clamp -2 1 10))
  (faith.= 10 (math-util.clamp 12 1 10)))

{: test-clamp-keeps-values-inside-range}
