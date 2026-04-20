local tracker = require("split_tracker")
local plan_loader = require("plan_loader")

describe("split_tracker", function()
  local function initialized_state_with_plan()
    local state = {}
    tracker.init(state)
    plan_loader.ensure_plan_loaded(state)
    tracker.init(state)
    return state
  end

  it("initializes a consistent empty state before a plan source loads data", function()
    local state = {}
    tracker.init(state)

    assert.is_table(state.inventory)
    assert.is_table(state.splits)
    assert.is_table(state.editor_selection)
    assert.are.equal(1, state.current_split_index)
    assert.are.equal(0, #state.splits)
  end)

  it("loads sample plan data through the plan loader interface", function()
    local state = {}
    tracker.init(state)

    assert.is_true(plan_loader.ensure_plan_loaded(state))
    tracker.init(state)

    assert.are.equal("sample-plan", state.plan_source)
    assert.are.equal("Starter Burners", state.splits[1].name)
    assert.are.equal("First Power", state.splits[2].name)
  end)

  it("advances split index without running past the final split", function()
    local state = initialized_state_with_plan()

    assert.is_true(tracker.advance_split(state))
    assert.are.equal(2, state.current_split_index)

    state.current_split_index = #state.splits
    assert.is_false(tracker.advance_split(state))
    assert.are.equal(#state.splits, state.current_split_index)
  end)

  it("adds and renames splits", function()
    local state = initialized_state_with_plan()

    local index, split = tracker.add_split(state, "Mall Setup")
    assert.are.equal("Mall Setup", split.name)

    assert.is_true(tracker.rename_split(state, index, "  Green Science  "))
    assert.are.equal("Green Science", state.splits[index].name)
  end)

  it("returns split status grouped around the current split", function()
    local state = initialized_state_with_plan()
    tracker.add_split(state, "Labs")
    state.current_split_index = 2

    local status = tracker.get_split_status(state)

    assert.are.equal("Starter Burners", status.previous.name)
    assert.are.equal("First Power", status.current.name)
    assert.are.equal("Labs", status.upcoming[1].name)
  end)
end)
