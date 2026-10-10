local errorHandler = require("error_handler")

local function fail(msg)
	if msg then
		errorHandler.setError(msg)
	end
	return false, msg
end

return fail
