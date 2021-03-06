-- Final Fantasy II Bot
--  - Levels all spells on characters 1-3 (not 4) to TARGET_SPELL_LEVEL defined below.
--  - Fight completion logic is primitive, and bot contains no healing logic at this point,
--     so this is best done in a low-level area at first. Once your HP/stats get high enough, go nuts.
--  - This also works better if all characters have CURE and character 4 is positioned in the front (to allow weapon attacks)

local config = {}
config.TARGET_SPELL_LEVEL = 16
config.TARGET_HP = 9999
config.TARGET_MP = 999
config.TARGET_GIL = 16000000
config.USE_TURBO = true
config.HP_FLOOR_PCT = 0.40
-- MP_FLOOR may need to be set to 1 at first, but 16 is the best spot once you have > 20ish MP and spells start getting leveled
config.MP_FLOOR = 16
-- disabling the INN will make HP and MP leveling difficult, since they require refilling resources
config.USE_INN = true
config.INN = "Mysidia"
-- when your stats get too high, you may want to switch to magic (LEVEL_BY_FIRE = true) if weapon attacks miss
config.LEVEL_BY_FIRE = false
-- this is normally set to false because character 4 can't use the same trick (queue spell and cancel), since the round ends as soon as character 4 queues anything
-- enabling this feature will make the magic leveling process SLOW. HP leveling should be okay
config.LEVEL_CHARACTER_4 = true
config.LEVEL_SPELL_MULTICAST = true

local SPELL_CURE = 0xD4
local SPELL_ESUNA = 0xD7
local SPELL_FIRE = 0xC0
local SPELL_LIGHTNING = 0xC1

-- sorted pairs
function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end
  
  -- if order function given, sort by it by passing the table and keys a, b
  -- otherwise just sort the keys
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end
  
  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

local function cursorisinbattlemenu(game_context, character_index)
  if character_index == 0 then return game_context.cursor_location == 1 or game_context.cursor_location == 33
  elseif character_index == 1 then return game_context.cursor_location == 9 or game_context.cursor_location == 39
  elseif character_index == 2 then return game_context.cursor_location == 17 or game_context.cursor_location == 45
  elseif character_index == 3 then return game_context.cursor_location == 25 or game_context.cursor_location == 51
  else return false
  end
end

local function fightEnemy(game_context, keys, target_enemy)
  if cursorisinbattlemenu(game_context, game_context.active_character) and not game_context.is_magic_menu_open then
    -- select 'fight' menu item
    if game_context.menu_y == 0 then keys.A = 1
    elseif game_context.menu_y == 1 then keys.up = 1
    elseif game_context.menu_y == 2 then keys.up = 1
    elseif game_context.menu_y == 3 then keys.up = 1
    end
  elseif game_context.cursor_location == 0 then
    -- move the cursor to the enemy side
    keys.left = 1
  elseif game_context.cursor_location == 255 then
    -- select the enemy and queue the attack
    if game_context.target_enemy > target_enemy then keys.up = 1
    elseif game_context.target_enemy < target_enemy then keys.down = 1
    else
      keys.A = 1
    end
  end
end

local function fightcharacter(game_context, keys, target_character)
  if cursorisinbattlemenu(game_context, game_context.active_character) and not game_context.is_magic_menu_open then
    -- select 'fight' menu item
    if game_context.menu_y == 0 then keys.A = 1
    elseif game_context.menu_y == 1 then keys.up = 1
    elseif game_context.menu_y == 2 then keys.up = 1
    elseif game_context.menu_y == 3 then keys.up = 1
    end
  elseif game_context.cursor_location == 0 then
    -- select the character and queue the attack
    if game_context.target_character > target_character then keys.up = 1
    elseif game_context.target_character < target_character then keys.down = 1
    else
      keys.A = 1
    end
  elseif game_context.cursor_location == 255 then
    -- move the cursor to the character side
    keys.right = 1
  end
end

local function getspellindex(character_index, spell_id)
  for spell_index = 0,15 do
    if memory.readbyte(0x6100 + (character_index * 0x0040) + 0x0030 + spell_index) == spell_id then
      return spell_index
    end
  end

  return nil
end

local function castwhitemagic(game_context, keys, spell_index, target_character)
  if cursorisinbattlemenu(game_context, game_context.active_character) and not game_context.is_magic_menu_open then
    -- select 'magic' menu item
    if game_context.menu_y == 0 then keys.down = 1
    elseif game_context.menu_y == 1 then keys.down = 1
    elseif game_context.menu_y == 2 then keys.A = 1
    elseif game_context.menu_y == 3 then keys.up = 1
    end
  elseif cursorisinbattlemenu(game_context, game_context.active_character) and game_context.is_magic_menu_open then
    -- select the spell to cast
    local target_row = math.floor(spell_index / 4)
    local target_column = math.fmod(spell_index, 4)
    
    if target_row < game_context.menu_y then keys.up = 1
    elseif target_row > game_context.menu_y then keys.down = 1
    elseif target_column < game_context.menu_x then keys.left = 1
    elseif target_column > game_context.menu_x then keys.right = 1
    else keys.A = 1
    end
  elseif game_context.cursor_location == 0 then
    -- select the character and queue the spell
    if game_context.target_character > target_character then keys.up = 1
    elseif game_context.target_character < target_character then keys.down = 1
    else
      keys.A = 1
    end
  end
