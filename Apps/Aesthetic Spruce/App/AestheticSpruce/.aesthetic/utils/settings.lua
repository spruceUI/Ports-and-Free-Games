--- Auto-restore: the theme model is saved on quit and loaded on start
local state = require("state")
local paths = require("paths")
local system = require("utils.system")
local themeFile = require("utils.theme_file")
local fail = require("utils.fail")

local settings = {}

settings.SOURCE_BUILTIN = "built-in"
settings.SOURCE_USER = "user"

function settings.saveToFile()
	local filePath = paths.USERDATA_SETTINGS_FILE
	if not filePath then
		return fail("No settings file path")
	end
	if not system.ensurePath(filePath) then
		return fail("Failed to create settings directory for " .. filePath)
	end
	local t = state.exportTheme()
	t.source = settings.SOURCE_USER
	return themeFile.write(filePath, t, "Aesthetic Spruce settings file")
end

function settings.loadFromFile()
	local filePath = paths.USERDATA_SETTINGS_FILE
	if not filePath or not system.isFile(filePath) then
		return false -- first run
	end
	local t = themeFile.read(filePath)
	if not t then
		return false
	end
	return state.importTheme(t)
end

return settings
