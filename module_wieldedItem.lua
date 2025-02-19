-- module wieldedItem --
-- by SwissalpS --
-- shows some info about wielded item. Updating
-- frequently so you can E.g. watch your dig count
-- of tool or level continuesly.
local C = core.colorize
local F = core.formspec_escape
local SER = core.serialize
local DES = core.deserialize

local empty_table_dump = dump({})
local empty_table_ser = SER({})
local empty_fields_table_dump = dump({ fields = {} })
local empty_fields_table_ser = SER({ fields = {} })

local function update(index)
	local output = ""

	local oWI = tmi.player:get_wielded_item()
	local oMeta = oWI:get_meta()
	local sItemstring = oWI:get_name()
	if '' == sItemstring then return 'Empty Hand\n' end

	if oMeta then
		local meta_table = oMeta:to_table()
		if meta_table then
			local inv_indices
			local meta_inv_serialized = "" -- prevent any edge cases and extra checks
			local meta_fields = meta_table.fields
			if meta_fields and SER(meta_fields) ~= SER({}) then
				meta_inv_serialized = meta_fields.inv
				if meta_fields.tool_capabilities then
					meta_table.fields.tool_capabilities = tmi.dump_sorted(DES("return " .. meta_fields.tool_capabilities))
				end
				meta_table.fields.description = nil
				if meta_inv_serialized then
					meta_table.fields.inv = nil
					inv_indices = string.match(meta_inv_serialized, "return ({[_\"].*})")
					if inv_indices == "{_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1],_[1]}" then
						inv_indices = "[All 27 inv items same]"
						meta_inv_serialized = SER({ DES(meta_inv_serialized)[1] })
					end
				end
			end
			if SER(meta_table) ~= empty_fields_table_ser then
				output = output ..
				C("#eff", "\nWielded Item Meta: " .. tmi.strip_esc(tmi.dump_sorted(meta_table)) .. "\n")
			end
			if meta_inv_serialized and meta_inv_serialized ~= "" then
				output = output .. C("#eff",
					"\nWielded Item Inv: {\n" ..
					tmi.strip_esc(tmi.dump_meta_inv(DES(meta_inv_serialized)):gsub("\\n", "–")) .. "}\n")
				if inv_indices and string.find(inv_indices, "_%[") then
					output = output .. C("#eff", tmi.strip_esc(inv_indices) .. "\n")
				end
			end
		end
	end

	local iCount = oWI:get_count()
	local sDescription = oWI:get_description()
	local iWear = oWI:get_wear()
	local iMax = 65535
	-- invert wear amount
	local iRemaining = iMax - iWear
	local fRemainingPercent = .01 * math.floor(
		10000 * iRemaining / iMax)
	local sWear
	if 0 == iWear then
		sWear = 'None'
	else
		sWear = tmi.niceNaturalString(iRemaining)
	end

	local sAux = ''
	local sPos = oMeta:get_string('target_pos')
	if '' ~= sPos then
		sAux = 'Target: ' .. sPos
	else
		-- yes, it should be "Remaining wear" but that's
		-- just too long on smaller screens
		sAux = 'Durability: ' .. sWear
			.. '  ' .. fRemainingPercent .. '%'
	end

	---------------------------------------------------------------
	-- here you can comment out lines you don't want or add more --
	-- depending on what you are interested in seeing in HUD     --
	---------------------------------------------------------------
	return output
		.. '\n' .. (sDescription or sItemstring)
		.. '\n' .. iCount .. ' ' .. sItemstring
		.. '\n' .. sAux
		.. '\n'
end -- update


tmi.addModule({
	id = 'wieldedItem',
	title = 'wieldedItem',
	onUpdate = update,
	value = 'wieldedItem',
})

--print('module wieldedItem loaded')