end

local function castBlackMagic(game_context, keys, spell_index, target_enemy, target_character)
  if cursorisinbattlemenu(game_context, game_context.active_character) and not game_context.is_magic_menu_open then
    -- select 'magic' menu item
    if game_context.menu_y == 0 then keys.down = 1
    elseif game_context.menu_y == 1 then keys.down = 1
    elseif game_context.menu_y == 2 then keys.A = 1
    elseif game_context.menu_y == 3 then keys.up = 1
    end
  elseif cursorisinbattlemenu(game_context, game_context.active_character) and game_context.is_magic_menu_open then
    -- select the spell to cast
    local target_row = math.floor(spell_index / 4)
    local target_column = math.fmod(spell_index, 4)
    
    if target_row < game_context.menu_y then keys.up = 1
    elseif target_row > game_context.menu_y then keys.down = 1
    elseif target_column < game_context.menu_x then keys.left = 1
    elseif target_column > game_context.menu_x then keys.right = 1
    else keys.A = 1
    end
  elseif game_context.cursor_location == 255 then
    if target_enemy ~= nil then
      -- select the enemy and queue the spell
      if game_context.target_enemy > target_enemy then keys.up = 1
      elseif game_context.target_enemy < target_enemy then keys.down = 1
      else
        keys.A = 1
      end
    else
      -- no target enemy, move over to select a character
      keys.right = 1
    end
  elseif game_context.cursor_location == 0 then
    if target_character ~= nil then
      -- select the enemy and queue the spell
      if game_context.target_character > target_character then keys.up = 1
      elseif game_context.target_character < target_character then keys.down = 1
      else
        keys.A = 1
      end
    else
      -- no target character, move over to select an enemy
      keys.left = 1
    end
  end
end

function completeTurnWithMinimalImpact(game_context, bot_context, keys)
  -- try to cast some white magic to avoid killing any enemies
  local character = game_context.characters[game_context.active_character]
  local did_cast_spell = false
  
  -- cast on character 4 if we aren't HP-capped so it won't mess with our HP leveling
  local target_character = 3
  if bot_context.hp_to_level == nil then
    -- otherwise pick a random character
    target_character = math.random(0, 3)
  else
    -- if we're leveling character 4's HP, pick someone else to cast on
    if config.LEVEL_CHARACTER_4 and bot_context.hp_to_level.character_index == 3 then
      target_character = math.random(0, 2)
    end
  end
  
  if character.status == 0 and character.magic.current_mp >= config.MP_FLOOR then
    local esuna_spell_index = getspellindex(game_context.active_character, SPELL_ESUNA)
    local cure_spell_index = getspellindex(game_context.active_character, SPELL_CURE)
    if esuna_spell_index ~= nil then
      -- always cast esuna on the character who needs hp leveling
      if bot_context.hp_to_level ~= nil then
        target_character = bot_context.hp_to_level.character_index
      end
      castwhitemagic(game_context, keys, esuna_spell_index, target_character)
      did_cast_spell = true
    elseif cure_spell_index ~= nil then
      castwhitemagic(game_context, keys, cure_spell_index, target_character)
      did_cast_spell = true
    end
  end
  
  if not did_cast_spell then
    -- auto attack
    keys.A = 1
  end  
end

-- base state class
State = {}

function State:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function State:getPriority()
  return -1
end

function State:needToRun(game_context, bot_context)
  return false
end

function State:getText(game_context, bot_context)
  return ""
end

function State:run(game_context, bot_context)
end

-- idle
IdleState = State:new()

function IdleState:getPriority()
  return 0
end

function IdleState:needToRun(game_context, bot_context)
  return true
end

function IdleState:getText(game_context, bot_context)
  return "idle"
end

function IdleState:run(game_context, bot_context)
end

-- find a battle
FindBattleState = State:new()

function FindBattleState:getPriority()
  return 1
end

function FindBattleState:needToRun(game_context, bot_context)
  if game_context.is_in_battle then return false end
  
  return bot_context.magic_to_level ~= nil
    or bot_context.hp_to_level ~= nil
    or bot_context.has_uncapped_mp
    or bot_context.has_uncapped_gil
end

function FindBattleState:getText(game_context, bot_context)
  return "find battle"
end

