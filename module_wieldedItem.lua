-- module wieldedItem --
-- by SwissalpS --
-- shows some info about wielded item. Updating
-- frequently so you can E.g. watch your dig count
-- of tool or level continuesly.
local C = minetest.colorize
local F = minetest.formspec_escape
local SER = minetest.serialize
local DES = minetest.deserialize


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
			output = C("#eff", "\nWielded Item Meta: " .. tostring(tmi.dump_sorted(meta_table)):gsub("\\?27%([cT].-%)", ""):gsub("\\?27[FE]", "") .. "\n")
			if meta_inv_serialized then
				output = C("#eff",
					"\nWielded Item Inv: " ..
					tmi.dump_sorted(DES(meta_inv_serialized)) .. "\n" .. tostring(inv_indices) .. "\n")
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
