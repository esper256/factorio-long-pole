describe("source guards", function()
  local runtime_lua_files = {
    "control.lua",
    "gui/plan_editor.lua",
    "gui/split_viewer.lua",
    "plan_storage.lua",
    "split_tracker.lua"
  }

  local function read_lines(path)
    local handle = assert(io.open(path, "r"))
    local lines = {}
    for line in handle:lines() do
      lines[#lines + 1] = line
    end
    handle:close()
    return lines
  end

  local function sanitize_line(line)
    local without_comment = line:gsub("%-%-.*$", "")
    without_comment = without_comment:gsub('"(.-)"', '""')
    without_comment = without_comment:gsub("'(.-)'", "''")
    return without_comment
  end

  local function count_pattern(line, pattern)
    local count = 0
    local start_index = 1
    while true do
      local first, last = line:find(pattern, start_index)
      if not first then
        return count
      end
      count = count + 1
      start_index = last + 1
    end
  end

  local function collect_dynamic_requires(path)
    local lines = read_lines(path)
    local block_stack = {}
    local function_depth = 0
    local violations = {}

    for line_number, raw_line in ipairs(lines) do
      local line = sanitize_line(raw_line)

      if line:match("%f[%a]repeat%f[%A]") then
        block_stack[#block_stack + 1] = "repeat"
      end

      for _ = 1, count_pattern(line, "%f[%a]function%f[%A]") do
        block_stack[#block_stack + 1] = "function"
        function_depth = function_depth + 1
      end

      if function_depth > 0 and line:match("%f[%a]require%s*%(") then
        violations[#violations + 1] = {
          line_number = line_number,
          line = raw_line
        }
      end

      for _ = 1, count_pattern(line, "%f[%a]until%f[%A]") do
        local block_type = table.remove(block_stack)
        if block_type == "function" then
          function_depth = function_depth - 1
        end
      end

      for _ = 1, count_pattern(line, "%f[%a]end%f[%A]") do
        local block_type = table.remove(block_stack)
        if block_type == "function" then
          function_depth = function_depth - 1
        end
      end
    end

    return violations
  end

  it("keeps require() calls out of runtime function bodies", function()
    local failures = {}

    for _, path in ipairs(runtime_lua_files) do
      local violations = collect_dynamic_requires(path)
      for _, violation in ipairs(violations) do
        failures[#failures + 1] = ("%s:%d: %s"):format(path, violation.line_number, violation.line)
      end
    end

    assert.are.equal(0, #failures, table.concat(failures, "\n"))
  end)
end)
