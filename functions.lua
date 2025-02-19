local C = core.colorize
local F = core.formspec_escape
local SER = core.serialize


--------------------------------------------------------------------------------
-- Localize functions to avoid table lookups (better performance).
local string_sub, string_find = string.sub, string.find
local math = math

--------------------------------------------------------------------------------
local function basic_dump(o)
	local tp = type(o)
	if tp == "number" then
		return tostring(o)
	elseif tp == "string" then
		return string.format("%q", o)
	elseif tp == "boolean" then
		return tostring(o)
	elseif tp == "nil" then
		return "nil"
		-- Uncomment for full function dumping support.
		-- Not currently enabled because bytecode isn't very human-readable and
		-- dump's output is intended for humans.
		--elseif tp == "function" then
		--	return string.format("loadstring(%q)", string.dump(o))
	elseif tp == "userdata" then
		return tostring(o)
	else
		return string.format("<%s>", tp)
	end
end

local keywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["goto"] = true, -- Lua 5.2
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}
local function is_valid_identifier(str)
	if not str:find("^[a-zA-Z_][a-zA-Z0-9_]*$") or keywords[str] then
		return false
	end
	return true
end

local function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end
function tmi.dump_sorted(o, indent, nested, level)
	local t = type(o)
	if not level and t == "userdata" then
		-- when userdata (e.g. player) is passed directly, print its metatable:
		return "userdata metatable: " .. dump(getmetatable(o))
	end
	if t ~= "table" then
		return basic_dump(o)
	end

	-- Contains table -> true/nil of currently nested tables
	nested = nested or {}
	if nested[o] then
		return "<circular reference>"
	end
	nested[o] = true
	indent = indent or "\t"
	level = level or 1

	local ret = {}
	local dumped_indexes = {}
	for i, v in ipairs(o) do
		ret[#ret + 1] = dump(v, indent, nested, level + 1)
		dumped_indexes[i] = true
	end
	for k, v in pairsByKeys(o) do
		if not dumped_indexes[k] then
			if type(k) ~= "string" or not is_valid_identifier(k) then
				k = "[" .. dump(k, indent, nested, level + 1) .. "]"
			end
			v = dump(v, indent, nested, level + 1)
			ret[#ret + 1] = k .. " = " .. v
		end
	end
	nested[o] = nil
	if indent ~= "" then
		local indent_str = "\n" .. string.rep(indent, level)
		local end_indent_str = "\n" .. string.rep(indent, level - 1)
		return string.format("{%s%s%s}",
			indent_str,
			table.concat(ret, "," .. indent_str),
			end_indent_str)
	end
	return "{" .. table.concat(ret, ", ") .. "}"
end

--[[ tModule is something like this
tModule = {
	id = 'moduleID', -- Unique module identifier. (String) {IDs beginning with '__' are reserved}
	title = 'Module Name', -- Title to show on toggle formspec. (String)
	updateWhenHidden = false, -- run update() even if hidden (but main HUD is on)
	value = '---', -- current/default valuestring to display if onUpdate is not a function. (String)
	onClear = nil, -- function to clear/reset or nil. When set, adds a button
				-- to formspec. This hook is called when button is pressed.
	onDealoc = nil, -- function to run on shutdown or nil. E.g. to save data.
	onHide = nil, -- function or nil. Called when module is deactivated in formspec
	onInit = nil, -- function to run on startup or nil.
				-- E.g. to read values from datastore.
				-- Can be called multiple times per session.
				-- Check tmi.modules[index].bInitDone field to detect repeated call
				-- or manipulate it in another hook to request a re-init
	onReveal = nil, -- function or nil. Called when module is activated in formspec
	onUpdate = nil, -- function to, update and return value, Is called at interval
				-- or nil --> value field is used
}) --]]
-- your module script needs to call this at load to register in the order
-- you want the info snippets to show up in
function tmi.addModule(tModule)
	-- no id, no registration
	if not tModule.id then return false end
	-- already got a module with that id
	if tmi.moduleLookup[tModule.id] then return false end

	tModule.index = #tmi.modules + 1
	tmi.modules[tModule.index] = tModule
	tmi.moduleLookup[tModule.id] = tModule.index

	return tModule.index
end -- addModule

function tmi.formInput(formname, fields)
	if tmi.formname ~= formname then return false end

	local m
	for k, v in pairs(fields) do
		local index = tonumber(k)
		if index then
			tmi.toggleModule(index)
		elseif 'b_' == k:sub(1, 2) then
			-- a button was pressed
			index = tonumber(k:sub(3, -1))
			if index then
				m = tmi.modules[index]
				if m and 'function' == type(m.onClear) then
					m.onClear(index)
				end
			end
		elseif 'quit' == k then
			--return true
		else
			print(dump(fields))
		end
	end -- loop all fields. With our formspec there should only be one

	return true
end -- formInput

function tmi.formShow()
	local iMax = #tmi.modules
	if 0 == iMax then return end

	local iX = .5
	local iY = .25
	local sOut = 'size[15,' .. F(tostring(iMax * .5 + 1.5)) .. ']'
		.. 'checkbox[' .. F(tostring(iX)) .. ',' .. F(tostring(iY)) .. ';'
		.. '0;Main;' .. F(tostring(tmi.isOn('__tmi__'))) .. ']'

	do
		-- textarea[<X>,<Y>;<W>,<H>;<name>;<label>;<default>]
		local bMain = tmi.isOn('__tmi__')

		if bMain and not tmi.hudID then return tmi.init() end

		local textbox_sOut = ''
		local textbox_iMax = #tmi.modules
		if 0 == textbox_iMax then return end

		local b, m, s
		for index = 1, textbox_iMax do
			s = ''
			m = tmi.modules[index]
			b = tmi.isOn(m.id)
			if b or m.updateWhenHidden then
				if 'function' == type(m.onUpdate) then
					s = m.onUpdate(index)
				else
					s = m.value or ''
				end
			end
			if b and '' ~= s then textbox_sOut = textbox_sOut .. s .. '\n' end
		end -- loop modules

		sOut = sOut ..
			"textarea[5,0;10," .. F(tostring(iMax * .5 + 1.5)) .. ";textbox_tmi_gui;;" .. F(textbox_sOut) .. "]"
	end


	local m
	for index = 1, iMax do
		iY = iY + .5
		m = tmi.modules[index]
		if 'function' == type(m.onClear) then
			-- add clear button
			sOut = sOut .. 'button[0,' .. F(tostring(iY)) .. ';.5,1;'
				.. 'b_' .. F(tostring(index)) .. ';X]'
		end
		sOut = sOut .. 'checkbox[' .. F(tostring(iX)) .. ',' .. F(tostring(iY)) .. ';'
			.. F(tostring(index)) .. ';' .. F(m.title) .. ';' .. F(tostring(tmi.isOn(m.id))) .. ']'
	end -- loop modules

	core.show_formspec(tmi.formname, sOut)
end -- formShow

function tmi.getVersion()
	local tV = core.get_version()
	tV.major = tonumber(tV.string:sub(1, 1))
	tV.minor = tonumber(tV.string:sub(3, 3))
	return tV
end

function tmi.init()
	-- don't do anything else if there is already a hud id stored
	if tmi.hudID then return end

	local bMain = tmi.isOn('__tmi__')

	if bMain then
		local tV = tmi.getVersion()
		local tHud = {
			type = 'text',
			name = 'tmiHUD',
			number = tmi.conf.colour,
			position = { x = 1 - 0.01, y = 0.95 },
			offset = { x = 8, y = -8 },
			text = 'Too Much Info HUD',
			scale = { x = 200, y = 60 },
			alignment = { x = -1, y = -1 },
			size = 0.5,
		}
		tmi.hudID = tmi.player:hud_add(tHud)
	end

	local iMax = #tmi.modules
	if 0 == iMax then return end
	local m
	for index = 1, iMax do
		m = tmi.modules[index]
		if (not m.bInitDone) and ('function' == type(m.onInit)) then
			m.onInit(index)
			-- modules can change it to request another init when main is turned on
			m.bInitDone = true
		end
		-- TODO: onReveal should be called here, no?
		-- not always. If game is launched with TMI-HUD hidden then module isn't
		-- being revealed
	end -- loop modules

	print('[TMI modules initialized]')
end -- init

-- query CSM-datastore for toggle setting of module
function tmi.isOn(id) return '' == tmi.store:get_string(id .. '_disabled') end -- isOn

-- clumsy name for a clumsy way of inserting grouping characters
function tmi.niceNaturalString(iN)
	local sOut = tostring(iN)
	if 3 < #sOut then
		sOut = sOut:sub(1, -4) .. "'" .. sOut:sub(-3, -1)
	end
	if 7 < #sOut then
		sOut = sOut:sub(1, -8) .. "'" .. sOut:sub(-7, -1)
	end
	if 11 < #sOut then
		sOut = sOut:sub(1, -12) .. "'" .. sOut:sub(-11, -1)
	end

	return sOut
end -- niceNaturalString

function tmi.removeHUD()
	-- no hud yet?
	if not tmi.hudID then return end

	tmi.player:hud_remove(tmi.hudID)
	tmi.hudID = nil
end -- removeHUD

-- called when logging off
function tmi.shutdown()
	local iMax = #tmi.modules
	if 0 == iMax then return end
	local m
	for index = 1, iMax do
		m = tmi.modules[index]
		if 'function' == type(m.onDealoc) then m.onDealoc(index) end
	end -- loop modules

	print('[TMI shutdown]')
end -- shutdown

function tmi.startupLoop()
	tmi.player = core.localplayer
	tmi.camera = core.camera

	if tmi.player and tmi.camera then
		core.after(1, tmi.init)
		core.after(2, tmi.update)
	else
		core.after(0.5, tmi.startupLoop)
	end
end -- startupLoop

-- to toggle visibility of a module by index
function tmi.toggleModule(index)
	local id, m
	-- main switch is inexistant index 0
	local bIsMain = 0 == index
	if bIsMain then
		id = '__tmi__'
		-- kinda check if index could be out of range
		--elseif #tmi.modules < index then
		--	return
		-- better check that also checks if an id is actually set
	elseif tmi.modules[index] and tmi.modules[index].id then
		m = tmi.modules[index]
		id = m.id
	else
		-- abbort
		return
	end

	-- get new value by inverting current value
	local bIsTurningOn = not tmi.isOn(id)
	local sNew = bIsTurningOn and '' or '-'
	tmi.store:set_string(id .. '_disabled', sNew)

	-- if m then
	if not bIsMain then
		if bIsTurningOn then
			if 'function' == type(m.onReveal) then
				m.onReveal(index)
			end
		else
			if 'function' == type(m.onHide) then
				m.onHide(index)
			end
		end
		return
	end -- if a submodule was toggled

	-- main module toggeled, need to destroy or remake HUD
	-- turn on?
	if bIsTurningOn then
		-- some modules might get init() called
		tmi.update()
	end

	-- call module hooks for reveal and hide
	-- we recycle index variable as we know it is 0 and don't need it anymore
	for index = 1, #tmi.modules do
		m = tmi.modules[index]
		if bIsTurningOn then
			if 'function' == type(m.onReveal) then
				m.onReveal(index)
			end
		else
			if 'function' == type(m.onHide) then
				m.onHide(index)
			end
		end -- if turning on or off
	end -- loop all modules

	-- turnig off, need to remove HUD
	if not bIsTurningOn then
		tmi.removeHUD()
	end
end                                                                        -- toggleModule

function tmi.twoDigitNumberString(iN) return string.format('%02i', iN) end -- twoDigitNumberString

function tmi.update()
	local bMain = tmi.isOn('__tmi__')

	core.after(tmi.conf.interval, tmi.update)

	-- if main switch is on but no HUD-ID, then we need to init HUD and
	-- possibly re-run module's init-hook
	if bMain and not tmi.hudID then return tmi.init() end

	local sOut = ''
	local iMax = #tmi.modules
	if 0 == iMax then return end

	local b, m, s
	for index = 1, iMax do
		s = ''
		m = tmi.modules[index]
		b = tmi.isOn(m.id)
		if b or m.updateWhenHidden then
			if 'function' == type(m.onUpdate) then
				s = m.onUpdate(index)
			else
				s = m.value or ''
			end
		end
		if b and '' ~= s then sOut = sOut .. s .. '\n' end
	end -- loop modules

	--if not bMain then return end
	if not tmi.hudID then return end

	tmi.player:hud_change(tmi.hudID, 'text', sOut)
end -- update

--print('loaded functions.lua')


--[[
Players: tarmo
161.97.183.176/161.97.183.176:30000v46-en_US/
CSM: 111111

Wielded Item Meta: {
	fields = {
		name = "Gear Kit 4.2.2025"
	}
}

Wielded Item Inv: {
mcl_tools:pick_netherite_enchanted 1 0 "–groupcaps_hash–f22fcd20–tool_capabilities–{\"damage_groups\":{\"fleshy\":6},\"full_punch_interval\":0.83333331346511841,\"groupcaps\":{\"pickaxey_dig_default\":{\"maxlevel\":0,\"times\":[null,0.0,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448,0.15000000596046448,0.20000000298023224,0.20000000298023224,0.25,0.30000001192092896,0.30000001192092896,0.40000000596046448,0.44999998807907104,0.5,0.60000002384185791,0.64999997615814209,0.75,1.0,1.2999999523162842,1.7000000476837158,2.2999999523162842,3.0,3.2000000476837158,4.25,7.0500001907348633],\"uses\":8124},\"pickaxey_dig_diamond\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448,0.15000000596046448,0.20000000298023224,0.20000000298023224,0.25,0.30000001192092896,0.40000000596046448,0.55000001192092896,0.69999998807907104,0.89999997615814209,1.0,1.2999999523162842,2.1500000953674316],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Pickaxe–Silk Touch–Unbreaking III–Mending–Efficiency V–Mining speed: Extremely fast–Durability: 8124/8124–Block breaking strength: 5–Damage: 6–Full punch interval: 0.83s–mcl_enchanting:enchantments–return {silk_touch=1,mending=1,efficiency=5,unbreaking=3}–"  x1,    
mcl_tools:axe_netherite_enchanted 1 0 "–groupcaps_hash–25fee0ab–tool_capabilities–{\"damage_groups\":{\"fleshy\":10},\"full_punch_interval\":1.0,\"groupcaps\":{\"axey_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Axe–Silk Touch–Smite V–Mending–Unbreaking III–Efficiency V–Mining speed: Extremely fast–Durability: 6248/6248–Block breaking strength: 5–Damage: 9–Full punch interval: 1.00s–mcl_enchanting:enchantments–return {silk_touch=1,smite=5,mending=1,unbreaking=3,efficiency=5}–"  x1,    
mcl_farming:hoe_netherite_enchanted 1 0 "–groupcaps_hash–0bf30d73–tool_capabilities–{\"damage_groups\":{\"fleshy\":4},\"full_punch_interval\":0.25,\"groupcaps\":{\"hoey_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.15000000596046448],\"uses\":8124}},\"max_drop_level\":1,\"punch_attack_uses\":2031}–mcl_enchanting:enchantments–return {unbreaking=3,mending=1,efficiency=5,silk_touch=1}–description–Netherite Hoe–Mending–Silk Touch–Unbreaking III–Efficiency V––Turns block into farmland–Durability: 6248/6248–Block breaking strength: 1–Damage: 1–Full punch interval: 0.25s–"  x1,    
mcl_tools:shovel_netherite_enchanted 1 0 "–groupcaps_hash–be76b34e–tool_capabilities–{\"damage_groups\":{\"fleshy\":5},\"full_punch_interval\":1.0,\"groupcaps\":{\"shovely_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Shovel–Mending–Silk Touch–Unbreaking III–Efficiency V–Mining speed: Extremely fast–Durability: 6248/6248–Block breaking strength: 5–Damage: 5–Full punch interval: 1.00s–mcl_enchanting:enchantments–return {mending=1,silk_touch=1,unbreaking=3,efficiency=5}–"  x1,    
mcl_armor:helmet_netherite_enchanted 1 0 "–inventory_image–mcl_armor_inv_helmet_netherite.png^[colorize:purple:50^(helmet_trim.png^[colorize:#302a26:150)–mcl_armor:inv–^(helmet_trim.png^[colorize:#302a26:150)–mcl_armor:trim_overlay–^(rib_helmet.png^[colorize:#302a26:150)–mcl_enchanting:enchantments–return {protection=4,thorns=3,mending=1,unbreaking=3}–description–Netherite Helmet–Protection IV–Thorns III–Mending–Unbreaking III––Head armor–Armor points: 3–Armor durability: 544–Upgrade:– Rib Armor Trim–"  x1,    
mcl_armor:chestplate_netherite_enchanted 1 0 "–inventory_image–mcl_armor_inv_chestplate_netherite.png^[colorize:purple:50^(chestplate_trim.png^[colorize:#302a26:150)–mcl_armor:inv–^(chestplate_trim.png^[colorize:#302a26:150)–mcl_armor:trim_overlay–^(rib_chestplate.png^[colorize:#302a26:150)–mcl_enchanting:enchantments–return {protection=4,thorns=3,mending=1,unbreaking=3}–description–Netherite Chestplate–Protection IV–Thorns III–Mending–Unbreaking III––Torso armor–Armor points: 8–Armor durability: 794–Upgrade:– Rib Armor Trim–"  x1,    
mcl_armor:leggings_netherite_enchanted 1 0 "–inventory_image–mcl_armor_inv_leggings_netherite.png^[colorize:purple:50^(leggings_trim.png^[colorize:#302a26:150)–mcl_armor:inv–^(leggings_trim.png^[colorize:#302a26:150)–mcl_armor:trim_overlay–^(rib_leggings.png^[colorize:#302a26:150)–mcl_enchanting:enchantments–return {protection=4,thorns=3,mending=1,unbreaking=3}–description–Netherite Leggings–Protection IV–Thorns III–Mending–Unbreaking III––Legs armor–Armor points: 6–Armor durability: 744–Upgrade:– Rib Armor Trim–"  x1,    
mcl_armor:boots_netherite_enchanted 1 0 "–inventory_image–mcl_armor_inv_boots_netherite.png^[colorize:purple:50^(boots_trim.png^[colorize:#302a26:150)–mcl_armor:inv–^(boots_trim.png^[colorize:#302a26:150)–mcl_armor:trim_overlay–^(rib_boots.png^[colorize:#302a26:150)–mcl_enchanting:enchantments–return {protection=4,thorns=3,unbreaking=3,depth_strider=3,feather_falling=4,soul_speed=3,mending=1}–description–Netherite Boots–Protection IV–Thorns III–Unbreaking III–Depth Strider III–Feather Falling IV–Mending–Soul Speed III––Feet armor–Armor points: 3–Armor durability: 644–Upgrade:– Rib Armor Trim–"  x1,    
mcl_armor:elytra_enchanted 1 0 "–description–Elytra–Mending–Unbreaking III––Torso armor–Armor durability: 14–mcl_enchanting:enchantments–return {mending=1,unbreaking=3}–"  x1,    
mcl_tools:pick_netherite_enchanted 1 0 "–groupcaps_hash–f22fcd20–tool_capabilities–{\"damage_groups\":{\"fleshy\":6},\"full_punch_interval\":0.83333331346511841,\"groupcaps\":{\"pickaxey_dig_default\":{\"maxlevel\":0,\"times\":[null,0.0,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448,0.15000000596046448,0.20000000298023224,0.20000000298023224,0.25,0.30000001192092896,0.30000001192092896,0.40000000596046448,0.44999998807907104,0.5,0.60000002384185791,0.64999997615814209,0.75,1.0,1.2999999523162842,1.7000000476837158,2.2999999523162842,3.0,3.2000000476837158,4.25,7.0500001907348633],\"uses\":8124},\"pickaxey_dig_diamond\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448,0.15000000596046448,0.20000000298023224,0.20000000298023224,0.25,0.30000001192092896,0.40000000596046448,0.55000001192092896,0.69999998807907104,0.89999997615814209,1.0,1.2999999523162842,2.1500000953674316],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Pickaxe–Fortune III–Mending–Unbreaking III–Efficiency V–Mining speed: Extremely fast–Durability: 6248/6248–Block breaking strength: 5–Damage: 5–Full punch interval: 0.83s–mcl_enchanting:enchantments–return {fortune=3,mending=1,unbreaking=3,efficiency=5}–"  x1,    
mcl_tools:axe_netherite_enchanted 1 0 "–groupcaps_hash–25fee0ab–tool_capabilities–{\"damage_groups\":{\"fleshy\":10},\"full_punch_interval\":1.0,\"groupcaps\":{\"axey_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.10000000149011612,0.10000000149011612,0.15000000596046448,0.15000000596046448],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Axe–Sharpness V–Mending–Fortune III–Unbreaking III–Efficiency V–Mining speed: Extremely fast–Durability: 6248/6248–Block breaking strength: 5–Damage: 11–Full punch interval: 1.00s–mcl_enchanting:enchantments–return {mending=1,fortune=3,sharpness=5,unbreaking=3,efficiency=5}–"  x1,    
mcl_farming:hoe_netherite_enchanted 1 0 "–groupcaps_hash–0bf30d73–tool_capabilities–{\"damage_groups\":{\"fleshy\":4},\"full_punch_interval\":0.25,\"groupcaps\":{\"hoey_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0,0.15000000596046448],\"uses\":8124}},\"max_drop_level\":1,\"punch_attack_uses\":2031}–description–Netherite Hoe–Fortune III–Mending–Unbreaking III–Efficiency V––Turns block into farmland–Durability: 6248/6248–Block breaking strength: 1–Damage: 1–Full punch interval: 0.25s–mcl_enchanting:enchantments–return {fortune=3,mending=1,unbreaking=3,efficiency=5}–"  x1,    
mcl_tools:shovel_netherite_enchanted 1 0 "–groupcaps_hash–be76b34e–tool_capabilities–{\"damage_groups\":{\"fleshy\":5},\"full_punch_interval\":1.0,\"groupcaps\":{\"shovely_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0,0.0,0.0,0.0],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":1016}–description–Netherite Shovel–Mending–Fortune III–Unbreaking III–Efficiency V–Mining speed: Extremely fast–Durability: 6248/6248–Block breaking strength: 5–Damage: 5–Full punch interval: 1.00s–mcl_enchanting:enchantments–return {mending=1,fortune=3,unbreaking=3,efficiency=5}–"  x1,    
mcl_bows:bow_enchanted 1 0 "–description–Bow–Power V–Flame–Punch II–Unbreaking III–Infinity––Launches arrows–Durability: 1540/1540 uses–mcl_enchanting:enchantments–return {power=5,flame=1,punch=2,unbreaking=3,infinity=1}–"  x1,    
mcl_bows:arrow 64  x1,    
mcl_mobitems:warped_fungus_on_a_stick  x1,    
mcl_mobitems:carrot_on_a_stick  x1,    
vl_fireworks:rocket 64 0 "–vl_fireworks:duration–6–vl_fireworks:force–30–vl_fireworks:stars–return {\"return {size=2,fn=\\\"generic\\\"}\"}–description–Firework Rocket–Flight Duration: 6––Generic Firework Star–Size: 2–"  x1,    
mcl_tools:sword_netherite_enchanted 1 0 "–mcl_enchanting:enchantments–return {fire_aspect=2,unbreaking=3,sharpness=5,mending=1,looting=3,knockback=2}–tool_capabilities–{\"damage_groups\":{\"fleshy\":11},\"full_punch_interval\":0.625,\"groupcaps\":{\"swordy_cobweb_dig\":{\"maxlevel\":0,\"times\":[null,0.69999998807907104],\"uses\":8124},\"swordy_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.15000000596046448,0.20000000298023224],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":8124}–groupcaps_hash–4eaca884–description–Netherite Sword–Knockback II–Fire Aspect II–Sharpness V–Unbreaking III–Looting III–Mending–Damage: 11–Full punch interval: 0.63s–Mining speed: Very fast–Durability: 8124/8124–Block breaking strength: 5–"  x1,    
mcl_tools:sword_netherite_enchanted 1 0 "–groupcaps_hash–fc031739–tool_capabilities–{\"damage_groups\":{\"fleshy\":9},\"full_punch_interval\":0.625,\"groupcaps\":{\"swordy_cobweb_dig\":{\"maxlevel\":0,\"times\":[null,0.69999998807907104],\"uses\":8124},\"swordy_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.15000000596046448,0.20000000298023224],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":2031}–description–Netherite Sword–Looting III–Fire Aspect II–Mending–Smite V–Knockback II–Unbreaking III–Damage: 7–Full punch interval: 0.63s–Mining speed: Very fast–Durability: 6248/6248–Block breaking strength: 5–mcl_enchanting:enchantments–return {looting=3,fire_aspect=2,mending=1,knockback=2,unbreaking=3,smite=5}–"  x1,    
mcl_tools:sword_netherite_enchanted 1 0 "–groupcaps_hash–fc031739–tool_capabilities–{\"damage_groups\":{\"fleshy\":9},\"full_punch_interval\":0.625,\"groupcaps\":{\"swordy_cobweb_dig\":{\"maxlevel\":0,\"times\":[null,0.69999998807907104],\"uses\":8124},\"swordy_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.15000000596046448,0.20000000298023224],\"uses\":8124}},\"max_drop_level\":5,\"punch_attack_uses\":2031}–description–Netherite Sword–Looting III–Bane of Arthropods V–Fire Aspect II–Mending–Knockback II–Unbreaking III–Damage: 7–Full punch interval: 0.63s–Mining speed: Very fast–Durability: 6248/6248–Block breaking strength: 5–mcl_enchanting:enchantments–return {looting=3,bane_of_arthropods=5,fire_aspect=2,mending=1,knockback=2,unbreaking=3}–"  x1,    
mcl_fishing:fishing_rod_enchanted 1 0 "–mcl_enchanting:enchantments–return {mending=1,luck_of_the_sea=3,lure=3,unbreaking=3}–description–Fishing Rod–Mending–Luck of the Sea III–Lure III–Unbreaking III––Catches fish in water–Durability: 260/260 uses–"  x1,    
mcl_tools:shears_enchanted 1 0 "–description–Shears–Mending–Efficiency V–Silk Touch–Unbreaking III–Mining speed: Fast–Durability: 952/952–Block breaking strength: 1–Full punch interval: 0.50s–groupcaps_hash–02e0a238–tool_capabilities–{\"damage_groups\":null,\"full_punch_interval\":0.5,\"groupcaps\":{\"shearsy_cobweb_dig\":{\"maxlevel\":0,\"times\":[null,0.15000000596046448],\"uses\":952},\"shearsy_dig\":{\"maxlevel\":0,\"times\":[null,0.0,0.0,0.0],\"uses\":952},\"shearsy_wool_dig\":{\"maxlevel\":0,\"times\":[null,0.0],\"uses\":952}},\"max_drop_level\":1,\"punch_attack_uses\":0}–mcl_enchanting:enchantments–return {mending=1,unbreaking=3,silk_touch=1,efficiency=5}–"  x1,    
mcl_experience:bottle 64  x1,    
mcl_farming:carrot_item_gold 64  x1,    
mcl_core:apple_gold_enchanted 64  x1,    
mcl_chests:ender_chest 64  x1,    
}

