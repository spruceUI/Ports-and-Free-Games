--- Path constants (spruceOS)
---
--- Environment contract (set by launch.sh on device, dev_launch.sh on a workstation):
---   WIDTH / HEIGHT        logical landscape screen size (DISPLAY_WIDTH x DISPLAY_HEIGHT)
---   ROTATION              DISPLAY_ROTATION in degrees (0, 90, 180, 270); the app renders a
---                         logical WIDTHxHEIGHT canvas and rotates it like PyUI does
---   ROOT_DIR              the app directory (App/AestheticSpruce); holds userdata/ and logs
---   SOURCE_DIR            the Lua/asset tree the love binary runs (ROOT_DIR/.aesthetic)
---   THEME_PRESETS_DIR     built-in presets (SOURCE_DIR/presets)
---   SPRUCE_THEMES_DIR     where PyUI themes live (/mnt/SDCARD/Themes)
---   SPRUCE_SYSTEM_JSON    the per-device system json whose "theme" key names the active theme
---   SPRUCE_PLATFORM       spruce PLATFORM id (SmartProS, Flip, Miniloong, ...)
local system = require("utils.system")
local state = require("state")

local paths = {}

paths.SOURCE_DIR = system.getEnvironmentVariable("SOURCE_DIR")
paths.ROOT_DIR = system.getEnvironmentVariable("ROOT_DIR")
paths.THEME_PRESETS_DIR = system.getEnvironmentVariable("THEME_PRESETS_DIR")

paths.SPRUCE_PLATFORM = os.getenv("SPRUCE_PLATFORM") or "unknown"
paths.SPRUCE_THEMES_DIR = os.getenv("SPRUCE_THEMES_DIR")
	or (state.isDevMode and (paths.ROOT_DIR .. "/Themes") or "/mnt/SDCARD/Themes")
-- spruce's default theme; the "SPRUCE Art" and "SPRUCE Mono" icon styles recolour its system art
paths.SPRUCE_REFERENCE_THEME = os.getenv("SPRUCE_REFERENCE_THEME") or (paths.SPRUCE_THEMES_DIR .. "/SPRUCE")
paths.SPRUCE_SYSTEM_JSON = os.getenv("SPRUCE_SYSTEM_JSON")
	or (state.isDevMode and (paths.ROOT_DIR .. "/system.json") or nil)

paths.USERDATA_DIR = paths.ROOT_DIR .. "/userdata"
paths.USERDATA_THEME_PRESETS_DIR = paths.USERDATA_DIR .. "/presets"
paths.USERDATA_SETTINGS_FILE = paths.USERDATA_DIR .. "/settings.lua"

-- Themes are assembled here and moved into SPRUCE_THEMES_DIR/<name> when complete, so PyUI
-- never lists a half-written theme.
paths.WORKING_THEME_DIR = paths.ROOT_DIR .. "/theme_working"

-- Assets used by the app UI
paths.CONTROL_HINTS_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/icons/kenney_input_prompts"
paths.UI_ICON_PNG_DIR = paths.SOURCE_DIR .. "/assets/icons/png"
paths.UI_KOFI_QR_CODE_IMAGE = "assets/images/kofi_qrcode.png"

-- Assets copied into generated themes
paths.THEME_FONT_SOURCE_DIR = paths.SOURCE_DIR .. "/assets/fonts"
paths.THEME_PICTOGRAM_DIR = paths.SOURCE_DIR .. "/assets/icons/png/lucide/ui"

-- Files inside the working theme
paths.THEME_CONFIG = paths.WORKING_THEME_DIR .. "/config.json"
paths.THEME_CREDITS = paths.WORKING_THEME_DIR .. "/README.md"
paths.THEME_PREVIEW = paths.WORKING_THEME_DIR .. "/preview.png"

-- PyUI resolution sets. The base set (config.json + skin/ + icons/) is always 640x480; every
-- other size gets config_<W>x<H>.json + skin_<W>x<H>/ + icons_<W>x<H>/. These are the sizes
-- spruceOS devices actually run at (SPRUCE also ships 752x560, an muOS-era size, not used).
-- A size SPRUCE has no set for gets the base set only, which PyUI's ThemePatcher scales on the
-- device (themeCreator.targetResolutions); SPRUCE gained the Zero40's 480x800 set upstream, so that
-- panel is pre-baked again.
paths.BASE_RESOLUTION = "640x480"
paths.SUPPORTED_THEME_RESOLUTIONS = {
	"640x480", -- A30, Mini, Flip, Zero28, Pixel2, RG35XX-H/Plus/SP/2024, RG28XX
	"480x800", -- MagicX Zero 40 (portrait)
	"720x480", -- RG40XX-H/V
	"720x720", -- RGB30, RG CubeXX
	"960x720", -- Miniloong Pocket 1
	"1024x768", -- TrimUI Brick, Brick Pro, MagicX XU20
	"1280x720", -- TrimUI Smart Pro, Smart Pro S
}

function paths.resolutionSuffix(width, height)
	local res = string.format("%dx%d", width, height)
	if res == paths.BASE_RESOLUTION then
		return ""
	end
	return "_" .. res
end

function paths.getThemeConfigPath(width, height)
	local res = string.format("%dx%d", width, height)
	if res == paths.BASE_RESOLUTION then
		return paths.WORKING_THEME_DIR .. "/config.json"
	end
	return paths.WORKING_THEME_DIR .. "/config_" .. res .. ".json"
end

function paths.getThemeSkinDir(width, height)
	return paths.WORKING_THEME_DIR .. "/skin" .. paths.resolutionSuffix(width, height)
end

function paths.getThemeIconsDir(width, height)
	return paths.WORKING_THEME_DIR .. "/icons" .. paths.resolutionSuffix(width, height)
end

-- Helper to execute a function for a list of resolutions ("WxH" strings)
function paths.forEachResolution(resolutions, func)
	for _, resolution in ipairs(resolutions) do
		local width, height = resolution:match("(%d+)x(%d+)")
		width, height = tonumber(width), tonumber(height)
		local success, err = func(width, height)
		if not success then
			return false, err
		end
	end
	return true
end

return paths
