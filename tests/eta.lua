local eta = require("progress_analysis.eta")

assert(eta.finish_ticks(0, 0, 0) == 0)
assert(eta.finish_ticks(60, 60, 0) == 3600)
assert(eta.finish_ticks(120, 0, 0) == 3600)
assert(eta.handcraft_per_minute(0.5, 1) == 120)
assert(eta.handcraft_per_minute(1, 2) == 120)
assert(eta.finish_ticks(120, 0, 120) == 3600)
