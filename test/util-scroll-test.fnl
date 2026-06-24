(local faith (require :faith))
(local scroll (require :util.scroll))

(fn test-scrolls-when-total-exceeds-visible []
  (faith.is (scroll.scrolls? 10 5))
  (faith.is (not (scroll.scrolls? 5 5)))
  (faith.is (not (scroll.scrolls? 3 5)))
  (faith.is (not (scroll.scrolls? nil nil)))
  (faith.is (scroll.scrolls? 2 nil)))

(fn test-max-offset-never-negative []
  (faith.= 5 (scroll.max-offset 10 5))
  (faith.= 0 (scroll.max-offset 5 5))
  (faith.= 0 (scroll.max-offset 3 5))
  (faith.= 0 (scroll.max-offset nil 5))
  (faith.= 4 (scroll.max-offset 4 nil)))

(fn test-clamp-offset-stays-in-range []
  (faith.= 3 (scroll.clamp-offset 3 10 5))
  (faith.= 5 (scroll.clamp-offset 99 10 5))
  (faith.= 0 (scroll.clamp-offset -2 10 5))
  (faith.= 0 (scroll.clamp-offset 4 5 5))
  (faith.= 0 (scroll.clamp-offset nil 10 5)))

(fn test-info-record-gated-by-scrollability []
  (faith.= {:offset 2 :total 10 :visible 5} (scroll.info 2 10 5))
  (faith.= {:offset 0 :total 10 :visible 5} (scroll.info nil 10 5))
  (faith.= nil (scroll.info 0 5 5))
  (faith.= nil (scroll.info 0 3 5)))

{: test-scrolls-when-total-exceeds-visible
 : test-max-offset-never-negative
 : test-clamp-offset-stays-in-range
 : test-info-record-gated-by-scrollability}
