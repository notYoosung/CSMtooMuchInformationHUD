local bound = vector.new(8, 8, 8)

local update_interval = 5
local update_counter = 5
local function update()
    if update_counter >= update_interval then
        update_counter = 1
    else
        update counter = update_counter + 1
        local player_pos = tmi.player_pos
        if tmi.csm_restrictions.lookup_nodes and player_pos then
            local find_names = tmi.store:get_string("tmi:nodeSearch_find_names")
            
            local nodes = {}

            local pos_min = vector.subtract(player_pos, bound)
            local pos_max = vector.add(player_pos, bound)
            for x = pos_min.x, pos_max.x do
                for y = pos_min.y, pos_max.y do
                    for z = pos_min.z, pos_max.z do
                        local node = core.get_node_or_nil({x = x, y = y, z = z})
                        -- {name="node_name", param1=0, param2=0}
                        nodes[x .. "," .. y .. "," .. z] = node
                    end
                end
            end
        end
    end
end


tmi.addModule({
	id = 'nodeSearch',
	title = 'nodeSearch',
	value = 'nodeSearch',
	onUpdate = update,
})
