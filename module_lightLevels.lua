-- pointed above, below
-- head, feet
-- mark nodes with light level 0 ? will need particle displays & (frequent?) checks

local get_node_light = core.get_node_light()

local function update(index)
	local output = ""
	local pointed_thing = tmi.pointed_thing
	if pointed_thing then
		if pointed_thing.above then
			output = output .. string.format("Pointed Above Light Level: %02i", get_node_light(pointed_thing.above))
		end
		if pointed_thing.below then
			output = output .. string.format("Pointed Below Light Level: %02i", get_node_light(pointed_thing.below))
		end
	end
	output = output .. string.format("Head Light Level: %02i", get_node_light(vector.offset(tmi.player_pos, 0, 1, 0)))
	output = output .. string.format("Feet Light Level: %02i", get_node_light(tmi.player_pos))
    

	return output
    
end -- update


tmi.addModule({
	id = 'lightLevels',
	title = 'light levels',
	value = 'lightLevels module',
	onUpdate = update,
})