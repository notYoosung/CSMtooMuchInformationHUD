local bound = vector.new(16, 8, 16)

local tmi_interval = tmi.conf.interval
local update_interval = 5
local update_counter = 5
local prev_player_pos = nil

local meta_inv_wps = {}

-- local player_pos_equals_prev
-- local prev_find_nodes_with_meta
local function update()
    if update_counter >= update_interval then
        update_counter = 1
    else
        update_counter = update_counter + 1
        local output = ""

        local player_pos = tmi.player_pos
        player_pos_equals_prev = prev_player_pos and vector.equals(vector.round(prev_player_pos), vector.round(player_pos))
        if --[[tmi.csm_restrictions.lookup_nodes and]] player_pos then
            local pos_min = vector.subtract(player_pos, bound)
            local pos_max = vector.add(player_pos, bound)
            --[[local find_names = tmi.store:get_string("tmi:nodeSearch_find_names")
            local found_names = {}

            local nodes = {}

            for x = pos_min.x, pos_max.x do
                for y = pos_min.y, pos_max.y do
                    for z = pos_min.z, pos_max.z do
                        local node = core.get_node_or_nil({ x = x, y = y, z = z })
                        -- {name="node_name", param1=0, param2=0}
                        if node then
                            local nname = node.name
                            for _, find_name in ipairs(string.split(find_names, ",%s-", true, 2048, true)) do
                                if nname == find_name or string.gsub(nname, "^-*:(.*)", "%1") == find_name then
                                    found_names[find_name] = (found_names[find_name] or 0) + 1
                                end
                            end

                            nodes[x .. "," .. y .. "," .. z] = node
                        end
                    end
                end
            end

            for name, pos in pairs(found_names) do
                output = output .. "\n" .. tostring(name) .. " x" .. (#pos or 0) .. "    "
            end]]



            
            local meta_nodes
            -- if player_pos_equals_prev and prev_find_nodes_with_meta then
            --     meta_nodes = prev_find_nodes_with_meta
            -- else
                meta_nodes = core.find_nodes_with_meta(pos_min, pos_max)
            -- end
            if meta_nodes then
                for k, node_pos in pairs(meta_nodes) do
                    local node_meta = core.get_meta(node_pos)
                    if node_meta then
                        local nm = node_meta:to_table()
                        if nm then
                            local inv
                            if nm.inventory then
                                if nm.inventory.main then
                                    inv = nm.inventory.main
                                end
                            end
                            if inv then
                                local itemstring = nil
                                for _, item in pairs(inv) do
                                    local item_name = item:get_name()
                                    if item_name ~= "" then
                                        if itemstring == nil then
                                            itemstring = item_name
                                        elseif itemstring ~= nil and itemstring ~= item_name then
                                            itemstring = nil
                                            break
                                        end
                                    end
                                end
                                if itemstring then
                                    local itemdef = core.get_item_def(itemstring)
                                    if itemdef then
                                        local texture = (itemdef.inventory_image ~= "" and itemdef.inventory_image) or (itemdef.wield_image ~= "" and itemdef.wield_image)
                                        if texture then
                                            minetest.add_particle({
                                                pos = vector.offset(node_pos, 0, 0.75, 0),
                                                velocity = { x = 0, y = 0, z = 0 },
                                                acceleration = { x = 0, y = 0, z = 0 },
                                                expirationtime = update_interval * tmi_interval,
                                                size = 7.5,
                                                collisiondetection = false,
                                                collision_removal = false,
                                                object_collision = false,
                                                vertical = not false,
                                                texture = texture,
                                                glow = 14,
                                            })
                                        else

                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- prev_find_nodes_with_meta = meta_nodes
            -- prev_player_pos = player_pos
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
