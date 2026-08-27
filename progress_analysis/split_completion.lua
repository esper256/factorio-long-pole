-- Decides whether the current split's analyzed requirements permit advancing.
-- It deliberately consumes progress facts rather than HUD elements, so the
-- same rule can later serve a hotkey or another presentation.
local M = {}

function M.is_complete(progress_bars)
  local has_requirement = false

  for _, progress in ipairs(progress_bars) do
    if progress.total > 0 then
      has_requirement = true
      if progress.done < progress.total then
        return false
      end
    end
  end

  return has_requirement
end

return M
