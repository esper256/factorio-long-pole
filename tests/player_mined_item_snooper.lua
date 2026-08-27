-- Exercises one real-event-shaped input without launching Factorio.
storage = {}
defines = {
  events = {
    on_player_mined_item = 1
  }
}
game = {
  get_player = function(player_index)
    assert(player_index == 1)
    return {
      surface = {
        name = "nauvis"
      }
    }
  end
}

local snooper = require("snoopers.player_mined_item")

snooper.on_event({
  player_index = 1,
  item_stack = {
    name = "iron-plate",
    count = 3
  }
})

assert(storage.long_pole.debug_game_state.surfaces.nauvis.products["iron-plate"].produced == 3)
