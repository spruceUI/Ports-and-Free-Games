--- Which skin assets a generated theme emits, and how each is drawn.
---
--- PyUI (App/PyUI/main-ui) loads ~45 named files from skin/ (grep of every "<name>.qoi|png"
--- literal in its source, 2026-09). Everything else in the 189-file SPRUCE skin is legacy stock
--- MainUI art that PyUI never reads, so it is not generated. Dimensions come from
--- src/spruce/skin_spec.lua (generated from SPRUCE), which is the per-resolution layout contract.
---
--- kinds:
---   background  full-screen solid or gradient
---   bar         full-width bar tinted with the foreground when the state flag in `visible` is set
---   plate       filled rounded rectangle (the "selected" look: foreground fill)
---   frame       rounded outline only (grid selection ring)
---   panel       popup/keyboard panel: background fill with a foreground outline
---   empty       transparent (keeps layout offsets identical to SPRUCE)
---   pictogram   tinted icon PNG centred in the asset (status icons, buttons, missing image)
---   tile        main-menu tile: a square plate with a pictogram in the TOP of the image; the bottom
---               band stays transparent because PyUI draws the label there (grid_view.py y_text =
---               310/480 of the screen); the focused variant inverts the colours
return {
	-- full = true: sized to the screen, not to SPRUCE's file (SPRUCE ships a 960x720 background in
	-- its 1280x720 set; PyUI's ThemePatcher rule, which spruce's prebake --check enforces, is WxH)
	["background"] = { kind = "background", full = true },

	["bg-title"] = { kind = "bar", visible = "showTopBarText" },
	["tips-bar-bg"] = { kind = "bar", visible = "showBottomBar" },

	["bg-list-l"] = { kind = "plate", radius = 10 },
	["bg-list-s"] = { kind = "plate", radius = 8 },
	["bg-list-s2"] = { kind = "plate", radius = 8 },
	["list-item-select-bg-short"] = { kind = "plate", radius = 8 },
	["bg-btn-01-f"] = { kind = "plate", radius = 8 },
	["bg-btn-01-n"] = { kind = "frame", radius = 8, width = 1, alpha = 0.35 },
	-- multi-row grids (systems, box-art game grids) draw this behind the selected cell at 1.05x; a thin
	-- frame reads as one cue with the inverted tile and is the only cue box art has
	["bg-game-item-f"] = { kind = "frame", radius = 14, width = 2, alpha = 0.9 },
	["bg-game-item-n"] = { kind = "empty" },
	-- single-row grids (the main menu) draw this behind the selected tile at 1.05x; the tile itself
	-- already inverts, so a second cue only clutters
	["bg-game-item-single-f"] = { kind = "frame", radius = 14, width = 2, alpha = 0.9, like = "bg-game-item-f" },
	["grid-game-selected"] = { kind = "frame", radius = 14, width = 4 },
	["grid-system-selected"] = { kind = "frame", radius = 14, width = 4, like = "grid-game-selected" },

	["bg-pop-menu-4"] = { kind = "panel", radius = 14 },
	["menu-6line-bg"] = { kind = "panel", radius = 14 },
	["bg-grid-s"] = { kind = "panel", radius = 14 },

	["missing_image"] = { kind = "pictogram", icon = "lucide/glyph/image", scale = 0.5, alpha = 0.6 },
	["ic-favorite-mark"] = { kind = "pictogram", icon = "lucide/glyph/star", scale = 0.9 },
	-- PyUI 4.4.3 marks games with achievements; a theme without it falls back to SPRUCE's own art
	["ic-cheevos-mark"] = { kind = "pictogram", icon = "lucide/glyph/trophy", scale = 0.9 },

	-- SPRUCE ships these two as transparent 640x54 strips (hides the hint); PyUI draws the image at
	-- its natural size and puts the text after it, so ours are compact buttons (dims at 640x480).
	["icon-A-54"] = { kind = "pictogram", icon = "kenney_input_prompts/steam_button_a", scale = 0.95, dims = { 36, 36 } },
	["icon-B-54"] = { kind = "pictogram", icon = "kenney_input_prompts/steam_button_b", scale = 0.95, dims = { 36, 36 } },
	["icon-START"] = { kind = "pictogram", icon = "kenney_input_prompts/steam_button_start_custom", scale = 0.9 },

	["icon-wifi-signal-01"] = { kind = "pictogram", icon = "lucide/glyph/wifi", alpha = 0.4 },
	["icon-wifi-signal-02"] = { kind = "pictogram", icon = "lucide/glyph/wifi", alpha = 0.6 },
	["icon-wifi-signal-03"] = { kind = "pictogram", icon = "lucide/glyph/wifi", alpha = 0.8 },
	["icon-wifi-signal-04"] = { kind = "pictogram", icon = "lucide/glyph/wifi" },
	["icon-wifi-locked"] = { kind = "pictogram", icon = "lucide/glyph/lock" },

	-- PyUI 4.5 picks one of these by connected-device kind (theme.py get_bluetooth_icon)
	["icon-bluetooth-default"] = { kind = "pictogram", icon = "lucide/glyph/bluetooth" },
	["icon-bluetooth-gamepad"] = { kind = "pictogram", icon = "lucide/glyph/gamepad-2" },
	["icon-bluetooth-headphone"] = { kind = "pictogram", icon = "lucide/glyph/headphones" },

	["ic-power-charge-0%"] = { kind = "pictogram", icon = "lucide/glyph/battery-charging", color = "batteryActive" },
	["ic-power-charge-25%"] = { kind = "pictogram", icon = "lucide/glyph/battery-charging", color = "batteryActive" },
	["ic-power-charge-50%"] = { kind = "pictogram", icon = "lucide/glyph/battery-charging", color = "batteryActive" },
	["ic-power-charge-75%"] = { kind = "pictogram", icon = "lucide/glyph/battery-charging", color = "batteryActive" },
	["ic-power-charge-100%"] = { kind = "pictogram", icon = "lucide/glyph/battery-charging", color = "batteryActive" },
	["power-0%-icon"] = { kind = "pictogram", icon = "lucide/glyph/battery-low", color = "batteryLow" },
	["power-20%-icon"] = { kind = "pictogram", icon = "lucide/glyph/battery-low" },
	["power-50%-icon"] = { kind = "pictogram", icon = "lucide/glyph/battery-medium" },
	["power-80%-icon"] = { kind = "pictogram", icon = "lucide/glyph/battery-full" },
	["power-full-icon"] = { kind = "pictogram", icon = "lucide/glyph/battery-full" },

	["ic-game-n"] = { kind = "tile", icon = "lucide/glyph/gamepad-2" },
	["ic-game-f"] = { kind = "tile", icon = "lucide/glyph/gamepad-2", focused = true },
	["ic-app-n"] = { kind = "tile", icon = "lucide/glyph/layout-grid" },
	["ic-app-f"] = { kind = "tile", icon = "lucide/glyph/layout-grid", focused = true },
	["ic-collection-n"] = { kind = "tile", icon = "lucide/glyph/folder" },
	["ic-collection-f"] = { kind = "tile", icon = "lucide/glyph/folder", focused = true },
	["ic-favorite-n"] = { kind = "tile", icon = "lucide/glyph/star" },
	["ic-favorite-f"] = { kind = "tile", icon = "lucide/glyph/star", focused = true },
	["ic-recent-n"] = { kind = "tile", icon = "lucide/glyph/history" },
	["ic-recent-f"] = { kind = "tile", icon = "lucide/glyph/history", focused = true },
	["ic-setting-n"] = { kind = "tile", icon = "lucide/glyph/settings" },
	["ic-setting-f"] = { kind = "tile", icon = "lucide/glyph/settings", focused = true },
	["ic-retroarch-n"] = { kind = "tile", icon = "lucide/glyph/joystick" },
	["ic-retroarch-f"] = { kind = "tile", icon = "lucide/glyph/joystick", focused = true },
}
