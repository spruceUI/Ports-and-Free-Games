--- Screen tour: AESTHETIC_TOUR=1 visits every screen, presses buttons on the option screens and
--- checks the theme model changed, then quits (device smoke test).
---
--- Input is injected by shadowing love.keyboard.isDown with the keys InputConfig maps to actions
--- ("right" = navigate_right), so the real List/Button input path is exercised. Lines:
---   TOUR enter <screen> | TOUR check <field> <before> -> <after> | TOUR FAIL <why> | TOUR OK
local love = require("love")
local state = require("state")

local tour = {}

local held = {}
local realIsDown = love.keyboard.isDown
love.keyboard.isDown = function(key, ...)
	if held[key] then
		return true
	end
	return realIsDown(key, ...)
end

-- step = { screen = name } or { screen = name, press = key, field = stateKey }
local STEPS = {
	{ screen = "main_menu" },
	{ screen = "home_screen_layout", press = "right", field = "homeScreenLayout" },
	{ screen = "background" },
	{ screen = "color_picker" },
	{ screen = "battery" },
	{ screen = "font_family" },
	{ screen = "icons", press = "right", field = "systemIcons" },
	{ screen = "bars", press = "right", field = "showTopBarText" },
	{ screen = "box_art_width", press = "right", field = "boxArtWidth" },
	{ screen = "spruce_options", press = "right", field = "gameListView" },
	{ screen = "settings" },
	{ screen = "load_preset" },
	{ screen = "about" },
	{ screen = "virtual_keyboard" },
	{ screen = "main_menu" },
}
local T_PRESS, T_RELEASE, T_CHECK, T_NEXT = 0.5, 0.65, 1.0, 1.1
local index, timer, before, failed = 0, 0, nil, false

function tour.enabled()
	return os.getenv("AESTHETIC_TOUR") == "1"
end

local function say(line)
	print(line)
	io.stdout:flush()
end

local function enter(step)
	state.activeColorContext = "background"
	state.previousScreen = "main_menu"
	before = step.field and state[step.field]
	say("TOUR enter " .. step.screen)
	require("screens").switchTo(step.screen)
end

function tour.update(dt)
	local step = STEPS[index]
	if not step then
		index = 1
		timer = 0
		enter(STEPS[1])
		return
	end
	timer = timer + dt
	if step.press then
		if timer >= T_PRESS and timer < T_RELEASE then
			held[step.press] = true
		else
			held[step.press] = nil
		end
		if timer >= T_CHECK and not step.checked then
			step.checked = true
			local after = state[step.field]
			say(string.format("TOUR check %s %s -> %s", step.field, tostring(before), tostring(after)))
			if after == before then
				failed = true
				say("TOUR FAIL " .. step.field .. " did not change after pressing " .. step.press)
			end
		end
	end
	if timer >= T_NEXT then
		index = index + 1
		timer = 0
		if index > #STEPS then
			say(failed and "TOUR FAILED" or "TOUR OK")
			love.event.quit(failed and 1 or 0)
			return
		end
		enter(STEPS[index])
	end
end

return tour
