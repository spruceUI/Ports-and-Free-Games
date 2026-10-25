--- Physical button labels vs SDL gamepad names
---
--- SDL's built-in controller mappings are positional (Xbox layout): the bottom face button is
--- "a", the right one is "b". Most spruce handhelds carry Nintendo labels (A on the right, B at
--- the bottom), and PyUI maps the evdev codes to the printed labels per device
--- (App/PyUI/main-ui/devices/*mapping_provider*.py). launch.sh exports the same facts as
--- AESTHETIC_SWAP_AB / AESTHETIC_SWAP_XY so "a" in InputConfig always means the button labelled A.
--- Anbernic and RGB30 use spruce's own SDL map strings, which are already label-based.
local layout = {}

local swapAB = os.getenv("AESTHETIC_SWAP_AB") == "1"
local swapXY = os.getenv("AESTHETIC_SWAP_XY") == "1"

local physical = {}
if swapAB then
	physical.a, physical.b = "b", "a"
end
if swapXY then
	physical.x, physical.y = "y", "x"
end

--- SDL gamepad button name to poll for the button labelled `name`
function layout.sdlButton(name)
	return physical[name] or name
end

function layout.describe()
	return string.format("swapAB=%s swapXY=%s", tostring(swapAB), tostring(swapXY))
end

return layout
