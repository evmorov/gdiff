(local sys (require :platform.core))

(local candidates [{:program "pbcopy" :command "pbcopy" :os "Darwin"}
                   {:program "wl-copy"
                    :command "wl-copy"
                    :env "WAYLAND_DISPLAY"}
                   {:program "xclip" :command "xclip -selection clipboard"}
                   {:program "xsel" :command "xsel --clipboard --input"}
                   {:program "pbcopy" :command "pbcopy"}])

(fn candidate-fits? [candidate env]
  (and (or (not candidate.os) (= candidate.os env.os))
       (or (not candidate.env)
           (let [value (. env candidate.env)]
             (and value (< 0 (length value)))))))

(fn choose-command [env available?]
  (accumulate [found nil _ candidate (ipairs candidates) &until found]
    (when (and (candidate-fits? candidate env) (available? candidate.program))
      candidate.command)))

(fn current-env []
  {:os (sys.os-name) :WAYLAND_DISPLAY (os.getenv "WAYLAND_DISPLAY")})

(var ?cached-command nil)

(fn command []
  (when (not ?cached-command)
    (set ?cached-command (or (choose-command (current-env) sys.command-exists?)
                             false)))
  (or ?cached-command nil))

(fn copy [text]
  (let [?cmd (command)
        f (and ?cmd (io.popen ?cmd "w"))]
    (if f
        (do
          (f:write text)
          (let [(ok _kind _code) (f:close)]
            (and ok true)))
        false)))

{: candidates : choose-command : command : copy}
