--- Headless build hook for tests and device smoke runs
---
--- AESTHETIC_AUTOBUILD=1   build the theme from the current (or preset) state, then quit
--- AESTHETIC_AUTOAPPLY=1   also write the "theme" key so PyUI loads it on restart
--- AESTHETIC_PRESET=<name> load a built-in/user preset before building
--- The result line "AUTOBUILD OK <dir>" / "AUTOBUILD FAIL <err>" goes to stdout (the session log).
local love = require("love")
local logger = require("utils.logger")
local state = require("state")

local autobuild = {}
local co = nil
local phase = nil

function autobuild.enabled()
	return os.getenv("AESTHETIC_AUTOBUILD") == "1"
end

function autobuild.start()
	-- log what the compatibility check would tell the user (headless runs never show the modal)
	local compat = require("spruce.compat")
	local result = compat.check()
	print("COMPAT " .. result.level .. ": " .. result.message:gsub("\n", " "))
	local presetName = os.getenv("AESTHETIC_PRESET")
	if presetName and presetName ~= "" then
		local presets = require("utils.presets")
		local ok = presets.loadPreset(presetName)
		print("AUTOBUILD preset " .. presetName .. ": " .. tostring(ok))
	end
	local themeCreator = require("theme_creator")
	co = themeCreator.createThemeCoroutine()
	phase = "build"
end

function autobuild.update()
	if not co then
		return
	end
	local ok, a, b = coroutine.resume(co)
	if not ok then
		print("AUTOBUILD FAIL " .. tostring(a))
		io.stdout:flush()
		co = nil
		love.event.quit(1)
		return
	end
	if coroutine.status(co) ~= "dead" then
		if type(a) == "string" then
			logger.debug("autobuild: " .. a)
		end
		return
	end
	if phase == "build" then
		if a and type(b) == "string" then
			print("AUTOBUILD OK " .. b)
			if os.getenv("AESTHETIC_AUTOAPPLY") == "1" then
				local themeCreator = require("theme_creator")
				local folder = b:gsub("/+$", ""):match("([^/\\]+)$")
				co = themeCreator.installThemeCoroutine(folder)
				phase = "apply"
				return
			end
		else
			print("AUTOBUILD FAIL " .. tostring(b))
			io.stdout:flush()
			co = nil
			love.event.quit(1)
			return
		end
	elseif phase == "apply" then
		print(a and "AUTOAPPLY OK" or ("AUTOAPPLY FAIL " .. tostring(b)))
		state.themeApplied = a and true or false
	end
	io.stdout:flush()
	co = nil
	love.event.quit(0)
end

return autobuild
