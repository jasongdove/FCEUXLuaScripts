AcceptBattleRewardsState = State:new()

function AcceptBattleRewardsState:needToRun(game_context, bot_context)
  return game_context.menu.is_in_menu and (game_context.menu.is_accepting_xp or game_context.menu.is_accepting_items)
end

function AcceptBattleRewardsState:writeText(game_context, bot_context)
  gui.text(0, 0, "accept battle rewards")
end

function AcceptBattleRewardsState:run(game_context, bot_context, keys)
  bot_context.is_save_required = true
  pressAndRelease(bot_context, keys, "Circle")
end
