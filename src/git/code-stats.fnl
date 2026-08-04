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
                    :ps1
                    :template] ["#"])
           (extend [:lua :sql :hs :elm] ["--"])
           (extend [:fnl :fnlm :clj :cljs :cljc :edn :el :lisp :scm] [";"])
           (extend [:html :htm :xml :svg] ["<!--"])
           (extend [:css] ["/*" "*"])
           (extend [:erl :hrl :tex] ["%"])))

(local comment-file-names (extend {}
                                  [:gemfile
                                   :rakefile
                                   :guardfile
                                   :vagrantfile
                                   :brewfile
                                   :procfile
                                   :dockerfile
                                   :makefile
                                   :justfile]
                                  ["#"]))

(local test-dirs {:test true
                  :tests true
                  :testing true
                  :spec true
                  :specs true
                  :unit true
                  :integration true
                  :acceptance true
                  :functional true
                  :e2e true
                  :cypress true
                  :__tests__ true
                  :__test__ true
                  :__mocks__ true
                  :__snapshots__ true})

(fn file-extension [path]
  (let [extension (path:match "%.(%w+)$")]
    (and extension (extension:lower))))

(fn file-name [path]
  (let [name (path:match "([^/]+)$")]
    (and name (name:lower))))

(fn markdown-path? [path]
  (let [extension (file-extension path)]
    (or (= extension "md") (= extension "markdown"))))

(fn test-path? [path]
  (accumulate [test? false directory (path:gmatch "([^/]+)/") &until test?]
    (not (= nil (. test-dirs (directory:lower))))))

(fn starts-with? [text prefix]
  (= (text:sub 1 (length prefix)) prefix))

(fn comment-line? [path content]
  (let [prefixes (or (. comment-prefixes (file-extension path))
                     (. comment-file-names (file-name path)))]
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

(fn record [stats path total-key no-tests-key]
  (tset stats total-key (+ (. stats total-key) 1))
  (when (not (test-path? path))
    (tset stats no-tests-key (+ (. stats no-tests-key) 1))))

(fn parse [text]
  (var ?path nil)
  (let [stats {:additions 0
               :deletions 0
               :no_tests_additions 0
               :no_tests_deletions 0}]
    (each [line (string.gmatch (or text "") "[^\r\n]+")]
      (let [?header-path (header-path line)]
        (if ?header-path (set ?path ?header-path) (header? line) nil
            (line:match "^%+")
            (when (counted? ?path (line:sub 2))
              (record stats ?path :additions :no_tests_additions))
            (line:match "^%-")
            (when (counted? ?path (line:sub 2))
              (record stats ?path :deletions :no_tests_deletions)))))
    stats))

{: comment-line? : counted? : markdown-path? : parse : test-path?}
