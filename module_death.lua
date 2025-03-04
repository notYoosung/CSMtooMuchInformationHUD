--last death pos; time
--cause?
--chat msg
--log?
--wp?
core.register_on_death(function()
    core.log("error", "died")
    core.display_chat_message("died")
    if tmi.player_pos then
        local death_msg = core.colorize("#E00000",  "You died at " .. core.pos_to_string(tmi.player_pos) .. ".")
        core.log("error", death_msg)
        core.display_chat_message(death_msg)
        tmi.last_death_pos = tmi.player_pos
        if tmi.player then
            tmi.player:hud_add({
                type = "waypoint",
                name = "death",
                text = "",
                precision = 10,
                number = 0x00ff00,
                world_pos = tmi.player_pos,
                offset = { x = 0, y = 0, z = 0 },
                alignment = { x = 0, y = 0 },
            })
        end
    end
end)



local function update()
    if tmi.last_death_pos then
        return "Last death pos: " .. tostring(core.pos_to_string(tmi.last_death_pos))
    end
end

tmi.addModule({
	id = 'death',
	title = 'death',
	value = 'death',
	onUpdate = update,
})
