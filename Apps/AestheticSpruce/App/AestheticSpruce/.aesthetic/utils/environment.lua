--- Environment detection utilities
local logger = require("utils.logger")

local environment = {}

-- Function to get the current operating system
function environment.getOS()
	local handle = io.popen("uname -s")
	local osType = handle and handle:read("*l") or nil
	if handle then
		handle:close()
	end
	if osType == "Darwin" then
		return "macos"
	elseif osType == "Linux" then
		return "linux"
	else
		logger.warning("Unknown OS detected: " .. tostring(osType) .. ", defaulting to Linux")
		return "unknown"
	end
end

-- True when running on a spruceOS handheld (launch.sh exports SPRUCE_PLATFORM; the helper
-- library is the on-card marker when the env var is missing).
function environment.isSpruceDevice()
	if os.getenv("SPRUCE_PLATFORM") then
		return true
	end
	local f = io.open("/mnt/SDCARD/spruce/scripts/helperFunctions.sh", "r")
	if f then
		f:close()
		return true
	end
	return false
end

return environment
