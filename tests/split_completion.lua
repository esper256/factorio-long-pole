local split_completion = require("progress_analysis.split_completion")

assert(not split_completion.is_complete({
  { total = 0, done = 0, pending = 0 },
  { total = 0, done = 0, pending = 0 }
}))

assert(split_completion.is_complete({
  { total = 10, done = 10, pending = 0 },
  { total = 0, done = 0, pending = 0 }
}))

assert(split_completion.is_complete({
  { total = 10, done = 10, pending = 0 },
  { total = 20, done = 20, pending = 0 }
}))

assert(not split_completion.is_complete({
  { total = 10, done = 10, pending = 0 },
  { total = 20, done = 19, pending = 1 }
}))
