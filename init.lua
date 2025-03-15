local C = core.colorize
local F = core.formspec_escape
local SER = core.serialize

-- Minetest Client-Side-Mod by SwissalpS
-- Modular rearangeable manager for a single
-- text based HUD element.
-- Allows you to easily order and select only
-- the information you want. Then at runtime
-- you can blend, the loaded modules, in or out of the HUD
-- by invoking a formspec with .tmi command.
tmi = {
	version = 20240719.1331,
}
-- some values for users to configure
tmi.conf = {
	-- seconds between updates
	interval = 0.5,
	-- how many characters to show per vector
	precision = 4,
	-- rrggbb colour of text
	colour = 0xfffddc,
}

-- don't modify this, holds the HUD-ID when initialized
tmi.hudID = nil
tmi.formname = '__TMI_form__'
-- table to hold module definitions
tmi.modules = {}
-- tabel to look-up index for an module id
tmi.moduleLookup = {}
-- make sure modules can access datastore from get-go
tmi.store = assert(core.get_mod_storage())

-- this is too early, we do it in tmi.init()
--tmi.player = assert(core.localplayer)

-- make sure path is ok
local modname = assert(core.get_current_modname())
tmi.pathMod = assert(core.get_modpath(modname))
-- load 'API' functions
dofile(tmi.pathMod .. 'functions.lua')
local p = tmi.pathMod .. 'module_'

-----------------------------------------------------
-- comment out modules you don't want and reorder  --
-- first loaded go on top in HUD and others bellow --
-----------------------------------------------------
--dofile(p .. 'debugChannel.lua') -- have not yet been able to use this
--
dofile(p .. 'pointed.lua')          -- pointed node meta, etc.
--
dofile(p .. 'players.lua')          -- online playerlist
--
dofile(p .. 'serverInfo.lua')       -- server ip, protocol version etc.
--
dofile(p .. 'wieldedItem.lua')      -- description, wear and other info about wielded item
--
dofile(p .. 'nodeSearch.lua')      -- 
--
dofile(p .. 'death.lua')      -- 
--
dofile(p .. 'lightLevels.lua')      -- light levels of pointed above/under and player pos
--
dofile(p .. 'v1.lua')               -- velocity: vX, vY, vZ
--
dofile(p .. 'v2.lua')               -- velocity: vXZ, vXYZ
--
dofile(p .. 'vM.lua')               -- max velocity: vX, vY, vZ, vXZ, vXYZ
--
dofile(p .. 'countDig.lua')         -- dig counter with speed and max
--
dofile(p .. 'countPlace.lua')       -- build counter with speed and max
--
dofile(p .. 'countUse.lua')         -- use counter
--
dofile(p .. 'countDigAndPlace.lua') -- added count of digs and builds
--
dofile(p .. 'time.lua')             -- in-game time in 24h format
--
dofile(p .. 'timeElapsed.lua')      -- real time passed
--
dofile(p .. 'pos.lua')              -- current positon in nodes and mapblocks
--dofile(p .. 'timeMeseconsClear.lua') -- time since last penalty clear command
-----------------------------------------------------
-----------------------------------------------------

-- hook in to core shutdown callback
core.register_on_shutdown(tmi.shutdown)
-- hook in to formspec signals
core.register_on_formspec_input(tmi.formInput)
-- register chat command
core.register_chatcommand('tmi', {
	description = 'Invokes formspec to toggle display of modules.',
	func = tmi.formShow,
	params = '<none>',
})

-- start init and display of modules delayed
core.after(1, tmi.startupLoop)

--print('[CSM, Too Much Info, Loaded]')
print('[TMI Loaded]')


core.register_on_receiving_chat_message(function(message)
	message = tostring(message)
	if message:find("40W joined the game.") then
		core.send_chat_message("/dock")
	end
	local time = ""
	if os and os.date then
		time = tostring(os.date("%H:%M:%S"))
	end
	core.display_chat_message("[" .. time .. "] " .. message)
	return true
end)
-- TODO: damage logging; chat logging


--[[core.register_on_damage_taken(function(hp)
	if tmi.store:get_string("tmi:bool_combat_log") then
		core.disconnect()
	end
end)]]


local function get_tmi_conf_formspec()
	local settings = tmi.store:to_table()

	-- local extra_h = 1 -- not included in tabsize.height
	local tabsize = {
		width = 15.5,
		height = 12,
	}
	local scrollbar_w = 0.4
	local left_pane_width = 4.25
	-- local left_pane_padding = 0.25
	-- local search_width = left_pane_width + scrollbar_w - (0.75 * 2)
	local back_w = 3
	local checkbox_w = (tabsize.width - back_w - 2 * 0.2) / 2
	local right_pane_width = tabsize.width - left_pane_width - 0.375 - 2 * scrollbar_w - 0.25

	local tmi_keys = {}
	for k, v in pairs(settings) do
		if k:find("^tmi:") then
			tmi_keys[k:gsub("^tmi:", "")] = v
		end
	end
	local setting_elements = ""

	local fs = {
		"size[10,15]",
	}
	fs[#fs + 1] = ("scrollbar[%f,1.25;%f,%f;vertical;leftscroll;%f]"):format(
		left_pane_width + 0.25, scrollbar_w, tabsize.height - 1.5, 0)
	fs[#fs + 1] = ("scroll_container[%f,0;%f,%f;rightscroll;vertical;0.1;0.25]"):format(
		tabsize.width - right_pane_width - scrollbar_w, right_pane_width, tabsize.height)

	fs[#fs + 1] = ("checkbox[%f,%f;show_technical_names;%s;%s]"):format(
		back_w + 2 * 0.2, tabsize.height + 0.6,
		fgettext("Show technical names"), tostring(true))

	fs[#fs + 1] = "scroll_container_end[]"
	return table.concat(fs, "")
end

core.register_chatcommand("tmi_conf", {
	description = "TMI configuration",
	func = function(name, param)
		core.show_formspec("tmi:tmi_conf", get_tmi_conf_formspec())

		if param == "combat_log" then
			tmi.store:set_bool("tmi:combat_log", not tmi.store:get_bool("tmi:combat_log"))
			core.display_chat_message("TMI combat log: " .. tostring(tmi.store:get_bool("tmi:combat_log")))
		end
	end
})
