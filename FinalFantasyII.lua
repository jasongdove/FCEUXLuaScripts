-- Final Fantasy II Bot
-- Levels all spells on characters 1-3 (not 4) to MAX_SPELL_LEVEL defined below.
-- Fight completion logic is primitive, and bot contains no healing logic at this point,
-- so this is best done in a low-level area.
-- This also works better if character 4 has CURE and is positioned in the front (to allow weapon attacks)

local config = {}
config.TARGET_SPELL_LEVEL = 5
config.TARGET_HP = 9999
config.TARGET_MP = 999
config.USE_TURBO = true
config.HP_FLOOR_PCT = 0.55
config.MP_FLOOR = 16

local SPELL_CURE = 0xD4
local SPELL_ESUNA = 0xD7

local function text(x,y,str)
	if (x > 0 and x < 255 and y > 0 and y < 240) then
		gui.text(x,y,str)
	end
end

local function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

local function hasbit(x, p)
  return x % (p + p) >= p
end

local function getCharacterHP(game_context, character_index)
	hp = {}
	
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
	mp = {}
	
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
	game_context.is_in_town = hasbit(memory.readbyte(0x002D), bit(1))
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

		game_context.characters[character_index] = character
	end
end

-- strafe from left to right until we get attacked
local function findbattle(game_context, bot_context)
	text(2, 10, "find a battle")
	local keys = {}
	
	if bot_context.town_steps_outside == nil then
		bot_context.town_steps_outside = {}
		bot_context.town_steps_outside[0] = { x = 7, y = 19, completed = false }
		bot_context.town_steps_outside[1] = { x = 0, y = 19, completed = false }
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
	elseif game_context.is_in_town and game_context.room_number == 5 and not game_context.is_something_happening then
		for i = 0,1 do
			local town_outside_step = bot_context.town_steps_outside[i]
			if town_outside_step ~= nil and town_outside_step.completed == false then
				if game_context.indoor_y < town_outside_step.y then keys.down = 1
				elseif game_context.indoor_y > town_outside_step.y then keys.up = 1
				elseif game_context.indoor_x < town_outside_step.x then keys.right = 1
				elseif game_context.indoor_x > town_outside_step.x then keys.left = 1
				else town_outside_step.completed = true
				end
				
				break
			end
		end
	elseif not game_context.is_something_happening then
		-- if we just came out of town, move down to where we can go left/right and battle
		if game_context.overworld_y < 112 then
			keys.down = 1
		else
			if game_context.overworld_x == bot_context.previous_overworld_x then
				if bot_context.is_headed_left then
					keys.left = nil
				else
					keys.right = nil
				end
				
				bot_context.is_headed_left = not bot_context.is_headed_left
			end
		
			if bot_context.is_headed_left then
				keys.left = 1
			else
				keys.right = 1
			end
		end
		
		bot_context.previous_overworld_x = game_context.overworld_x
	end

	joypad.set(1, keys)
end

-- auto attack to kill all enemies (could be grealy improved; need to find enemy state in RAM)
local function winbattle(game_context, bot_context)
	text(2, 10, "win a battle")
	local keys = {}
	
	if not game_context.is_something_happening and game_context.overworld_x == 2 then
		if not bot_context.is_save_required then
			-- if we have a save queued, undo the last action
			keys.B = 1
			bot_context.is_save_required = true
		else
			-- auto attack
			keys.A = 1
		end
		
		joypad.set(1, keys)
	end
end

-- save the game
local function savegame(game_context, bot_context)
	text(2, 10, "saving...")
	
	if not game_context.is_something_happening then
		savestate.save(bot_context.save_state)
		
		bot_context.is_save_required = false
	end
end

-- reload the game
local function reloadgame(game_context, bot_context)
	text(2, 10, "reloading...")
	FCEU.print("oops, reloading")
	
	if not game_context.is_something_happening then
		savestate.load(bot_context.save_state)
		
		bot_context.should_reload = false
	end
end

