local bound = vector.new(16, 12, 16)

local tmi_interval = tmi.conf.interval
local update_counter_interval = 3
local update_counter = 0
local prev_player_pos = nil

local node_search_wps = {}
local meta_inv_wps = {}

-- local player_pos_equals_prev
-- local prev_find_nodes_with_meta

local node_table = {
    "default:stone_with_diamond",
    "default:mese",
    "moreores:mineral_mithril"
}

local ns_store_id = "tmi:nodeSearch_node_names"
local ret = ""
local function init()
    local nn = tmi.store:get_string(ns_store_id)
    if not nn or (nn and nn == "") then
        tmi.store:set_string(ns_store_id, table.concat(node_table, ","))
    end

    -- chatcommand to add or remove an itemstring in the node search list
    core.register_chatcommand("ns", {
        params = "<add/remove> <itemstring>",
        description = "Add or remove itemstring in node search list.",
        func = function(param)
            local node_names = tmi.store:get_string(ns_store_id)
            local subcmds = string.split(param, " +", false, 1024, true)
            if node_names --[[and node_names ~= ""]] then
                local node_names_table = string.split(node_names, ",")
                -- core.display_chat_message(dump(subcmds))
                local sc1 = subcmds[1]
                local sc2 = subcmds[2]
                if sc1 then
                    if sc2 == nil then
                        local pointed = tmi.pointed_thing
                        if pointed and pointed.type == "node" then
                            local ndef = core.get_node_or_nil(pointed.under)
                            if ndef then
                                sc2 = ndef.name
                            end
                        end
                    end
                    if sc2 then
                        if sc1 == "add" then
                            core.display_chat_message("Adding: " .. tostring(sc2))
                            if table.indexof(node_names_table, sc2) == -1 then
                                node_names_table[#node_names_table + 1] = sc2
                                core.display_chat_message("\"" .. tostring(sc2) .. "\" added to node search list.")
                            else
                                core.display_chat_message("\"" .. tostring(sc2) .. "\" already in node search list.")
                            end
                        elseif sc1 == "remove" then
                            local index_of = table.indexof(node_names_table, sc2)
                            if index_of ~= -1 then
                                table.remove(node_names_table, index_of)
                                core.display_chat_message("\"" .. tostring(sc2) .. "\" removed from node search list.")
                            end
                        end
                    end
                end
                core.display_chat_message(dump(node_names_table))
                tmi.store:set_string(ns_store_id, table.concat(node_names_table, ","))
            end
        end,
    })


    core.register_chatcommand("pt", {
        params = "(<x> <y> <z>)|(<x> <z>)",
        description = "Create a waypoint at a coordinate.",
        func = function(param)
            local p = tmi.player
            if p then
                local subcmds = string.split(param, "[, ]+", false, 1024, true)
                local player_pos = tmi.player_pos
                if player_pos then
                    player_pos = vector.round(player_pos)
                    local x, y, z
                    if #subcmds == 3 then
                        x = core.parse_relative_number(subcmds[1], player_pos.x)
                        y = core.parse_relative_number(subcmds[2], player_pos.y)
                        z = core.parse_relative_number(subcmds[3], player_pos.z)
                    elseif #subcmds == 2 then
                        x = core.parse_relative_number(subcmds[1], player_pos.x)
                        y = player_pos.y
                        z = core.parse_relative_number(subcmds[2], player_pos.z)
                    elseif #subcmds == 0 then
                        x = player_pos.x
                        y = player_pos.y
                        z = player_pos.z
                    end
                    if x ~= nil and y ~= nil and z ~= nil then
                        p:hud_add({
                            hud_elem_type = "waypoint",
                            name = "○", --"•", -- •○◦⦾⦿¤·■⌂☼▼◘◙⁃      ⌖𖥠𐀏⊹₊𖣓𖣨⊹𖣠☩     ✦✧✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋❌❍❎❏❐
                            world_pos = vector.new(x, y, z),
                            text = "",
                            number = 0xdc143c,
                            precision = 10,
                            size = 10,
                        })
                    end
                end
            end
        end,
    })
end

local function update()
    if update_counter > 1 then
        update_counter = update_counter - 1
    else
        update_counter = update_counter_interval
        local output = ""


        for k, v in ipairs(node_search_wps) do
            tmi.player:hud_remove(v)
            node_search_wps[k] = nil
        end
        for k, v in ipairs(meta_inv_wps) do
            tmi.player:hud_remove(v)
            meta_inv_wps[k] = nil
        end

        local player_pos = tmi.player_pos
        player_pos_equals_prev = prev_player_pos and
            vector.equals(vector.round(prev_player_pos), vector.round(player_pos))
        if --[[tmi.csm_restrictions.lookup_nodes and]] player_pos then
            local pos_min = vector.subtract(player_pos, bound)
            local pos_max = vector.add(player_pos, bound)
            local node_names = tmi.store:get_string("tmi:nodeSearch_node_names")

            if node_names and node_names ~= "" then
                local node_names_table = string.split(node_names, ",")
                local nodes_in_area = core.find_nodes_in_area(pos_min, pos_max, node_names_table, true)


                for name, positions in pairs(nodes_in_area) do
                    for __, pos in ipairs(positions) do
                        meta_inv_wps[#meta_inv_wps + 1] = tmi.player:hud_add({
                            hud_elem_type = "waypoint",
                            -- TODO: vary symbol by dist
                            name = "○", -- •○◦⦾⦿¤·■⌂☼▼◘◙⁃      ⌖𖥠𐀏⊹₊𖣓𖣨⊹𖣠☩     ✦✧✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋❌❍❎❏❐
                            world_pos = pos,
                            text = "",
                            number = 0xdc143c,
                            precision = 0,
                            size = 10,
                        })
                    end

                    output = output .. "\n" .. tostring(name) .. " x" .. (#positions or 0) .. "    "
                end
            end



            local meta_nodes
            -- if player_pos_equals_prev and prev_find_nodes_with_meta then
            --     meta_nodes = prev_find_nodes_with_meta
            -- else
            meta_nodes = core.find_nodes_with_meta(pos_min, pos_max)
            -- end
            if meta_nodes then
                for k, node_pos in pairs(meta_nodes) do
--                local meta_node_def = core.get_node_or_nil(node_pos)
--                   if meta_node_def andt
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


        ret = output
    end
    return ret
end


tmi.addModule({
    id = 'nodeSearch',
    title = 'nodeSearch',
    value = 'nodeSearch',
    onInit = init,
    onUpdate = update,
})

--[[
.lua return dump(core.get_item_def(core.localplayer:get_wielded_item():get_name()))
]]
