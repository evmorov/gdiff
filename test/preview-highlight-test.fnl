(local faith (require :faith))
(local bat (require :platform.bat))
(local highlight (require :preview.highlight))
(local sys (require :platform.core))
(local theme (require :tui.theme))
(local tui (require :tui.core))
(local t (require :test-helper))

(local light (theme.new {:r 255 :g 255 :b 255}))

(fn test-needed-lines-reads-the-last-line-of-each-hunk []
  (faith.= {:old 40 :new 51}
           (highlight.needed-lines "@@ -1,3 +1,3 @@\n x\n@@ -40 +50,2 @@\n+y"))
  (faith.= {:old 0 :new 0} (highlight.needed-lines "no hunks here")))

(fn test-line-map-indexes-lines-by-number []
  (faith.= {1 "a" 2 "b"} (highlight.line-map ["a" "b"]))
  (faith.= nil (highlight.line-map nil)))

(fn test-styled-line-requires-matching-plain-text []
  (let [map {2 "\27[32mfoo\27[0m" 3 "" 4 "\27[32mfoo\27[0m"}]
    (faith.= "\27[32mfoo\27[0m" (highlight.styled-line map 2 "foo"))
    (faith.= nil (highlight.styled-line map 4 "bar"))
    (faith.= nil (highlight.styled-line map 3 ""))
    (faith.= nil (highlight.styled-line map 9 "foo"))
    (faith.= nil (highlight.styled-line nil 2 "foo"))
    (faith.= nil (highlight.styled-line map nil "foo"))))

(fn test-emphasize-styled-marks-visible-columns-and-resumes-line-tint []
  (let [styled "\27[32mfoo\27[0m bar"
        out (highlight.emphasize-styled light styled "foo bar"
                                        [{:from 5 :to 8}] :emphasis-added)
        start (theme.style-for light :emphasis-tint-added)
        stop (theme.style-for light :line-added)]
    (faith.= "foo bar" (tui.strip-ansi out))
    (faith.= (.. "\27[32mfoo\27[0m " start "bar" stop) out)))

(fn test-emphasize-styled-survives-token-resets-inside-the-range []
  (let [raw "x(id: \"zitadel\")"
        styled "x(\27[32mid\27[0m: \27[32m\"\27[0m\27[32mzitadel\27[0m\27[32m\"\27[0m)"
        out (highlight.emphasize-styled light styled raw [{:from 6 :to 16}]
                                        :emphasis-deleted)
        start (theme.style-for light :emphasis-tint-deleted)
        stop (theme.style-for light :line-deleted)]
    (faith.= raw (tui.strip-ansi out))
    (faith.= (.. "x(\27[32mid\27[0m:" start " \27[32m\"\27[0m" start
                 "\27[32mzitadel\27[0m" start "\27[32m\"" stop "\27[0m)")
             out)))

(fn test-emphasize-styled-without-ranges-returns-styled-text []
  (faith.= "\27[32mfoo\27[0m"
           (highlight.emphasize-styled light "\27[32mfoo\27[0m" "foo" []
                                       :emphasis-added))
  (faith.= "\27[32mfoo\27[0m"
           (highlight.emphasize-styled light "\27[32mfoo\27[0m" "foo" nil
                                       :emphasis-added)))

(fn test-emphasize-styled-needs-line-tints []
  (faith.= "foo bar"
           (highlight.emphasize-styled theme.default "foo bar" "foo bar"
                                       [{:from 5 :to 8}] :emphasis-added)))

(fn test-tint-roles-map-line-roles-to-background-tints []
  (faith.= :line-added (highlight.tint-role :status-added))
  (faith.= :line-added (highlight.tint-role :comment-added))
  (faith.= :line-deleted (highlight.tint-role :status-deleted))
  (faith.= :line-deleted (highlight.tint-role :comment-deleted))
  (faith.= nil (highlight.tint-role :moved))
  (faith.= :line-added (highlight.emphasis-end :emphasis-added))
  (faith.= :line-deleted (highlight.emphasis-end :emphasis-deleted))
  (faith.= :emphasis-tint-added (highlight.emphasis-tint :emphasis-added))
  (faith.= :emphasis-tint-deleted (highlight.emphasis-tint :emphasis-deleted)))

(fn test-within-cap-allows-unknown-and-small-counts []
  (faith.= true (highlight.within-cap? nil))
  (faith.= true (highlight.within-cap? highlight.max-lines))
  (faith.= false (highlight.within-cap? (+ highlight.max-lines 1))))

(fn test-bat-highlights-a-file-when-installed []
  (when (not (sys.command-exists? "bat"))
    (faith.skip))
  (t.reset-workdir)
  (t.write-file "a.py" "x = 1\n\ny = \"s\"\n")
  (let [lines (bat.highlight-lines {:file "a.py"} "a.py" nil "ansi")]
    (faith.= 3 (length lines))
    (faith.= "x = 1" (tui.strip-ansi (. lines 1)))
    (faith.= "" (. lines 2))
    (faith.= "y = \"s\"" (tui.strip-ansi (. lines 3)))
    (faith.is (string.find (. lines 1) "\27[" 1 true))))

(fn test-bat-line-range-stops-at-the-requested-line []
  (when (not (sys.command-exists? "bat"))
    (faith.skip))
  (t.reset-workdir)
  (t.write-file "a.py" "a = 1\nb = 2\nc = 3\n")
  (let [lines (bat.highlight-lines {:file "a.py"} "a.py" 2 "ansi")]
    (faith.= 2 (length lines))
    (faith.= "b = 2" (tui.strip-ansi (. lines 2)))))

{: test-bat-highlights-a-file-when-installed
 : test-bat-line-range-stops-at-the-requested-line
 : test-emphasize-styled-marks-visible-columns-and-resumes-line-tint
 : test-emphasize-styled-needs-line-tints
 : test-emphasize-styled-survives-token-resets-inside-the-range
 : test-emphasize-styled-without-ranges-returns-styled-text
 : test-line-map-indexes-lines-by-number
 : test-needed-lines-reads-the-last-line-of-each-hunk
 : test-styled-line-requires-matching-plain-text
 : test-tint-roles-map-line-roles-to-background-tints
 : test-within-cap-allows-unknown-and-small-counts}
