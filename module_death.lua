--last death pos; time
--cause?
--chat msg
--log?
--wp?
core.register_on_death(function()
    if tmi.player_pos then
        core.log("error", core.colorize("#E00000",  "You died at " .. core.pos_to_string(tmi.player_pos) .. "."))
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
