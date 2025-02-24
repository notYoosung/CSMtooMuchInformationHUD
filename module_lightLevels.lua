--pointed



local function update(index)

    --core.get_node_light()

	return 'Light level: ' 
    
end -- update


tmi.addModule({
	id = 'lightLevels',
	title = 'light levels',
	value = 'lightLevels module',
	onUpdate = update,
})