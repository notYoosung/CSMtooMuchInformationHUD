local C = minetest.colorize
local F = minetest.formspec_escape
local SER = minetest.serialize


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
	["goto"] = true,  -- Lua 5.2
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
    local iter = function ()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
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
				k = "["..dump(k, indent, nested, level + 1).."]"
			end
			v = dump(v, indent, nested, level + 1)
			ret[#ret + 1] = k.." = "..v
		end
	end
	nested[o] = nil
	if indent ~= "" then
		local indent_str = "\n"..string.rep(indent, level)
		local end_indent_str = "\n"..string.rep(indent, level - 1)
		return string.format("{%s%s%s}",
				indent_str,
				table.concat(ret, ","..indent_str),
				end_indent_str)
	end
	return "{"..table.concat(ret, ", ").."}"
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
		index = tonumber(k)
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
	local sOut = 'size[10,' .. F(tostring(iMax * .5 + 1.5)) .. ']'
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

		sOut = sOut .. "textarea[5,0;5," .. F(tostring(iMax * .5 + 1.5)) .. ";textbox_tmi_gui;;" .. F(textbox_sOut) .. "]"
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
end -- toggleModule

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
