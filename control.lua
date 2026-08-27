-- Mod runtime entrypoint. It only hands control to the runtime layer.
local bootstrap = require("runtime.bootstrap")

bootstrap.install(script)