local function useinn(game_context, bot_context)
	text(2, 10, "resting...")
	local keys = {}
	
	-- TODO: learn something about pathing so this isn't hardcoded
	if bot_context.overworld_steps_to_inn == nil then
		bot_context.overworld_steps_to_inn = {}
		bot_context.overworld_steps_to_inn[0] = { x = 84, y = 112, completed = false }
		bot_context.overworld_steps_to_inn[1] = { x = 84, y = 108, completed = false }
	end
	
	if bot_context.town_steps_to_inn == nil then
		bot_context.town_steps_to_inn = {}
		bot_context.town_steps_to_inn[0] = { x = 7, y = 19, completed = false }
		bot_context.town_steps_to_inn[1] = { x = 7, y = 13, completed = false }
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
		
	if game_context.is_in_town and game_context.room_number == 5 and not game_context.is_something_happening then
		for i = 0,1 do
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
			memory.writebyte(0x0024, 0x01)
		end
	end
		
	joypad.set(1, keys)
end

local function getBotContext(game_context, bot_context)
	bot_context.magic_to_level = nil
	bot_context.should_level_mp = false
	bot_context.hp_to_level = nil
	bot_context.should_finish_battle = false
	bot_context.should_use_inn = false
	bot_context.should_reload = false

	-- check for dead characters, and reload if any are found	
	for character_index = 0,3 do
		local character = game_context.characters[character_index]
		
		if character.health.current_hp == 0 then
			bot_context.should_reload = true
			break
		end
	end
	
	-- if we're currently in a battle, check for conditions that require a save
	if game_context.is_in_battle then
	
		-- if we're entering a battle, store some info
		if bot_context.previously_in_battle == nil or not bot_context.previously_in_battle then
			bot_context.battle = {}
			bot_context.battle.character_started_low = {}
			
			for character_index = 0,2 do
				local character = game_context.characters[character_index]
				bot_context.battle.character_started_low[character_index] = character.health.current_hp / character.health.max_hp <= config.HP_FLOOR_PCT 
			end
		end
		
		-- check for capped spell levels
		for character_index = 0,2 do
			for spell_index = 0,15 do
				if memory.readbyte(0x6100 + (character_index * 0x0040) + 0x0030 + spell_index) ~= 0x00 then
					local spell_level = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2)) + 1
					local spell_skill = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2) + 1)
					local spell_skill_queue = memory.readbyte(0x7CF7 + (character_index * 0x0010) + spell_index) 
					
					if spell_level < config.TARGET_SPELL_LEVEL and spell_skill + spell_skill_queue == 100 then
						bot_context.should_finish_battle = true
						break
					end
				end
			end
			
			if bot_context.should_finish_battle then break end
		end
		
		-- check for low hp
		local low_hp_characters = 0
		local max_hp_characters = 0
		local max_mp_characters = 0
		for character_index = 0,2 do
			local character = game_context.characters[character_index]
			
			if character.health.current_hp / character.health.max_hp <= config.HP_FLOOR_PCT then
				low_hp_characters = low_hp_characters + 1
			end
			
			if character.health.max_hp >= config.TARGET_HP then
				max_hp_characters = max_hp_characters + 1
			end

			if character_index < 3 and character.magic.max_mp >= config.TARGET_MP then
				max_mp_characters = max_mp_characters + 1
			end
		end
		
		if low_hp_characters > 0 and low_hp_characters + max_hp_characters >= 3 then
			-- if we're here, but we have a bunch of HP (say over 1000), then let's spam spells to level MP
			for character_index = 0,3 do
				local character = game_context.characters[character_index]
				
				if (character_index < 3 and character.health.current_hp < 1000) or character.magic.current_mp < config.MP_FLOOR then
					bot_context.should_finish_battle = true
				end
			end
			
			-- if we have maxed mp, forget spamming spells
			if max_mp_characters == 3 then
				bot_context.should_finish_battle = true
			end
			
			if not bot_context.should_finish_battle then bot_context.should_level_mp = true end
		end
		
		-- if we're here, but we have a bunch of HP (say over 1000), then let's spam spells to level MP
		bot_context.should_level_mp = true
		for character_index = 0,3 do
			local character = game_context.characters[character_index]
			
			if (character_index < 3 and character.health.current_hp < 1000) or character.magic.current_mp < config.MP_FLOOR then
				bot_context.should_level_mp = false
			end
		end
		
		if max_mp_characters == 3 then
			bot_context.should_level_mp = false
		end
		
		if bot_context.should_level_mp then
			bot_context.should_finish_battle = false
		end

	end

	bot_context.previously_in_battle = game_context.is_in_battle

	-- finishing the battle is the top priority, so skip other checks if that needs to happen
	if not bot_context.should_finish_battle then
	
		-- check if we need to rest
		local low_hp_characters = 0
		local low_mp_characters = 0
		local max_hp_characters = 0
		for character_index = 0,3 do
			local character = game_context.characters[character_index]

			-- don't care about character 3's HP
			if character_index < 3 then
				if character.health.current_hp / character.health.max_hp <= config.HP_FLOOR_PCT then
					low_hp_characters = low_hp_characters + 1
				end
			
				if character.health.max_hp >= config.TARGET_HP then
					max_hp_characters = max_hp_characters + 1
				end
			end
			
			if character.magic.current_mp <= config.MP_FLOOR then
				low_mp_characters = low_mp_characters + 1
			end
		end
		if (low_hp_characters > 0 and low_hp_characters + max_hp_characters >= 3) or low_mp_characters > 0 then
			bot_context.should_use_inn = true
		end
	
		-- check for uncapped spells
		for character_index = 0,2 do
			for spell_index = 0,15 do
				if memory.readbyte(0x6100 + (character_index * 0x0040) + 0x0030 + spell_index) ~= 0x00 then
					local spell_level = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2)) + 1
					local spell_skill = memory.readbyte(0x6200 + (character_index * 0x0040) + 0x0010 + (spell_index * 2) + 1)
					local spell_skill_queue = memory.readbyte(0x7CF7 + (character_index * 0x0010) + spell_index) 
					
					if spell_level < config.TARGET_SPELL_LEVEL and spell_skill + spell_skill_queue < 100 then
						bot_context.magic_to_level = {}
						bot_context.magic_to_level.character_index = character_index
						bot_context.magic_to_level.spell_index = spell_index
						bot_context.magic_to_level.spell_level = spell_level
						bot_context.magic_to_level.spell_skill = spell_skill
						bot_context.magic_to_level.spell_skill_queue = spell_skill_queue
						break
					end
				end
			end
			
			if bot_context.magic_to_level ~= nil then break end
		end
		
		-- check for uncapped hp
		for character_index = 0,2 do
			local character = game_context.characters[character_index]
			
			if character.health.current_hp / character.health.max_hp >= config.HP_FLOOR_PCT and character.health.max_hp < config.TARGET_HP then
				bot_context.hp_to_level = {}
				bot_context.hp_to_level.character_index = character_index
				
				-- if this character is in the back row, they can't melee themselves, so use another character
				-- TODO: improve this logic. defaulting to character 4 for now, who is likely unleveled because they get swapped in/out often
				if not character.is_in_front then
					bot_context.hp_to_level.attacking_character_index = 3
				else
					-- no skill with staves, should do okay damage to themselves
					bot_context.hp_to_level.attacking_character_index = character_index
				end
				
				break
			end
		end
		
		-- check for uncapped mp
		for character_index = 0,2 do
			local character = game_context.characters[character_index]
			
			if character.magic.max_mp < config.TARGET_MP then
				bot_context.should_level_mp = true
				break
			end
		end
	end
	
	return bot_context
