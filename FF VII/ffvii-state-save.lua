SaveGameState = State:new()

function SaveGameState:needToRun(game_context, bot_context)
  return bot_context.is_save_required and game_context.is_in_overworld
end

function SaveGameState:writeText(game_context, bot_context)
  gui.text(0, 0, "save game")
end

function SaveGameState:run(game_context, bot_context)
  savestate.saveslot(9)
  bot_context.is_save_required = false
  bot_context.reload_count = 0
  --console.writeline('saved')
end
