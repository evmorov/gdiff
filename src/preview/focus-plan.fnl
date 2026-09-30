(fn request-path [dir]
  (.. dir "/request.lua"))

(fn claimed-path [dir]
  (.. dir "/claimed.lua"))

(fn response-path [dir n]
  (.. dir "/out-" n ".lua"))

(fn ready-path [dir]
  (.. dir "/ready"))

(fn alive-path [dir]
  (.. dir "/alive"))

(fn request [seq wanted settings]
  {: seq
   :id wanted.id
   :generation wanted.generation
   :key wanted.key
   :kind wanted.kind
   :target wanted.target
   : settings})

(fn needs-request? [?pending wanted]
  (not (and ?pending (= ?pending.id wanted.id)
            (= ?pending.generation wanted.generation))))

;; The server waits one poll before claiming a request, so while a key is held
;; it skips files the cursor only passes over.
(fn claimable? [?seen-seq request]
  (and request (= ?seen-seq request.seq) true))

(fn accept? [response generation]
  (and (= (type response) :table) (= response.generation generation)
       (not= nil response.key) true))

(fn response [request data]
  (let [out {:key request.key
             :generation request.generation
             :kind request.kind}]
    (each [k v (pairs data)]
      (tset out k v))
    out))

{: accept?
 : alive-path
 : claimable?
 : claimed-path
 : needs-request?
 : ready-path
 : request
 : request-path
 : response
 : response-path}
