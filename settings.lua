-- Settings stage entrypoint. It stays present even when the current rewrite
-- does not define any mod settings.
data:extend({
  {
    type = "bool-setting",
    name = "long-pole-auto-load-first-plan",
    setting_type = "runtime-per-user",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "long-pole-auto-advance-split",
    setting_type = "runtime-per-user",
    default_value = false
  },
  {
    type = "bool-setting",
    name = "long-pole-put-current-split-in-quickbar",
    setting_type = "runtime-per-user",
    default_value = false
  }
})
