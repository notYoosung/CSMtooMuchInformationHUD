-- pointed above, under
-- head, feet
-- mark nodes with light level 0 ? will need particle displays & (frequent?) checks
-- core.find_nodes_in_area_under_air(pos1, pos2, nodenames)


local get_node_light_formatted = function(pos)
	local node_light = core.get_node_light(pos)
	if node_light == 0 then
		return minetest.colorize("#FF5555", "0")
	else
		return tostring(node_light)
	end
end

local light_update_interval = 5

local function update(index)
	if light_update_interval <= 1 then
		light_update_interval = 5
		local player_pos = tmi.player_pos
		if player_pos then
			local nodes_under_air = core.find_nodes_in_area_under_air(vector.offset(player_pos, -16, -8, -16), vector.offset(player_pos, 16, 8, 16))
		end

	else
		light_update_interval = light_update_interval - 1
	end

	local output = ""
	local pointed_thing = tmi.pointed_thing
	if pointed_thing then
		if pointed_thing.above then
			output = output .. "\n" .. "Pointed Above Light: " ..  get_node_light_formatted(pointed_thing.above)
		end
		if pointed_thing.under then
			output = output .. "\n" .. "Pointed Below Light: " ..  get_node_light_formatted(pointed_thing.under)
		end
	end
	if tmi.player_pos then
		output = output .. "\n" .. "Head Light: " ..  get_node_light_formatted(vector.offset(tmi.player_pos, 0, 1, 0))
		output = output .. "\n" .. "Feet Light: " ..  get_node_light_formatted(tmi.player_pos)
	end
    

	return output
    
end -- update


tmi.addModule({
	id = 'lightLevels',
	title = 'light levels',
	value = 'lightLevels module',
	onUpdate = update,
})