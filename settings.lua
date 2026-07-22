-- Settings stage entrypoint. It stays present even when the current rewrite
-- does not define any mod settings.
data:extend({
  {
    type = "bool-setting",
    name = "long-pole-auto-load-first-plan",
    setting_type = "runtime-per-user",
    default_value = true
  }
})