end

local function cursorisinbattlemenu(game_context, character_index)
	if character_index == 0 then return game_context.cursor_location == 1 or game_context.cursor_location == 33
	elseif character_index == 1 then return game_context.cursor_location == 9 or game_context.cursor_location == 39
	elseif character_index == 2 then return game_context.cursor_location == 17 or game_context.cursor_location == 45
	elseif character_index == 3 then return game_context.cursor_location == 25 -- TODO: find other number when character has LOW hp
	else return false
	end
end

-- level a spell by queueing and backing out over and over, without actually casting anything
local function levelmagic(game_context, bot_context)
	text(2, 10, "level magic c" .. bot_context.magic_to_level.character_index .. " s" .. bot_context.magic_to_level.spell_index .. " " .. bot_context.magic_to_level.spell_level .. "-" .. string.format("%02d", bot_context.magic_to_level.spell_skill) .. "+" .. string.format("%02d", bot_context.magic_to_level.spell_skill_queue))

	if not game_context.is_something_happening and game_context.overworld_x == 2 then
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
			if game_context.target_character ~= 132 then keys.up = 1
			else keys.A = 1
			end
		elseif game_context.cursor_location == 255 then
			-- select all enemies and queue the spell
			if game_context.target_enemy ~= 136 then keys.up = 1
			else keys.A = 1
			end
		end
		
		joypad.set(1, keys)
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
		-- select the spell to level
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

