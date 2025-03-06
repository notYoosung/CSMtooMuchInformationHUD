--last death pos; time
--cause?
--chat msg
--log?
--wp?

local function onInit()
    --[[core.register_on_death(function()
    end)--]]
    core.register_on_damage_taken(function(hp)
        if tmi.player then
            if tmi.player:get_hp() - hp <= 0 then
                if tmi.player_pos then
                    local death_pos = vector.round(tmi.player_pos)
                    if not tmi.last_death_pos or (tmi.last_death_pos and not vector.equals(death_pos, tmi.last_death_pos)) then
                        tmi.last_death_pos = death_pos
                        local death_msg = core.colorize("#E00000",
                            "You died at " .. core.pos_to_string(tmi.last_death_pos) .. ".")
                        core.log(death_msg)
                        if tmi.player then
                            tmi.player:hud_add({
                                type = "waypoint",
                                name = "death",
                                text = "",
                                precision = 10,
                                number = 0x00ff00,
                                world_pos = tmi.last_death_pos,
                                offset = { x = 0, y = 0, z = 0 },
                                alignment = { x = 0, y = 0 },
                            })
                        end
                    end
                end
            end
        end
    end)
end


local function update()
    if tmi.last_death_pos then
        return "Last death pos: " .. tostring(core.pos_to_string(tmi.last_death_pos))
    end
end

tmi.addModule({
    id = 'death',
    title = 'death',
    value = 'death',
    onInit = onInit,
    onUpdate = update,
})
