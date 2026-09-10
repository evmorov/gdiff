(local faith (require :faith))
(local blame-colors (require :preview.blame-colors))
(local theme (require :tui.theme))
(local tui (require :tui.core))

(fn test-author-is-the-text-after-the-date []
  (faith.= "Evgenii" (blame-colors.author "29/04/2021 Evgenii"))
  (faith.= nil (blame-colors.author "29/04/2021"))
  (faith.= nil (blame-colors.author nil)))

(fn test-assign-gives-each-author-in-a-file-its-own-slot []
  (let [names (fcollect [i 1 blame-colors.palette-size] (.. "Author" i))
        labels (icollect [_ name (ipairs names)] (.. "01/01/2020 " name))
        slots (blame-colors.assign labels)
        used (collect [_ name (ipairs names)] (values (. slots name) true))]
    (faith.= blame-colors.palette-size
             (accumulate [n 0 _ _ (pairs used)] (+ n 1)))))

(fn test-assign-keeps-an-authors-slot-across-files-when-free []
  (let [alone (blame-colors.assign ["01/01/2020 Ada"])
        with-others (blame-colors.assign ["03/03/2020 Ada"
                                          "02/02/2020 Grace"
                                          "04/04/2020 Linus"])]
    (faith.= (. alone :Ada) (. with-others :Ada))))

(fn test-assign-skips-labels-without-an-author []
  (faith.= {} (blame-colors.assign ["01/01/2020" "02/02/2020"])))

(fn test-role-names-the-slot []
  (let [slots (blame-colors.assign ["01/01/2020 Ada"])]
    (faith.= (.. "blame-" (. slots :Ada))
             (blame-colors.role slots "05/05/2021 Ada"))
    (faith.= nil (blame-colors.role slots "05/05/2021 Grace"))
    (faith.= nil (blame-colors.role slots nil))))

(fn test-colorize-styles-the-whole-label []
  (let [slots (blame-colors.assign ["01/01/2020 Ada" "01/01/2020 Grace"])
        ada (blame-colors.colorize theme.default slots "01/01/2020 Ada")
        grace (blame-colors.colorize theme.default slots "01/01/2020 Grace")]
    (faith.= "01/01/2020 Ada" (tui.strip-ansi ada))
    (faith.= (theme.color theme.default
                          (blame-colors.role slots "01/01/2020 Ada")
                          "01/01/2020 Ada") ada)
    (faith.not= ada grace)
    (faith.= "01/01/2020"
             (blame-colors.colorize theme.default slots "01/01/2020"))
    (faith.= nil (blame-colors.colorize theme.default slots nil))))

{: test-author-is-the-text-after-the-date
 : test-assign-gives-each-author-in-a-file-its-own-slot
 : test-assign-keeps-an-authors-slot-across-files-when-free
 : test-assign-skips-labels-without-an-author
 : test-role-names-the-slot
 : test-colorize-styles-the-whole-label}
