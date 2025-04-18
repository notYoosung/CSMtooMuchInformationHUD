-- module pos --
-- by SwissalpS --
-- displays player position in nodes and block coordinates
-- taken from [PosTool]

local C = core.colorize
local F = core.formspec_escape
local SER = core.serialize
local DES = core.deserialize

local sin = math.sin
local cos = math.cos
--[[
core.camera:
2025-02-11 17:15:43: [Main]: userdata metatable: {
	set_camera_mode = <function>,
	get_camera_mode = <function>,
	get_fov = <function>,
	get_offset = <function>,
	get_look_dir = <function>,
	get_look_vertical = <function>,
	get_look_horizontal = <function>,
	get_aspect_ratio = <function>,
	get_pos = <function>
}
]]
local camera = tmi.camera
local reach_length = 16
local empty_table_dump = dump({})
local empty_table_ser = SER({})
local empty_fields_table_dump = dump({ fields = {} })
local empty_fields_table_ser = SER({ fields = {} })


local function onInit()
    if tmi.player and tmi.player.set_yaw then
        tmi.can_set_look = true
        core.register_chatcommand("aim", {
            params = "<name> | (<x> <y> <z>) | (<x> <z>)",
            description = "aim at player or point",
            func = function(params)
                if params then
                    local param_table = params.split("[, ]-")
                    if #param_table == 1 then
                        if table.indexof(tmi.players, param_table[1]) then

                        else
                            local x = tonumber(param_table[1])
                            local y = tonumber(param_table[2])
                            local z = tonumber(param_table[3])
                            if #param_table == 2 then
                                if x ~= nil and y ~= nil then
                                    -- tmi.player()
                                end

                            end
                        end
                    end
                end
            end
        })
    end
end


local function update(index)
    if not camera then
        camera = tmi.camera
    end
    local output = ""

    local eye_pos = camera:get_pos()
    local look_offset = vector.multiply(camera:get_look_dir(), reach_length)
    local look_reach_pos = vector.add(eye_pos, look_offset)
    --[[core.add_particle({
        pos = look_reach_pos,
        velocity = vector.new(0, 0, 0),
        acceleration = vector.new(0, 0, 0),
        expirationtime = tmi.conf.interval,
        size = 5,
        texture = "mobs_mc_glow_squid_glint1.png",
        glow = core.LIGHT_MAX,
    })]]
    local ray = core.raycast(eye_pos, look_reach_pos, true, false)
    -- local playerent = ray:next()
    if ray then
        local pointed_thing = ray:next()
        if pointed_thing then
            tmi.pointed_thing = pointed_thing
            local type = pointed_thing.type
            if type == "node" then
                local node_pos = pointed_thing.under
                local node_meta = core.get_meta(node_pos)
                if node_meta then
                    local meta_table = node_meta:to_table()
                    -- output = output .. "Pointed Node Meta: " .. dump(meta_table)
                    local meta_table_dump = dump(meta_table)
                    if meta_table and meta_table_dump ~= empty_fields_table_dump then
                        local meta_fields = meta_table.fields
                        if meta_fields then
                            meta_table.fields.formspec = nil
                            if meta_fields.description then
                                meta_table.fields.description = meta_fields.description
                            end
                        end
                        local meta_inv = meta_table.inventory
                        if meta_inv then
                            meta_table.inventory = nil
                        end

                        if meta_fields then
                            local meta_fields_dump = dump(meta_fields)
                            if meta_fields_dump == empty_table_dump or meta_fields_dump == empty_fields_table_dump then
                                meta_table.fields = nil
                            end
                        end

                        local meta_table_dump_sorted = tmi.dump_sorted(meta_table)
                        if meta_table_dump_sorted ~= empty_table_dump then
                            output = output .. C("#eff", "\nPointed Node Meta: " .. meta_table_dump_sorted .. "\n")
                        end
                        if meta_inv then
                            for meta_inv_key, meta_inv_table in pairs(meta_inv) do
                                local dump_meta_inv = tmi.dump_meta_inv(meta_inv_table)
                                output = output ..
                                    C("#eff",
                                        "\nPointed Node Inv (" ..
                                        tostring(meta_inv_key) ..
                                        "): {\n" ..
                                        tostring(dump_meta_inv) --[[.. "\n" .. tostring(inv_indices)--]] .. "\n}\n")
                            end
                        end
                    end
                    -- output = output .. dump_meta_inv
                end
            elseif type == "object" then
                local id = pointed_thing.id
                output = output .. C("#eff", "\nPointed Entity Meta: " .. dump(id))
            end
        else
            tmi.pointed_thing = nil
        end
    end

    return tmi.strip_esc(output)
end -- update


tmi.addModule({
    id = 'pointed',
    title = 'pointed',
    value = 'pointed module',
    onInit = onInit,
    onUpdate = update,
})

--print('module pos loaded')










