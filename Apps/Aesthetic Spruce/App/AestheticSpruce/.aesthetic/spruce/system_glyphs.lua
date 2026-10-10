--- System icon families, glyphs and display names for the generated icons/ tiles
---
--- Ids are PyUI's Emu/ folder names as found in the SPRUCE theme (icons/<id>.png).
--- Families map to one glyph each so a tile says "handheld" / "TV console" / "arcade" /
--- "computer" at a glance; PyUI draws the system's name under the tile. Engines and ports keep a
--- specific glyph. "@handheld", "@console" and "@tv" are drawn procedurally by the icon renderer
--- (Lucide has no handheld or console unit); every other name must exist in
--- assets/icons/lucide/glyph/ or lucide/ui/.
local glyphs = {}

glyphs.default = "gamepad-2"

glyphs.familyGlyph = {
	handheld = "@handheld",
	console = "@console",
	arcade = "joystick",
	computer = "computer",
}

glyphs.families = {
	handheld = {
		"gb", "gbc", "gba", "gg", "lynx", "ngp", "ngpc", "ws", "wsc", "supervision", "megaduck", "poke",
		"psp", "nds", "dsi", "vb", "gw", "j2me",
	},
	console = {
		"fc", "fds", "sfc", "sgb", "sufami", "msu1", "satella", "n64", "md", "ms", "32X", "segasgone", "msumd",
		"pce", "sgfx", "neogeo", "vdp", "ps", "saturn", "dc", "segacd", "neocd", "pcecd",
		"atari", "5200", "7800", "jaguar", "col", "itv", "ody", "fairchild", "vectrex",
	},
	arcade = { "arcade", "mame", "fbneo", "cps1", "cps2", "cps3", "naomi", "atomiswave" },
	computer = { "amiga", "c64", "vic20", "cpc", "msx", "x68000", "zxs", "atarist", "atari800", "dos", "coco", "pc98" },
}

-- engines, ports and oddballs that are not a device
glyphs.overrides = {
	ports = "package", doom = "crosshair", quake = "crosshair", wolf = "crosshair", openbor = "flame",
	scummvm = "book-open", easyrpg = "book-text", ffplay = "clapperboard", pico = "sparkles",
	tic = "sparkles", fake08 = "sparkles", chai = "coffee", arduboy = "circuit-board", gametank = "cpu",
	["mkxp-z"] = "shapes", dos = "terminal",
}

glyphs.apps = {
	backup = "archive", bootlogo = "image", cheevos = "trophy", emufresh = "refresh-ccw", ereader = "book-open",
	expertappswitch = "sliders-horizontal", file = "folder", firmwareupdate = "hard-drive-upload",
	fnkey = "keyboard", gallery = "images", gamelist = "list-ordered", iconfresh = "sparkles",
	led = "lightbulb", menuswitch = "layout-grid", moonlight = "monitor-smartphone", pico8 = "sparkles",
	portmaster = "package", ppsspp = "gamepad", random = "shuffle", recents = "history",
	restore = "database-backup", retroarch = "joystick", retroexpert = "wrench", rtc = "clock",
	scraper = "images", sftpgo = "hard-drive", songo = "music", SSH = "terminal", syncthing = "refresh-cw",
	themegallery = "palette", updater = "download", usb = "usb",
	aestheticspruce = "moon-star",
}

-- Display names (what PyUI shows), used for the "Letter" icon style
glyphs.names = {
	["32X"] = "32X", ["5200"] = "Atari 5200", ["7800"] = "Atari 7800", amiga = "Amiga", arcade = "Arcade",
	arduboy = "Arduboy", atari800 = "Atari 800", atari = "Atari 2600", atarist = "Atari ST",
	atomiswave = "Atomiswave", c64 = "Commodore 64", chai = "ChaiLove", coco = "CoCo", col = "ColecoVision",
	cpc = "Amstrad CPC", cps1 = "CPS-1", cps2 = "CPS-2", cps3 = "CPS-3", dc = "Dreamcast", doom = "Doom",
	dos = "DOS", dsi = "DSi", easyrpg = "EasyRPG", fairchild = "Channel F", fake08 = "FAKE-08", fbneo = "FBNEO",
	fc = "NES", fds = "Famicom Disk System",
	ffplay = "Video", gametank = "Game Tank", gba = "Game Boy Advance", gbc = "Game Boy Color", gb = "Game Boy",
	gg = "Game Gear", gw = "Game & Watch", itv = "Intellivision", j2me = "J2ME", jaguar = "Jaguar", lynx = "Lynx",
	mame = "MAME", md = "Genesis", megaduck = "Mega Duck", ["mkxp-z"] = "MKXP-Z", ms = "Master System",
	msu1 = "MSU-1", msumd = "MSU-MD", msx = "MSX", n64 = "Nintendo 64", naomi = "Naomi", nds = "Nintendo DS",
	neocd = "Neo Geo CD", neogeo = "Neo Geo", ngpc = "Neo Geo Pocket Color", ngp = "Neo Geo Pocket",
	ody = "Odyssey 2", openbor = "OpenBOR", pc98 = "PC-98", pcecd = "PC Engine CD", pce = "PC Engine",
	pico = "PICO-8", poke = "Pokemon Mini", ports = "Ports", ps = "PlayStation", psp = "PSP", quake = "Quake",
	satella = "Satellaview", saturn = "Saturn", scummvm = "ScummVM", segacd = "Sega CD", segasgone = "SG-1000",
	sfc = "Super Nintendo", sgb = "Super Game Boy", sgfx = "SuperGrafx", sufami = "Sufami Turbo",
	supervision = "Supervision", tic = "TIC-80", vb = "Virtual Boy", vdp = "VDP", vectrex = "Vectrex",
	vic20 = "VIC-20", wolf = "Wolfenstein 3D", wsc = "WonderSwan Color", ws = "WonderSwan", x68000 = "X68000",
	zxs = "ZX Spectrum",
}

local familyOf = {}
for family, ids in pairs(glyphs.families) do
	for _, id in ipairs(ids) do
		familyOf[id] = family
	end
end

function glyphs.familyFor(id)
	return familyOf[id]
end

function glyphs.forSystem(id)
	if glyphs.overrides[id] then
		return glyphs.overrides[id]
	end
	local family = familyOf[id]
	if family then
		return glyphs.familyGlyph[family]
	end
	return glyphs.default
end

function glyphs.forApp(name)
	return glyphs.apps[name] or "layout-grid"
end

function glyphs.nameFor(id)
	return glyphs.names[id] or id
end

--- First letter of the display name, for the "Letter" icon style ("Saturn" -> "S")
function glyphs.letterFor(id)
	local name = glyphs.nameFor(id)
	local first = name:match("%w")
	return first and first:upper() or "?"
end

return glyphs
