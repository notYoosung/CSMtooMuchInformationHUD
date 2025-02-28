--[[
.lua local lh = core.localplayer:get_last_look_horizontal() return dump(core.ui.minimap:set_pos(vector.offset(core.localplayer:get_pos(), 100 * math.cos(lh), 0, 100 * math.sin(lh))))
]]

