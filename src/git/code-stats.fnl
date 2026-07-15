(local str (require :util.string))

(local trim str.trim)

(local c-like ["//" "/*" "*"])

(fn extend [target extensions prefixes]
  (each [_ extension (ipairs extensions)]
    (tset target extension prefixes))
  target)

(local comment-prefixes
       (-> {}
           (extend [:js
                    :jsx
                    :mjs
                    :cjs
                    :ts
                    :tsx
                    :java
                    :c
                    :h
                    :cpp
                    :cc
                    :cxx
                    :hpp
                    :hh
                    :cs
                    :go
                    :rs
                    :kt
                    :kts
                    :swift
                    :scala
                    :dart
                    :m
                    :mm] c-like)
           (extend [:php :scss :less :vue] ["//" "/*" "*" "#" "<!--"])
           (extend [:py
                    :rb
                    :sh
                    :bash
                    :zsh
                    :pl
                    :pm
                    :r
                    :yml
                    :yaml
                    :toml
                    :ex
                    :exs
                    :ps1] ["#"])
           (extend [:lua :sql :hs :elm] ["--"])
           (extend [:fnl :fnlm :clj :cljs :cljc :edn :el :lisp :scm] [";"])
           (extend [:html :htm :xml :svg] ["<!--"])
           (extend [:css] ["/*" "*"])
           (extend [:erl :hrl :tex] ["%"])))

(fn file-extension [path]
  (let [extension (path:match "%.(%w+)$")]
    (and extension (extension:lower))))

(fn markdown-path? [path]
  (let [extension (file-extension path)]
    (or (= extension "md") (= extension "markdown"))))

(fn starts-with? [text prefix]
  (= (text:sub 1 (length prefix)) prefix))

(fn comment-line? [path content]
  (let [prefixes (. comment-prefixes (file-extension path))]
    (accumulate [comment? false _ prefix (ipairs (or prefixes []))
                 &until comment?]
      (starts-with? content prefix))))

(fn counted? [?path line]
  (let [content (trim line)]
    (and ?path (not (markdown-path? ?path)) (< 0 (length content))
         (not (comment-line? ?path content)))))

(fn header-path [line]
  (or (line:match "^%+%+%+ b/(.*)$") (line:match "^%-%-%- a/(.*)$")))

(fn header? [line]
  (or (line:match "^%+%+%+ ") (line:match "^%-%-%- ")))

(fn parse [text]
  (var ?path nil)
  (let [stats {:additions 0 :deletions 0}]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (let [?header-path (header-path line)]
        (if ?header-path (set ?path ?header-path) (header? line) nil
            (line:match "^%+")
            (when (counted? ?path (line:sub 2))
              (set stats.additions (+ stats.additions 1)))
            (line:match "^%-")
            (when (counted? ?path (line:sub 2))
              (set stats.deletions (+ stats.deletions 1))))))
    stats))

{: comment-line? : counted? : markdown-path? : parse}