function FindBattleState:run(game_context, bot_context)
  local keys = {}
  
  if bot_context.mysidia_steps_outside == nil then
    bot_context.mysidia_steps_outside = {}
    bot_context.mysidia_steps_outside[0] = { x = 23, y = 17, completed = false }
    bot_context.mysidia_steps_outside[1] = { x = 30, y = 17, completed = false }
  end
  
  if game_context.is_in_town and game_context.room_number == 43 and not game_context.is_something_happening then
    -- reset paths that brought us to the inn
    bot_context.overworld_steps_to_inn = nil
    bot_context.town_steps_to_inn = nil
    bot_context.inn_steps_to_innkeeper = nil

    -- dismiss the inn dialog
    if bot_context.dismissing_inn_dialog then 
      bot_context.dismissing_inn_dialog = false
    else
      bot_context.dismissing_inn_dialog = true
      keys.A = 1
    end
  elseif game_context.is_in_town and game_context.room_number == 11 and not game_context.is_something_happening then -- Mysidia
    for i = 0,1 do
      local outside_step = bot_context.mysidia_steps_outside[i]
      if outside_step ~= nil and outside_step.completed == false then
        if game_context.indoor_y < outside_step.y then keys.down = 1
        elseif game_context.indoor_y > outside_step.y then keys.up = 1
        elseif game_context.indoor_x < outside_step.x then keys.right = 1
        elseif game_context.indoor_x > outside_step.x then keys.left = 1
        else outside_step.completed = true
        end
        
        break
      end
    end
  else
    -- if we just came out of town, move down to where we can go left/right and battle without walking into town
    if game_context.overworld_y < 112 then
      keys.down = 1
    elseif game_context.overworld_y > 155 then
      keys.up = 1
    else
      -- if we didn't move anywhere, stop moving this direction and head the other direction
      if game_context.overworld_x == bot_context.previous_overworld_x then
        if bot_context.is_headed_left then
          keys.left = nil
        else
          keys.right = nil
        end
        
        bot_context.is_headed_left = not bot_context.is_headed_left
      end
  
      -- move left or right    
      if bot_context.is_headed_left then
        keys.left = 1
      else
        keys.right = 1
      end
    end
    
    -- store our current location for checking the next time through
    bot_context.previous_overworld_x = game_context.overworld_x
  end
  
  joypad.set(1, keys)  
end

-- win a battle
WinBattleState = State:new()

function WinBattleState:getPriority()
  return 3
end

function WinBattleState:needToRun(game_context, bot_context)
  if not game_context.is_in_battle then return false end
  
  --FCEU.print("reload count: " .. bot_context.reload_count)
  
  return bot_context.has_battle_capped_spell
    or bot_context.has_low_mp
    or bot_context.has_uncapped_gil
end

function WinBattleState:getText(game_context, bot_context)
  return "win battle"
end

function WinBattleState:run(game_context, bot_context)
  local keys = {}
  
  if game_context.overworld_x == 2 then
    if not bot_context.is_save_required then
      -- if we have a save queued, undo the last action
      keys.B = 1
      bot_context.is_save_required = true
    else
      -- find all enemies that are alive, and mod to distribute attacks
      -- this feels more complicated than it should be
      local max_living_enemy_index = 0
      for enemy_index = 0,7 do
        if game_context.battle.enemies[enemy_index].is_alive then
          max_living_enemy_index = enemy_index
        end
      end
      
      local living_enemies = {}
      
      local start_index
      if math.fmod(max_living_enemy_index, 2) == 0 then
        start_index = math.max(max_living_enemy_index - 2, 0) -- odd because we index at 0 (6 is really 7)
      else
        start_index = math.max(max_living_enemy_index - 3, 0)
      end
      
      local enemy_count = 0
      for enemy_index = start_index,7 do
        if game_context.battle.enemies[enemy_index].is_alive then
          living_enemies[enemy_count] = enemy_index
          enemy_count = enemy_count + 1
        end
      end
      
      local living_enemy_index = living_enemies[math.fmod(game_context.active_character, enemy_count)]
      
      local character = game_context.characters[game_context.active_character]
      local fire_spell_index = getspellindex(game_context.active_character, SPELL_FIRE)
      local lightning_spell_index = getspellindex(game_context.active_character, SPELL_LIGHTNING)
      if game_context.battle.enemies[living_enemy_index].weak_against_fire and fire_spell_index ~= nil and character.magic.current_mp > config.MP_FLOOR then
        castBlackMagic(game_context, keys, fire_spell_index, living_enemy_index, nil)
      elseif game_context.battle.enemies[living_enemy_index].weak_against_lightning and lightning_spell_index ~= nil and character.magic.current_mp > config.MP_FLOOR then
        castBlackMagic(game_context, keys, lightning_spell_index, living_enemy_index, nil)
      else
        fightEnemy(game_context, keys, living_enemy_index)
      end
    end
  end
  
  joypad.set(1, keys)
end

DismissTreasureState = State:new()

function DismissTreasureState:getPriority()
  return 9
end

function DismissTreasureState:needToRun(game_context, bot_context)
  return game_context.is_treasure_menu_open
end

function DismissTreasureState:getText(game_context, bot_context)
  return "dismiss treasure"
end

function DismissTreasureState:run(game_context, bot_context)
  local keys = {}
  
  if game_context.treasure_x > 0 then keys.left = 1 -- may not be needed
  elseif game_context.treasure_y < 9 then keys.B = 1 -- cancel out to select "exit"
  else keys.A = 1 -- confirm "exit"
  end
  
  joypad.set(1, keys)
