SeiferFindBattleState = State:new()

function SeiferFindBattleState:needToRun(game_context, bot_context)
  -- must NOT be in battle
  if game_context.battle.is_in_battle then
    return false
  end
  
  for character_index = 0,2 do
    local character = game_context.characters[character_index]
    
    -- party must contain squall, zell and seifer
    if not (character.id == 0x00 or character.id == 0x01 or character.id == 0x06) then
      return false
    end
    
    -- squall cannot be alive
    if character.id == 0x00 and character.current_hp > 0 then
      return false
    end
    
    -- zell cannot be alive
    if character.id == 0x01 and character.current_hp > 0 then
      return false
    end
    
    -- seifer must be alive
    if character.id == 0x06 and character.current_hp <= 0 then
      return false
    end
  end
  
  return true
end

function SeiferFindBattleState:writeText(game_context, bot_context)
  gui.text(0, 0, "Seifer find battle")
  
  for character_index = 0,2 do
    if game_context.characters[character_index].id == 0x06 then
      gui.text(0, 15, "level " .. game_context.characters[character_index].level)
    end
  end
end

function SeiferFindBattleState:run(game_context, bot_context, keys)
  bot_context.left_right_countdown = bot_context.left_right_countdown or 20

  if bot_context.left_right_countdown == 0 then
    if bot_context.tapping_left then
      bot_context.tapping_left = false
      bot_context.tapping_right = true
    else
      bot_context.tapping_left = true
      bot_context.tapping_right = false
    end
    
    bot_context.left_right_countdown = 20
  end
  
  if bot_context.tapping_left then
    keys.Left = true
  else
    keys.Right = true
  end

  bot_context.left_right_countdown = bot_context.left_right_countdown - 1
end
