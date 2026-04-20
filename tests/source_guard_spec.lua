describe("source guards", function()
  local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = assert(handle:read("*a"))
    handle:close()
    return content
  end

  it("does not dynamically require the plan editor from split_viewer event handlers", function()
    local source = read_file("gui/split_viewer.lua")

    assert.is_nil(source:match('require%("gui%.plan_editor"%)%.open'))
    assert.is_truthy(source:match('local%s+plan_editor%s*=%s*require%("gui%.plan_editor"%)'))
  end)
end)