Gear Kit 4.2.2025
27 inventory slots
Can be carried around with its contents
1 mcl_chests:black_shulker_box
Durability: None  100%

vX: 0 vY: 0 vZ: 0
vXZ: 0 vXYZ: 0
vmX: 7.99 vmY: 33.5 vmZ: 14.6
vmXZ: 14.8 vmXYZ: 33.5

D: 28'206   0n/s 0n/s max
P: 3'552   0n/s 0n/s max
U: 1'395
D&P: 31'758
Time: 15:38
Elapsed: 00:00:45
Node: 2462, -28832, 3690
Block: 153, -1802, 230
]]

local full_inv_pattern = string.rep("_%[1%],", 26) .. "_%[1%]"
function tmi.strip_esc(str)
	--[[:gsub("\\?\\u%w%w%w%w%([cT].-%)?E?", "")]]
	return tostring(str):gsub("\\?27%([cT].-%)", ""):gsub("\\?27[FE]", ""):gsub(full_inv_pattern, "_[1] x27"):gsub("\\?u000[123]", "–"):gsub("\\?u001b%b()", ""):gsub("\\?u001b[FE]", "")--:gsub("\\u%w%w%w%wE?", "")
end

local empty_table_dump = dump({})
local empty_table_ser = SER({})
local empty_fields_table_dump = dump({ fields = {} })
local empty_fields_table_ser = SER({ fields = {} })


