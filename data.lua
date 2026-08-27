-- Data stage entrypoint. It defines runtime-facing prototypes such as custom
-- inputs without pushing that work into control.lua.
data:extend({
  {
    type = "custom-input",
    name = "long-pole-toggle-debug-window",
    key_sequence = "CONTROL + SHIFT + L",
  }
})
