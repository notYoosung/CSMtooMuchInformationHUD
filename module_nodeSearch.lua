local bound = vector.new(10, 6, 10)

local tmi_interval = tmi.conf.interval
local update_counter_interval = 3
local update_counter = 0
local prev_player_pos = nil

local meta_inv_wps = {}

-- local player_pos_equals_prev
-- local prev_find_nodes_with_meta
local function update()
    if update_counter > 1 then
        update_counter = update_counter - 1
    else
        update_counter = update_counter_interval
        local output = ""


        for k, v in ipairs(meta_inv_wps) do
            tmi.player:hud_remove(v)
        end

        local player_pos = tmi.player_pos
        player_pos_equals_prev = prev_player_pos and
            vector.equals(vector.round(prev_player_pos), vector.round(player_pos))
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
                                    local texture, label
                                    if itemdef then
                                        texture = (itemdef.inventory_image ~= "" and itemdef.inventory_image) or
                                            (itemdef.wield_image ~= "" and itemdef.wield_image)
                                        if texture then
                                            minetest.add_particle({
                                                pos = vector.offset(node_pos, 0, 0.75, 0),
                                                velocity = { x = 0, y = 0, z = 0 },
                                                acceleration = { x = 0, y = 0, z = 0 },
                                                expirationtime = (update_counter_interval + 0.5) * tmi_interval,
                                                size = 7.5,
                                                collisiondetection = false,
                                                collision_removal = false,
                                                object_collision = false,
                                                vertical = not false,
                                                texture = texture,
                                                glow = 14,
                                            })
                                        end
                                    end
                                    label = (not texture and itemdef and itemdef.description) or nm.name
                                    if label then
                                        local n_above = core.get_node_or_nil(vector.offset(node_pos, 0, 1, 0))
                                        local n_above_def = n_above and n_above.name and core.get_node_def(n_above.name)
                                        if not n_above_def or (n_above_def and (n_above_def.sunlight_propogates or n_above_def.walkable == false)) then
                                            local display_text = string.gsub(label, "^(.-)\n.*", "%1")
                                            meta_inv_wps[#meta_inv_wps + 1] = tmi.player:hud_add({
                                                hud_elem_type = "waypoint",
                                                name = display_text, --"node_meta_inv_itemname_wp",
                                                world_pos = vector.offset(node_pos, 0, 0.75, 0),
                                                text = "",
                                                number = 0xffffaa,
                                                precision = 0,
                                                size = 10,
                                            })
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