end

SaveGameState = State:new()

function SaveGameState:getPriority()
  -- high priority
  return 1000
end

function SaveGameState:needToRun(game_context, bot_context)
  -- only save in the overworld
  return bot_context.is_save_required and game_context.is_in_overworld
end

function SaveGameState:getText(game_context, bot_context)
  return "save"
end

function SaveGameState:run(game_context, bot_context)
  -- save the state (not accessible outside of a single instance of this bot)
  savestate.save(bot_context.save_state)
  --FCEU.print("saving")  
  
  -- mark the save as completed
  bot_context.is_save_required = false
end

ReloadGameState = State:new()

function ReloadGameState:getPriority()
  -- higher priority
  return 1001
end

function ReloadGameState:needToRun(game_context, bot_context)
  -- TODO: reload when someone is stoned? will be easier than casting esuna as a quick fix
  for character_index = 0,3 do
    local character = game_context.characters[character_index]
    
    if character.health.current_hp == 0 then
      return true
    end
  end

  return false
end

function ReloadGameState:getText(game_context, bot_context)
  return "reload"
end

function ReloadGameState:run(game_context, bot_context)
  -- reload the state (only works if we saved at least once during this instance)
  savestate.load(bot_context.save_state)
  
  bot_context.reload_count = bot_context.reload_count + 1
end

UseMysidiaInnState = State:new()

function UseMysidiaInnState:getPriority()
  return 2
end

function UseMysidiaInnState:needToRun(game_context, bot_context)
  local characters_to_level = 3
  if config.LEVEL_CHARACTER_4 then characters_to_level = 4 end
  
  local has_any_low_hp_characters = bot_context.low_hp_characters > 0
  local has_max_low_hp_characters = bot_context.low_hp_characters + bot_context.capped_hp_characters == characters_to_level 

  return config.USE_INN
    and config.INN == "Mysidia"
    and not game_context.is_in_battle
    and (bot_context.has_low_mp or (has_any_low_hp_characters and has_max_low_hp_characters))
end

function UseMysidiaInnState:getText(game_context, bot_context)
  return "use [mysidia] inn"
end

-- TODO: learn something about pathing so this isn't hardcoded
function UseMysidiaInnState:run(game_context, bot_context)
  local keys = {}
  
  -- if we don't have any steps, this must be the first time here for this state,
  -- so let's fill the steps
  if bot_context.overworld_steps_to_inn == nil then
    bot_context.overworld_steps_to_inn = {}
    bot_context.overworld_steps_to_inn[0] = { x = 34, y = 155, completed = false }
    bot_context.overworld_steps_to_inn[1] = { x = 34, y = 160, completed = false }
  end
  
  if bot_context.town_steps_to_inn == nil then
    bot_context.town_steps_to_inn = {}
    bot_context.town_steps_to_inn[0] = { x = 15, y = 13, completed = false }
    bot_context.town_steps_to_inn[1] = { x = 23, y = 13, completed = false }
    bot_context.town_steps_to_inn[2] = { x = 23, y = 9, completed = false }
  end
  
  if bot_context.inn_steps_to_innkeeper == nil then
    bot_context.inn_steps_to_innkeeper = {}
    bot_context.inn_steps_to_innkeeper[0] = { x = 16, y = 26, completed = false }
    bot_context.inn_steps_to_innkeeper[1] = { x = 16, y = 23, completed = false }
  end

  if game_context.is_in_overworld and not game_context.is_something_happening then
    for i = 0,1 do
      local overworld_inn_step = bot_context.overworld_steps_to_inn[i]
      if overworld_inn_step ~= nil and overworld_inn_step.completed == false then
        if game_context.overworld_y < overworld_inn_step.y then keys.down = 1
        elseif game_context.overworld_y > overworld_inn_step.y then keys.up = 1
        elseif game_context.overworld_x < overworld_inn_step.x then keys.right = 1
        elseif game_context.overworld_x > overworld_inn_step.x then keys.left = 1
        else overworld_inn_step.completed = true
        end
        
        break
      end
    end
  end
    
  if game_context.is_in_town and (game_context.room_number == 5 or game_context.room_number == 11) and not game_context.is_something_happening then
    for i = 0,2 do
      local town_inn_step = bot_context.town_steps_to_inn[i]
      if town_inn_step ~= nil and town_inn_step.completed == false then
        if game_context.indoor_y < town_inn_step.y then keys.down = 1
        elseif game_context.indoor_y > town_inn_step.y then keys.up = 1
        elseif game_context.indoor_x < town_inn_step.x then keys.right = 1
        elseif game_context.indoor_x > town_inn_step.x then keys.left = 1
        else town_inn_step.completed = true
        end
        
        break
      end
    end
  end  

  if game_context.is_in_town and game_context.room_number == 43 and not game_context.is_something_happening then
    for i = 0,1 do
      local inn_innkeeper_step = bot_context.inn_steps_to_innkeeper[i]
      if inn_innkeeper_step ~= nil and inn_innkeeper_step.completed == false then
        if game_context.indoor_y < inn_innkeeper_step.y then keys.down = 1
        elseif game_context.indoor_y > inn_innkeeper_step.y then keys.up = 1
        elseif game_context.indoor_x < inn_innkeeper_step.x then keys.right = 1
        elseif game_context.indoor_x > inn_innkeeper_step.x then keys.left = 1
        else inn_innkeeper_step.completed = true
        end
        
        break
      end
    end
    
    if bot_context.inn_steps_to_innkeeper[1].completed then
      -- forcibly press the 'A' key
      -- not sure why 'keys.A = 1' doesn't work here
      memory.writebyte(0x0024, 0x01)

      -- reset the steps that will be required to get out of town      
      bot_context.mysidia_steps_outside = nil
    end
  end
    
  joypad.set(1, keys)