function tmi.dump_meta_inv(meta_inv_table)
	if meta_inv_table then
		local meta_inv_table_counts = {}
		for meta_inv_table_index, meta_inv_table_itemstack in pairs(meta_inv_table) do
			local itemstack_str = tostring(meta_inv_table_itemstack)
			if meta_inv_table_itemstack and meta_inv_table_itemstack.get_meta then
				local itemstack_meta = meta_inv_table_itemstack:get_meta()
				if itemstack_meta then
					local itemstack_meta_table = itemstack_meta:to_table()
					if itemstack_meta_table then
						local ser = (SER(itemstack_meta_table))
						if ser ~= empty_fields_table_ser then
							itemstack_str = itemstack_str .. " - " .. ser
						end
					end
				end
			end
			local previous_count_data = meta_inv_table_counts[#meta_inv_table_counts]
			if previous_count_data and previous_count_data.itemstack_str == itemstack_str then
				meta_inv_table_counts[#meta_inv_table_counts].count = (previous_count_data.count or 0) + 1
			else
				meta_inv_table_counts[#meta_inv_table_counts + 1] = {
					itemstack_str = itemstack_str,
					count = 1,
				}
			end
		end
		local meta_inv_output = ""
		for indx, count_data in ipairs(meta_inv_table_counts) do
			meta_inv_output = meta_inv_output ..
				tostring(count_data.itemstack_str):gsub("ItemStack%((.*)%)", "%1") ..
				" " .. string.format("%3s", "x" .. (count_data.count or 0)) .. ",    \n"
		end
		--[[local meta_inv_serialized = SER(meta_inv_table)
			local inv_indices = string.match(meta_inv_serialized, "return ({.*})") or ""
			if inv_indices == "{_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1]}" then
				inv_indices = "[All 27 inv items same]"
				-- meta_inv = { meta_inv[1] }
			end--]]
		-- output = output .. C("#eff", "\nPointed Node Inv: " .. dump((meta_inv)) .. "\n" .. tostring(inv_indices) .. "\n")
		return tmi.strip_esc(meta_inv_output)
	else
		return ""
	end
end
