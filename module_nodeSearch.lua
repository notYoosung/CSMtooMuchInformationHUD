local bound = vector.new(8, 8, 8)

local update_interval = 5
local update_counter = 5
local function update()
    if update_counter >= update_interval then
        update_counter = 1
    else
        local output = ""

        update counter = update_counter + 1
        local player_pos = tmi.player_pos
        if tmi.csm_restrictions.lookup_nodes and player_pos then
            local find_names = tmi.store:get_string("tmi:nodeSearch_find_names")
            local found_names = {}

            local nodes = {}

            local pos_min = vector.subtract(player_pos, bound)
            local pos_max = vector.add(player_pos, bound)
            for x = pos_min.x, pos_max.x do
                for y = pos_min.y, pos_max.y do
                    for z = pos_min.z, pos_max.z do
                        local node = core.get_node_or_nil({x = x, y = y, z = z})
                        -- {name="node_name", param1=0, param2=0}
                        if node then
                            local nname = node.name
                            for _, find_name in ipairs(find_names) do
                                if nname == find_name or string.gsub(nname, "^-*:") == find_name then
                                    found_names[nname]
                            end

                            if node.name then
                                find[names]
                            end
                            nodes[x .. "," .. y .. "," .. z] = node
                        end
                    end
                end
            end
        end

        for name, pos in pairs(found_names) do
            output = output .. "\n" .. tostring(name) .. " x" .. (#pos or 0) .. "    "
        end

        return output
    end
end


tmi.addModule({
	id = 'nodeSearch',
	title = 'nodeSearch',
	value = 'nodeSearch',
	onUpdate = update,
})