end

LevelSpellState = State:new()

function LevelSpellState:getPriority()
  return 7
end

function LevelSpellState:needToRun(game_context, bot_context)
  return bot_context.magic_to_level ~= nil and game_context.is_in_battle
end

function LevelSpellState:getText(game_context, bot_context)
  return "level magic c" .. bot_context.magic_to_level.character_index
    .. " s" .. bot_context.magic_to_level.spell_index
    .. " " .. bot_context.magic_to_level.spell_level
    .. "-" .. string.format("%02d", bot_context.magic_to_level.spell_skill)
    .. "+" .. string.format("%02d", bot_context.magic_to_level.spell_skill_queue)
end

function LevelSpellState:run(game_context, bot_context)
  if game_context.overworld_x ~= 2 then return end
  
  local keys = {}
  
  if game_context.active_character > bot_context.magic_to_level.character_index then
    -- cancel actions to select character
    keys.B = 1
  elseif game_context.active_character < bot_context.magic_to_level.character_index then
    -- auto attack to select character
    keys.A = 1
  elseif cursorisinbattlemenu(game_context, bot_context.magic_to_level.character_index) and not game_context.is_magic_menu_open then
    -- select 'magic' menu item
    if game_context.menu_y == 0 then keys.down = 1
    elseif game_context.menu_y == 1 then keys.down = 1
    elseif game_context.menu_y == 2 then keys.A = 1
    elseif game_context.menu_y == 3 then keys.up = 1
    end
  elseif cursorisinbattlemenu(game_context, bot_context.magic_to_level.character_index) and game_context.is_magic_menu_open then
    -- select the spell to level
    local target_row = math.floor(bot_context.magic_to_level.spell_index / 4)
    local target_column = math.fmod(bot_context.magic_to_level.spell_index, 4)
    
    if target_row < game_context.menu_y then keys.up = 1
    elseif target_row > game_context.menu_y then keys.down = 1
    elseif target_column < game_context.menu_x then keys.left = 1
    elseif target_column > game_context.menu_x then keys.right = 1
    else keys.A = 1
    end
  elseif game_context.cursor_location == 0 then
    -- select all characters and queue the spell
    if config.LEVEL_SPELL_MULTICAST and game_context.target_character ~= 132 then keys.up = 1
    else keys.A = 1
    end
  elseif game_context.cursor_location == 255 then
    -- select all enemies and queue the spell
    if config.LEVEL_SPELL_MULTICAST and game_context.target_enemy ~= 136 then keys.up = 1
    else keys.A = 1
    end
  end
  
  joypad.set(1, keys)
end

LevelHPState = State:new()

function LevelHPState:getPriority()
  return 6
end

function LevelHPState:needToRun(game_context, bot_context)
  return bot_context.hp_to_level ~= nil
    and not bot_context.hp_to_level.will_level
    and game_context.is_in_battle
end

function LevelHPState:getText(game_context, bot_context)
  return "level hp c" .. bot_context.hp_to_level.character_index
    .. " by c" .. bot_context.hp_to_level.attacking_character_index
end

function LevelHPState:run(game_context, bot_context)
  if game_context.overworld_x == 2 then
    local keys = {}
    
    -- if we're supposed to attack, attack
    if game_context.active_character == bot_context.hp_to_level.attacking_character_index then
      local fire_spell_index = getspellindex(game_context.active_character, SPELL_FIRE)
      local character = game_context.characters[game_context.active_character]
      if config.LEVEL_BY_FIRE and fire_spell_index ~= nil and character.magic.current_mp > config.MP_FLOOR then
        castBlackMagic(game_context, keys, fire_spell_index, nil, bot_context.hp_to_level.character_index)
      else
        fightcharacter(game_context, keys, bot_context.hp_to_level.character_index)
      end
    else
      local living_enemy_count = 0
      for enemy_index = 0,7 do
        if game_context.battle.enemies[enemy_index].is_alive then
          living_enemy_count = living_enemy_count + 1
        end
      end

      -- if we have a bunch of enemies left, kill some
      if living_enemy_count > 1 then
        keys.A = 1
      else
        completeTurnWithMinimalImpact(game_context, bot_context, keys)
      end
    end
    
    joypad.set(1, keys)
  end  
end

LevelMPState = State:new()

function LevelMPState:getPriority()
  return 5
