--- spruceOS compatibility check
---
--- This app writes files that only PyUI's theme loader understands, so it is tied to the spruceOS
--- release families it was built and tested against. launch.sh exports SPRUCE_VERSION (from
--- helperFunctions.sh get_version, i.e. /mnt/SDCARD/spruce/spruce) and SPRUCE_VERSION_COMPLEX
--- (nightly tag if any). check() returns { level = "ok" | "warn", message = ... }; a warning is
--- shown once on the main menu and the user may continue.
local compat = {}

-- Base versions this build was verified on (hardware runs, theme loaded by PyUI)
compat.TESTED_VERSIONS = { "4.3.6", "4.4.0", "4.4.3", "4.5.3" }
-- Release families (major.minor) whose PyUI theme format this build targets. PyUI's
-- themes/theme.py and theme_patcher.py read the same layout from 4.3.0 to 4.5.3, and 4.5.2 stable
-- carries a theme loader byte-identical to the 4.5.3 nightly; 4.3.3 added the
-- optional screensaver.lowPowerWhileIdle, 4.4.0 the optional screensaver.dimBacklight and
-- screensaver.widgets, 4.4.3 the optional ic-cheevos-mark and 4.5 the three bluetooth status icons
-- (all fall back to a PyUI or stock-theme default when a theme omits them).
compat.SUPPORTED_FAMILIES = { "4.3", "4.4", "4.5" }

local PYUI_THEME_LOADER = "/mnt/SDCARD/App/PyUI/main-ui/themes/theme.py"
-- Strings the loader must still contain for the generated layout to be understood
local PYUI_SENTINELS = { 'config_{width}x{height}.json', '"skin"', '"icons"', "bg-list-l", "grid-game-selected", "tips-bar-bg" }

local function parseVersion(v)
	if type(v) ~= "string" then
		return nil
	end
	local major, minor, patch = v:match("^(%d+)%.(%d+)%.?(%d*)")
	if not major then
		return nil
	end
	return { major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch) or 0, family = major .. "." .. minor }
end

local function isSupportedFamily(family)
	for _, supported in ipairs(compat.SUPPORTED_FAMILIES) do
		if family == supported then
			return true
		end
	end
	return false
end

--- "4.3.x or 4.4.x"
function compat.supportedFamiliesText()
	local parts = {}
	for i, family in ipairs(compat.SUPPORTED_FAMILIES) do
		parts[i] = family .. ".x"
	end
	if #parts < 3 then
		return table.concat(parts, " or ")
	end
	return table.concat(parts, ", ", 1, #parts - 1) .. " or " .. parts[#parts]
end

local function readFile(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

function compat.currentVersion()
	local complex = os.getenv("SPRUCE_VERSION_COMPLEX")
	local base = os.getenv("SPRUCE_VERSION")
	if complex and complex ~= "" and complex ~= "0" then
		return complex, base
	end
	return base, base
end

function compat.check()
	-- Test hook: always warn, so dev runs and device tours exercise the warning modal
	if os.getenv("AESTHETIC_COMPAT_WARN") == "1" then
		return { level = "warn", message = "Compatibility warning forced by AESTHETIC_COMPAT_WARN=1.\n\nContinue anyway?" }
	end
	if os.getenv("DEV") == "true" then
		return { level = "ok", message = "dev mode" }
	end
	local shown, base = compat.currentVersion()
	local parsed = parseVersion(base)
	local tested = table.concat(compat.TESTED_VERSIONS, ", ")
	local problems = {}

	if not parsed then
		problems[#problems + 1] = "The spruceOS version could not be read (expected /mnt/SDCARD/spruce/spruce)."
	elseif not isSupportedFamily(parsed.family) then
		problems[#problems + 1] = string.format(
			"This build targets spruceOS %s (tested on %s) but this card runs %s.",
			compat.supportedFamiliesText(), tested, tostring(shown))
	end

	local loader = readFile(PYUI_THEME_LOADER)
	if not loader then
		problems[#problems + 1] = "PyUI's theme loader was not found; this does not look like a spruceOS card that can use generated themes."
	else
		for _, sentinel in ipairs(PYUI_SENTINELS) do
			if not loader:find(sentinel, 1, true) then
				problems[#problems + 1] = "PyUI's theme loader has changed since this build was made; generated themes may not load correctly."
				break
			end
		end
	end

	if #problems == 0 then
		return { level = "ok", message = "spruceOS " .. tostring(shown) }
	end
	return {
		level = "warn",
		message = table.concat(problems, "\n\n") .. "\n\nThemes made here may look wrong or fail to load. Continue anyway?",
	}
end

return compat
