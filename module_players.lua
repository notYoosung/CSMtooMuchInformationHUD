local function update(index)
    local player_names = core.get_player_names()
    if player_names then
        return "Players: " .. table.concat(player_names, ", ")
    else
        return ""
    end
end -- update


tmi.addModule({
    id = 'players',
    title = 'players',
    value = 'players module',
    onUpdate = update,
})