end

function LevelMPState:needToRun(game_context, bot_context)
  return game_context.is_in_battle and bot_context.has_uncapped_mp
end

function LevelMPState:getText(game_context, bot_context)
  return "level mp"
end

function LevelMPState:run(game_context, bot_context)
  if game_context.overworld_x == 2 then
    local keys = {}
    
    -- try to cast some white magic to spend MP (might as well level that too)
    -- ALWAYS cast on character 4 so it won't mess with our HP leveling
    local white_magic = { [0] = SPELL_ESUNA, SPELL_CURE }
    local did_cast_spell = false
    local character = game_context.characters[game_context.active_character]
    if character.magic.current_mp > config.MP_FLOOR then     
      for i, spell_id in pairs(white_magic) do
        local spell_index = getspellindex(game_context.active_character, spell_id)
        if spell_index ~= nil then
          castwhitemagic(game_context, keys, spell_index, 3)
          did_cast_spell = true
          break
        end
      end
    end
    
    if not did_cast_spell then
      FCEU.print("no magic to cast for character " .. game_context.active_character)
      -- auto attack
      keys.A = 1
    end
    
    joypad.set(1, keys)
  end
end

HealCharacterState = State:new()

function HealCharacterState:getPriority()
  return 8
end

function HealCharacterState:needToRun(game_context, bot_context)
  return game_context.is_in_battle
    and (bot_context.hp_to_level == nil or not bot_context.hp_to_level.will_level)
    and bot_context.low_hp_characters > 0
end

function HealCharacterState:getText(game_context, bot_context)
  return "heal character"
end

function HealCharacterState:run(game_context, bot_context)
  local keys = {}
  
  -- find low hp character
  local low_hp_character_index
  for character_index = 0,3 do
    local character = game_context.characters[character_index]
    
    if character.health.current_hp / character.health.max_hp <= config.HP_FLOOR_PCT then
      low_hp_character_index = character_index
    end
  end
  
  if low_hp_character_index == nil then return end
    
  -- find first character with CURE
  local heal_character_index
  local cure_spell_index
  for character_index = 0,3 do
    cure_spell_index = getspellindex(character_index, SPELL_CURE)
    if cure_spell_index ~= nil then
      heal_character_index = character_index
      break
    end
  end
  
  if heal_character_index == nil then return end
  
  if not bot_context.is_heal_queued then
    if game_context.active_character > heal_character_index then
      -- cancel actions to get to character who will cast HEAL
      keys.B = 1
    elseif game_context.active_character < heal_character_index then
      completeTurnWithMinimalImpact(game_context, bot_context, keys)
    else
      castwhitemagic(game_context, keys, cure_spell_index, low_hp_character_index)
      bot_context.is_heal_queued = true
    end
  else
    if game_context.active_character ~= heal_character_index then
      completeTurnWithMinimalImpact(game_context, bot_context, keys)
    else
      castwhitemagic(game_context, keys, cure_spell_index, low_hp_character_index)
    end    
  end
  
  joypad.set(1, keys)
end

EsunaCharacterState = State:new()

function EsunaCharacterState:getPriority()
  return 8
end

function EsunaCharacterState:needToRun(game_context, bot_context)
  if not game_context.is_in_battle then return false end
  
  for character_index = 0,3 do
    if game_context.characters[character_index].status ~= 0 and game_context.characters[character_index].status ~= 512 then
      return true
    end
  end
  
  bot_context.is_esuna_queued = false
  return false
end

function EsunaCharacterState:getText(game_context, bot_context)
  return "esuna character"
end

function EsunaCharacterState:run(game_context, bot_context)
  local keys = {}
  
  -- find abnormal status hp character
  local abnormal_status_character_index
  for character_index = 0,3 do
    if game_context.characters[character_index].status ~= 0 then
      abnormal_status_character_index = character_index
      break
    end
  end

  if abnormal_status_character_index == nil then return end
    
  -- find first character with ESUNA
  local esuna_character_index
  local esuna_spell_index
  for character_index = 0,3 do
    esuna_spell_index = getspellindex(character_index, SPELL_ESUNA)
    if game_context.characters[character_index].status == 0 and esuna_spell_index ~= nil then
      esuna_character_index = character_index
      break
    end
  end
  
  if esuna_character_index == nil then return end
  
  if not bot_context.is_esuna_queued then
    if game_context.active_character > esuna_character_index then
      -- cancel actions to get to character who will cast ESUNA
      keys.B = 1
    elseif game_context.active_character < esuna_character_index then
      completeTurnWithMinimalImpact(game_context, bot_context, keys)
    else
      castwhitemagic(game_context, keys, esuna_spell_index, abnormal_status_character_index)
      bot_context.is_esuna_queued = true
    end
  else
    if game_context.active_character ~= esuna_character_index then
      completeTurnWithMinimalImpact(game_context, bot_context, keys)
    else
      castwhitemagic(game_context, keys, esuna_spell_index, abnormal_status_character_index)
    end    
  end
  
  joypad.set(1, keys)
end

