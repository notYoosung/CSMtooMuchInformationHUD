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
	onDealloc = nil, -- function to run on shutdown or nil. E.g. to save data.
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

function tmi.get_output()
	local textbox_iMax = #tmi.modules
	if 0 == textbox_iMax then return "" end

	local output = ""
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
		if b and '' ~= s and nil ~= s then output = output .. tostring(s) .. '\n' end
	end -- loop modules
	return output
end

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
		
		local textbox_sOut = tmi.get_output()

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
		if 'function' == type(m.onDealloc) then m.onDealloc(index) end
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


	tmi.player_pos = tmi.player:get_pos()


	local sOut = ''
	local iMax = #tmi.modules
	if 0 == iMax then return end

	sOut = sOut .. tmi.get_output()

	--if not bMain then return end
	if not tmi.hudID then return end

	tmi.player:hud_change(tmi.hudID, 'text', sOut)
end -- update

--print('loaded functions.lua')



local full_inv_pattern = string.rep("_%[1%],", 26) .. "_%[1%]"
function tmi.strip_esc(str)
	--[[:gsub("\\?\\u%w%w%w%w%([cT].-%)?E?", "")]]
	return tostring(str):gsub("\\?27%([cT].-%)", ""):gsub("\\?27[FE]", ""):gsub(full_inv_pattern, "_[1] x27"):gsub("\\?u000[123]", "–"):gsub("\\?u001b%b()", ""):gsub("\\?u001b[FE]", "")--:gsub("\\u%w%w%w%wE?", "")
end

local empty_table_dump = dump({})
local empty_table_ser = SER({})
local empty_fields_table_dump = dump({ fields = {} })
local empty_fields_table_ser = SER({ fields = {} })

local empty_itemstr = C("#ff555", "\"\"")
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
			local itemstack_name = tostring(count_data.itemstack_str):gsub("ItemStack%((.*)%)", "%1")
			local output_append = itemstack_name .. " x" .. tostring(count_data.count or 0) .. ",    \n"
			meta_inv_output = meta_inv_output .. (itemstack_name == "\"\"" and empty_itemstr or output_append)
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

--[[
.local player = minetest.localplayer player:hud_add({ 	type = "waypoint", 	name = "poswaypoint", 	text = "", 	precision = 10, 	number = 0x00ff00, 	world_pos = vector.new(4671,-8224,5807), 	offset = { x = 0, y = 0, z = 0 }, 	alignment = { x = 0, y = 0 }, })
]]