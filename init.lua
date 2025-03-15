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



tmi.colors = {
	{"aliceblue",            0xf0f8ff},
	{"antiquewhite",         0xfaebd7},
	{"aqua",                 0x00ffff},
	{"aquamarine",           0x7fffd4},
	{"azure",                0xf0ffff},
	{"beige",                0xf5f5dc},
	{"bisque",               0xffe4c4},
	{"black",                00000000},
	{"blanchedalmond",       0xffebcd},
	{"blue",                 0x0000ff},
	{"blueviolet",           0x8a2be2},
	{"brown",                0xa52a2a},
	{"burlywood",            0xdeb887},
	{"cadetblue",            0x5f9ea0},
	{"chartreuse",           0x7fff00},
	{"chocolate",            0xd2691e},
	{"coral",                0xff7f50},
	{"cornflowerblue",       0x6495ed},
	{"cornsilk",             0xfff8dc},
	{"crimson",              0xdc143c},
	{"cyan",                 0x00ffff},
	{"darkblue",             0x00008b},
	{"darkcyan",             0x008b8b},
	{"darkgoldenrod",        0xb8860b},
	{"darkgray",             0xa9a9a9},
	{"darkgreen",            0x006400},
	{"darkgrey",             0xa9a9a9},
	{"darkkhaki",            0xbdb76b},
	{"darkmagenta",          0x8b008b},
	{"darkolivegreen",       0x556b2f},
	{"darkorange",           0xff8c00},
	{"darkorchid",           0x9932cc},
	{"darkred",              0x8b0000},
	{"darksalmon",           0xe9967a},
	{"darkseagreen",         0x8fbc8f},
	{"darkslateblue",        0x483d8b},
	{"darkslategray",        0x2f4f4f},
	{"darkslategrey",        0x2f4f4f},
	{"darkturquoise",        0x00ced1},
	{"darkviolet",           0x9400d3},
	{"deeppink",             0xff1493},
	{"deepskyblue",          0x00bfff},
	{"dimgray",              0x696969},
	{"dimgrey",              0x696969},
	{"dodgerblue",           0x1e90ff},
	{"firebrick",            0xb22222},
	{"floralwhite",          0xfffaf0},
	{"forestgreen",          0x228b22},
	{"fuchsia",              0xff00ff},
	{"gainsboro",            0xdcdcdc},
	{"ghostwhite",           0xf8f8ff},
	{"gold",                 0xffd700},
	{"goldenrod",            0xdaa520},
	{"gray",                 0x808080},
	{"green",                0x008000},
	{"greenyellow",          0xadff2f},
	{"grey",                 0x808080},
	{"honeydew",             0xf0fff0},
	{"hotpink",              0xff69b4},
	{"indianred",            0xcd5c5c},
	{"indigo",               0x4b0082},
	{"ivory",                0xfffff0},
	{"khaki",                0xf0e68c},
	{"lavender",             0xe6e6fa},
	{"lavenderblush",        0xfff0f5},
	{"lawngreen",            0x7cfc00},
	{"lemonchiffon",         0xfffacd},
	{"lightblue",            0xadd8e6},
	{"lightcoral",           0xf08080},
	{"lightcyan",            0xe0ffff},
	{"lightgoldenrodyellow", 0xfafad2},
	{"lightgray",            0xd3d3d3},
	{"lightgreen",           0x90ee90},
	{"lightgrey",            0xd3d3d3},
	{"lightpink",            0xffb6c1},
	{"lightsalmon",          0xffa07a},
	{"lightseagreen",        0x20b2aa},
	{"lightskyblue",         0x87cefa},
	{"lightslategray",       0x778899},
	{"lightslategrey",       0x778899},
	{"lightsteelblue",       0xb0c4de},
	{"lightyellow",          0xffffe0},
	{"lime",                 0x00ff00},
	{"limegreen",            0x32cd32},
	{"linen",                0xfaf0e6},
	{"magenta",              0xff00ff},
	{"maroon",               0x800000},
	{"mediumaquamarine",     0x66cdaa},
	{"mediumblue",           0x0000cd},
	{"mediumorchid",         0xba55d3},
	{"mediumpurple",         0x9370db},
	{"mediumseagreen",       0x3cb371},
	{"mediumslateblue",      0x7b68ee},
	{"mediumspringgreen",    0x00fa9a},
	{"mediumturquoise",      0x48d1cc},
	{"mediumvioletred",      0xc71585},
	{"midnightblue",         0x191970},
	{"mintcream",            0xf5fffa},
	{"mistyrose",            0xffe4e1},
	{"moccasin",             0xffe4b5},
	{"navajowhite",          0xffdead},
	{"navy",                 0x000080},
	{"oldlace",              0xfdf5e6},
	{"olive",                0x808000},
	{"olivedrab",            0x6b8e23},
	{"orange",               0xffa500},
	{"orangered",            0xff4500},
	{"orchid",               0xda70d6},
	{"palegoldenrod",        0xeee8aa},
	{"palegreen",            0x98fb98},
	{"paleturquoise",        0xafeeee},
	{"palevioletred",        0xdb7093},
	{"papayawhip",           0xffefd5},
	{"peachpuff",            0xffdab9},
	{"peru",                 0xcd853f},
	{"pink",                 0xffc0cb},
	{"plum",                 0xdda0dd},
	{"powderblue",           0xb0e0e6},
	{"purple",               0x800080},
	{"rebeccapurple",        0x663399},
	{"red",                  0xff0000},
	{"rosybrown",            0xbc8f8f},
	{"royalblue",            0x4169e1},
	{"saddlebrown",          0x8b4513},
	{"salmon",               0xfa8072},
	{"sandybrown",           0xf4a460},
	{"seagreen",             0x2e8b57},
	{"seashell",             0xfff5ee},
	{"sienna",               0xa0522d},
	{"silver",               0xc0c0c0},
	{"skyblue",              0x87ceeb},
	{"slateblue",            0x6a5acd},
	{"slategray",            0x708090},
	{"slategrey",            0x708090},
	{"snow",                 0xfffafa},
	{"springgreen",          0x00ff7f},
	{"steelblue",            0x4682b4},
	{"tan",                  0xd2b48c},
	{"teal",                 0x008080},
	{"thistle",              0xd8bfd8},
	{"tomato",               0xff6347},
	{"turquoise",            0x40e0d0},
	{"violet",               0xee82ee},
	{"wheat",                0xf5deb3},
	{"white",                0xffffff},
	{"whitesmoke",           0xf5f5f5},
	{"yellow",               0xffff00},
	{"yellowgreen",          0x9acd32}
}