local function bitnumer(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

local function hasbit(x, p)
  return x % (p + p) >= p
end

local function getCharacterHP(game_context, character_index)
  local hp = {}
  
  if game_context.is_in_battle then
    hp.current_hp = memory.readword(0x7D84 + (character_index * 0x0030))
    hp.max_hp = memory.readword(0x7D84 + (character_index * 0x0030) + 0x0004)
  else
    hp.current_hp = memory.readword(0x6100 + (character_index * 0x0040) + 0x0008)
    hp.max_hp = memory.readword(0x6100 + (character_index * 0x0040) + 0x000A)
  end
  
  return hp
end

local function getCharacterMP(game_context, character_index)
  local mp = {}
  
  if game_context.is_in_battle then
    mp.current_mp = memory.readword(0x7D86 + (character_index * 0x0030))
    mp.max_mp = memory.readword(0x7D86 + (character_index * 0x0030) + 0x0004)
  else
    mp.current_mp = memory.readword(0x6100 + (character_index * 0x0040) + 0x000C)
    mp.max_mp = memory.readword(0x6100 + (character_index * 0x0040) + 0x000E)
  end
  
  return mp
end

local function getGameContext(game_context)
  game_context.is_in_battle = memory.readbyte(0x002E) == 0xB8
  game_context.room_number = memory.readbyte(0x0048)
  game_context.is_in_town = hasbit(memory.readbyte(0x002D), bitnumer(1))
  game_context.is_in_overworld = not game_context.is_in_town and not game_context.is_in_battle
  game_context.is_something_happening = memory.readbyte(0x0034) ~= 0x00
  game_context.overworld_x = memory.readbyte(0x0027)
  game_context.overworld_y = memory.readbyte(0x0028)
  game_context.indoor_x = memory.readbyte(0x0068)
  game_context.indoor_y = memory.readbyte(0x0069)
  game_context.active_character = memory.readbyte(0x0012)
  game_context.cursor_location = memory.readbyte(0x000B)
  game_context.target_character = memory.readbyte(0x000C)
  game_context.target_enemy = memory.readbyte(0x000D)
  game_context.menu_x = memory.readbyte(0x0053)
  game_context.menu_y = memory.readbyte(0x0054)
  game_context.is_magic_menu_open = memory.readbyte(0x7CBA) == 0x01
  game_context.treasure_x = memory.readbyte(0x0072)
  game_context.treasure_y = memory.readbyte(0x0074)
  game_context.is_treasure_menu_open =  game_context.is_in_battle and memory.readbyte(0x0070) == 40
  game_context.gil = bit.lshift(memory.readbyte(0x601E), 16) + bit.lshift(memory.readbyte(0x601D), 8) + memory.readbyte(0x601C) 
  
  game_context.characters = {}
  
  for character_index = 0,3 do
    local character = {}
    character.health = getCharacterHP(game_context, character_index)
    character.magic = getCharacterMP(game_context, character_index)
    if game_context.is_in_battle then
      character.is_in_front = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0035) == 0x00
    else
      character.is_in_front = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0035) == 0x01
    end
    
    if game_context.is_in_battle then
      character.status = memory.readword(0x7D82 + (character_index * 0x0030))
    else
      character.status = memory.readbyte(0x6100 + (character_index * 0x0040) + 0x0001)
    end
    
    game_context.characters[character_index] = character
  end
  
  game_context.battle = {}
  game_context.battle.living_enemy_count = memory.readbyte(0x7B4D)
  game_context.battle.enemies = {}
  
  for enemy_index = 0,7 do
    local enemy = {}
    enemy.is_alive = memory.readbyte(0x7B62 + enemy_index) ~= 0xFF
    --enemy.can_target = memory.readbyte(0x7E3A + (enemy_index * 0x30) + 0x2A) ~= 0xFF
    local weakness = memory.readbyte(0x7E3A + (enemy_index * 0x30) + 0x16)
    enemy.weak_against_fire = hasbit(weakness, bitnumer(2))
    enemy.weak_against_lightning = hasbit(weakness, bitnumer(4))
    
    game_context.battle.enemies[enemy_index] = enemy
  end
end

