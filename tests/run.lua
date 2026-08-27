local failures = {}
local passes = 0
local current_file = "?"
local describe_stack = {}
local before_stack = {}
local after_stack = {}

local function full_name(it_name)
  local parts = {}
  for _, name in ipairs(describe_stack) do
    parts[#parts + 1] = name
  end
  parts[#parts + 1] = it_name
  return table.concat(parts, " / ")
end

local function deep_equal(a, b, seen)
  if a == b then
    return true
  end
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return false
  end
  seen = seen or {}
  if seen[a] and seen[a] == b then
    return true
  end
  seen[a] = b
  for key, value in pairs(a) do
    if not deep_equal(value, b[key], seen) then
      return false
    end
  end
  for key in pairs(b) do
    if a[key] == nil then
      return false
    end
  end
  return true
end

local function inspect(value, seen)
  local value_type = type(value)
  if value_type == "string" then
    return string.format("%q", value)
  end
  if value_type ~= "table" then
    return tostring(value)
  end
  seen = seen or {}
  if seen[value] then
    return "<cycle>"
  end
  seen[value] = true
  local parts = {}
  for key, entry in pairs(value) do
    parts[#parts + 1] = "[" .. inspect(key, seen) .. "]=" .. inspect(entry, seen)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function fail(message)
  error(message, 3)
end

local native_assert = assert
local assertion = {}
local assertion_mt = {
  __call = function(_, ...)
    return native_assert(...)
  end
}

assertion.is_true = function(value)
  if value ~= true then
    fail("expected true, got " .. inspect(value))
  end
end
assertion.is_false = function(value)
  if value ~= false then
    fail("expected false, got " .. inspect(value))
  end
end
assertion.is_nil = function(value)
  if value ~= nil then
    fail("expected nil, got " .. inspect(value))
  end
end
assertion.is_not_nil = function(value)
  if value == nil then
    fail("expected a value, got nil")
  end
end
assertion.is_table = function(value)
  if type(value) ~= "table" then
    fail("expected table, got " .. inspect(value))
  end
end
assertion.is_truthy = function(value)
  if not value then
    fail("expected truthy, got " .. inspect(value))
  end
end
assertion.are = {
  equal = function(expected, actual)
    if expected ~= actual then
      fail("expected " .. inspect(expected) .. " but got " .. inspect(actual))
    end
  end,
  same = function(expected, actual)
    if not deep_equal(expected, actual) then
      fail("expected " .. inspect(expected) .. " but got " .. inspect(actual))
    end
  end
}
assertion.same = assertion.are.same
assertion.are_not = {
  equal = function(expected, actual)
    if expected == actual then
      fail("expected values to differ: " .. inspect(expected))
    end
  end
}

assert = setmetatable(assertion, assertion_mt)

local pending = {}

function describe(name, fn)
  describe_stack[#describe_stack + 1] = name
  before_stack[#before_stack + 1] = before_stack[#before_stack]
  after_stack[#after_stack + 1] = after_stack[#after_stack]
  fn()
  describe_stack[#describe_stack] = nil
  before_stack[#before_stack] = nil
  after_stack[#after_stack] = nil
end

function before_each(fn)
  before_stack[#before_stack] = fn
end

function after_each(fn)
  after_stack[#after_stack] = fn
end

function it(name, fn)
  local collected_name = full_name(name)
  pending[#pending + 1] = {
    file = current_file,
    name = collected_name,
    before_fn = before_stack[#before_stack],
    after_fn = after_stack[#after_stack],
    fn = fn
  }
end

local spec_files = {}
local handle = io.popen("ls tests/*_spec.lua")
for line in handle:lines() do
  spec_files[#spec_files + 1] = line
end
handle:close()
table.sort(spec_files)

package.path = "./?.lua;./?/init.lua;" .. package.path

for _, path in ipairs(spec_files) do
  current_file = path
  describe_stack = {}
  before_stack = {}
  after_stack = {}
  local chunk, load_err = loadfile(path)
  if not chunk then
    failures[#failures + 1] = path .. " failed to load: " .. tostring(load_err)
  else
    local ok, err = pcall(chunk)
    if not ok then
      failures[#failures + 1] = path .. " failed while loading tests: " .. tostring(err)
    end
  end
end

for _, test in ipairs(pending) do
  current_file = test.file
  if test.before_fn then
    local before_ok, before_err = pcall(test.before_fn)
    if not before_ok then
      failures[#failures + 1] = test.file .. " :: " .. test.name .. "\n  before_each: " .. tostring(before_err)
      io.write("F")
      goto continue
    end
  end
  local ok, err = pcall(test.fn)
  if test.after_fn then
    pcall(test.after_fn)
  end
  if ok then
    passes = passes + 1
    io.write(".")
  else
    failures[#failures + 1] = test.file .. " :: " .. test.name .. "\n  " .. tostring(err)
    io.write("F")
  end
  ::continue::
end

io.write("\n")
print(("%d passed, %d failed"):format(passes, #failures))
for _, failure in ipairs(failures) do
  print(failure)
  print("")
end

if #failures > 0 then
  os.exit(1)
end