-- level a character's hp by auto attacking (low hp at the end of a battle will raise max hp)
local function levelhp(game_context, bot_context)
	text(2, 10, "level hp c" .. bot_context.hp_to_level.character_index .. " by c" .. bot_context.hp_to_level.attacking_character_index)
	
	if not game_context.is_something_happening and game_context.overworld_x == 2 then
		local keys = {}
		
		-- if we're supposed to attack, attack
		if game_context.active_character == bot_context.hp_to_level.attacking_character_index then
			fightcharacter(game_context, keys, bot_context.hp_to_level.character_index)
		else
			-- try to cast some white magic to spend MP (might as well level that too)
			-- ALWAYS cast on character 4 so it won't mess with our HP leveling
			-- TODO: check that we have enough MP
			local character = game_context.characters[game_context.active_character]
			local white_magic = { [0] = SPELL_ESUNA, SPELL_CURE }
			local did_cast_spell = false
			
			if character.magic.current_mp >= config.MP_FLOOR then
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
				FCEU.print("no magic/mp to cast for character " .. game_context.active_character)
				-- auto attack
				keys.A = 1
			end
		end
		
		joypad.set(1, keys)
	end
end

-- level a character's mp by casting white magic
local function levelmp(game_context, bot_context)
	text(2, 10, "level mp")
	
	if not game_context.is_something_happening and game_context.overworld_x == 2 then
		local keys = {}
		
		-- try to cast some white magic to spend MP (might as well level that too)
		-- ALWAYS cast on character 4 so it won't mess with our HP leveling
		-- TODO: check that we have enough MP
		local white_magic = { [0] = SPELL_ESUNA, SPELL_CURE }
		local did_cast_spell = false
		for i, spell_id in pairs(white_magic) do
			local spell_index = getspellindex(game_context.active_character, spell_id)
			if spell_index ~= nil then
				castwhitemagic(game_context, keys, spell_index, 3)
				did_cast_spell = true
				break
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

do
	local bot_context = {}
	local game_context = {}
	
	bot_context.save_state = savestate.object()
	savestate.save(bot_context.save_state)
	
	if config.USE_TURBO then FCEU.speedmode("turbo") end
	
	while true do
		getGameContext(game_context)
		getBotContext(game_context, bot_context)
	
		if bot_context.should_reload then
			reloadgame(game_context, bot_context)
		elseif game_context.is_in_overworld and bot_context.is_save_required then
			savegame(game_context, bot_context)
		elseif not game_context.is_in_battle and bot_context.should_use_inn then
			useinn(game_context, bot_context)
		elseif not game_context.is_in_battle and (bot_context.magic_to_level ~= nil or bot_context.hp_to_level ~= nil or bot_context.should_level_mp) then
			findbattle(game_context, bot_context)
		elseif game_context.is_in_battle and bot_context.should_finish_battle then
			winbattle(game_context, bot_context)
		elseif game_context.is_in_battle and bot_context.magic_to_level ~= nil then
			levelmagic(game_context, bot_context)
		elseif game_context.is_in_battle and bot_context.hp_to_level ~= nil then
			levelhp(game_context, bot_context)
		elseif game_context.is_in_battle and bot_context.should_level_mp then
			levelmp(game_context, bot_context)
		else
			text(2, 10, "nothing to do...")
		end
		
		FCEU.frameadvance()
	end
end
