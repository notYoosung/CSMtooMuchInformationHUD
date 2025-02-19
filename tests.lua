
local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local C = core.colorize
local function get_slot(x, y, size, texture)
	local t = "image[" .. x - size .. "," .. y - size .. ";" .. 1 + (size * 2) ..
		"," .. 1 + (size * 2) .. ";" .. (texture and texture or "mcl_formspec_itemslot.png") .. "]"
	return t
end

local function get_itemslot_bg_v4(x, y, w, h, size, texture)
	if not size then
		size = 0.05
	end
	local out = ""
	for i = 0, w - 1, 1 do
		for j = 0, h - 1, 1 do
			out = out .. get_slot(x + i + (i * 0.25), y + j + (j * 0.25), size, texture)
		end
	end
	return out
end

local formspec_ender_chest = table.concat({
	"formspec_version[4]",
	"size[11.75,10.425]",

	"label[0.375,0.375;" .. F(C("#313131", S("Ender Chest"))) .. "]",
	get_itemslot_bg_v4(0.375, 0.75, 9, 3),
	"list[current_player;enderchest;0.375,0.75;9,3;]",
	"label[0.375,4.7;" .. F(C("#313131", S("Inventory"))) .. "]",
	get_itemslot_bg_v4(0.375, 5.1, 9, 3),
	"list[current_player;main;0.375,5.1;9,3;9]",

	get_itemslot_bg_v4(0.375, 9.05, 9, 1),
	"list[current_player;main;0.375,9.05;9,1;]",

	"listring[current_player;enderchest]",
	"listring[current_player;main]",
})
core.show_formspec("mcl_chests:ender_chest_" .. core.localplayer:get_name(), formspec_ender_chest)