-- this function should perform common aggregations on the game_context so they don't have to be
-- recalculated by each state. it should NOT directly indicate which states should run
local function getBotContext(game_context, bot_context)

  -- check for uncapped gil
  bot_context.has_uncapped_gil = game_context.gil < config.TARGET_GIL

  bot_context.magic_to_level = nil
  bot_context.has_uncapped_mp = false
  bot_context.hp_to_level = nil
  bot_context.has_battle_capped_spell = false
  bot_context.has_low_mp = false
  bot_context.low_hp_characters = 0
  bot_context.capped_hp_characters = 0
  
  if bot_context.previously_in_battle == nil then
    bot_context.previously_in_battle = false
  end
  
  if bot_context.reload_count == nil then
    bot_context.reload_count = 0
  end
  
  -- leaving battle
  if not game_context.is_in_battle and bot_context.previously_in_battle then
    bot_context.reload_count = 0
  end
  
  bot_context.previously_in_battle = game_context.is_in_battle
  
  -- loop through all characters
  local max_character = 2
  if config.LEVEL_CHARACTER_4 then max_character = 3 end
  for character_index = 0,max_character do
    local character = game_context.characters[character_index]
    
    -- check for uncapped spells until we find *one* to level
    if bot_context.magic_to_level == nil then
      for spell_index = 0,15 do
        if memory.readbyte(0x6100 + (character_index * 0x0040) + 0x0030 + spell_index) ~= 0x00 then
          local spell_level = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2)) + 1
          local spell_skill = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2) + 1)
          local spell_skill_queue = memory.readbyte(0x7CF7 + (character_index * 0x0010) + spell_index) 
          
          if spell_level < config.TARGET_SPELL_LEVEL and spell_skill_queue == 100 then
            bot_context.has_battle_capped_spell = true
          end
          
          if bot_context.magic_to_level == nil and spell_level < config.TARGET_SPELL_LEVEL and spell_skill_queue < 100 and character.magic.current_mp >= config.MP_FLOOR then
            bot_context.magic_to_level = {}
            bot_context.magic_to_level.character_index = character_index
            bot_context.magic_to_level.spell_index = spell_index
            bot_context.magic_to_level.spell_level = spell_level
            bot_context.magic_to_level.spell_skill = spell_skill
            bot_context.magic_to_level.spell_skill_queue = spell_skill_queue
          end
        end
      end
    end
    
    -- cancel leveling magic if we have a capped spell
    if bot_context.has_battle_capped_spell then
      bot_context.magic_to_level = nil
    end
    
    -- check for capped HP
    if character.health.max_hp >= config.TARGET_HP then
      bot_context.capped_hp_characters = bot_context.capped_hp_characters + 1
    end
    
    -- check for low MP
    if character.magic.current_mp <= config.MP_FLOOR and character.magic.max_mp >= config.MP_FLOOR then
      bot_context.has_low_mp = true
    end

    -- check for uncapped MP
    if character.magic.max_mp < config.TARGET_MP and character.magic.current_mp > config.MP_FLOOR then
      bot_context.has_uncapped_mp = true
    end
    
    -- check for uncapped HP until we find *one* character to level
    if bot_context.hp_to_level == nil then
      if character.health.max_hp < config.TARGET_HP then
        bot_context.hp_to_level = {}
        bot_context.hp_to_level.character_index = character_index
        bot_context.hp_to_level.will_level = character.health.current_hp / character.health.max_hp <= config.HP_FLOOR_PCT
        
        -- if this character is in the back row, they can't melee themselves, so use another character
        -- TODO: improve this logic. defaulting to character 4 for now, who is likely unleveled because they get swapped in/out often
        if not character.is_in_front then
          bot_context.hp_to_level.attacking_character_index = 3
        else
          -- no skill with staves, should do okay damage to themselves
          bot_context.hp_to_level.attacking_character_index = character_index
        end
      end
    end
  end
  
  -- perform some checks on all characters, whether or not we're leveling character 4
  for character_index = 0,3 do
    local character = game_context.characters[character_index]
    
    -- check for low HP
    if character.health.current_hp / character.health.max_hp < config.HP_FLOOR_PCT then
      bot_context.low_hp_characters = bot_context.low_hp_characters + 1
    end
  end
  
  -- reset the "is_heal_queued" flag after we're done healing
  -- TODO: improve this reset logic; we'll probably get stuck if a single CURE
  -- isn't enough to heal above config.HP_FLOOR_PCT
  if bot_context.low_hp_characters == 0 then
    bot_context.is_heal_queued = nil
  end
  
  return bot_context
end

do
  local bot_context = {}
  local game_context = {}
  
  local states = {}
  states[0] = IdleState:new()
  states[1] = FindBattleState:new()
  states[2] = WinBattleState:new()
  states[3] = DismissTreasureState:new()
  states[4] = SaveGameState:new()  
  states[5] = ReloadGameState:new()
  states[6] = UseMysidiaInnState:new()
  states[7] = LevelSpellState:new()
  states[8] = LevelHPState:new()
  states[9] = LevelMPState:new()
  states[10] = HealCharacterState:new()
  states[11] = EsunaCharacterState:new()
  
  bot_context.save_state = savestate.object()
  savestate.save(bot_context.save_state)
  
  if config.USE_TURBO then FCEU.speedmode("turbo") end
  
  local state_to_run = nil
  
  while true do
    getGameContext(game_context)
    getBotContext(game_context, bot_context)

    -- loop through the states in descending priority order to find the appropriate state to run
    for index,state in spairs(states, function(t, a, b) return t[a]:getPriority() > t[b]:getPriority() end) do
      if state:needToRun(game_context, bot_context) then
        gui.text(2, 10, state:getText(game_context, bot_context))

        -- don't do anything if something is already happening (map is scrolling, attack animations are occurring, etc)  
        if not game_context.is_something_happening then
          state:run(game_context, bot_context)
        end
        
        break
      end
    end
  
    FCEU.frameadvance()
  end
end
