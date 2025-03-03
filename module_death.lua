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
