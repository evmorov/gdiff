(local theme (require :tui.theme))

(fn from-settings [settings]
  (let [highlight (or settings.highlight {})]
    {:revision settings.revision
     :revision_old_label settings.old-label
     :revision_new_label settings.new-label
     :full_context? (and settings.full-context? true)
     :hide_comments? (and settings.hide-comments? true)
     :show_blame? (and settings.blame? true)
     :highlight? (and highlight.on? true)
     :highlight_available? (and highlight.on? true)
     :bat_theme highlight.bat-theme
     :theme (theme.new highlight.background)
     :preview_cache {}
     :split_cache {}}))

{: from-settings}
