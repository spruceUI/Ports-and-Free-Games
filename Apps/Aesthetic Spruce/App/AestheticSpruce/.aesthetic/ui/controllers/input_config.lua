-- InputConfig.lua
-- Centralized configuration for key/button mappings to logical UI actions

local InputConfig = {}

-- Default mapping: logical UI actions to Love2D key/gamepad names
InputConfig.default = {
	navigate_up = { keyboard = { "up" }, gamepad = { "dpup" } },
	navigate_down = { keyboard = { "down" }, gamepad = { "dpdown" } },
	navigate_left = { keyboard = { "left" }, gamepad = { "dpleft" } },
	navigate_right = { keyboard = { "right" }, gamepad = { "dpright" } },
	confirm = { keyboard = { "z" }, gamepad = { "a" } },
	cancel = { keyboard = { "x" }, gamepad = { "b" } },
	undo = { keyboard = { "a" }, gamepad = { "y" } },
	clear = { keyboard = { "s" }, gamepad = { "x" } },
	swap_cursor = { keyboard = { "tab" }, gamepad = { "y" } }, -- TODO: This is not a good name
	tab_left = { keyboard = { "q" }, gamepad = { "leftshoulder" } },
	tab_right = { keyboard = { "w" }, gamepad = { "rightshoulder" } },
	open_menu = { keyboard = { "return" }, gamepad = { "start" } },
}

-- Allow for user override in the future
InputConfig.current = InputConfig.default

return InputConfig
