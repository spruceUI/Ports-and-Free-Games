--- Error handler
--- This module centralizes error handling functionality throughout the application
local logger = require("utils.logger")

local errorHandler = {}
local lastError = nil

-- Function to log error message
function errorHandler.setError(message)
	lastError = tostring(message)
	logger.error("Error: " .. lastError)
end

function errorHandler.getError()
	return lastError
end

function errorHandler.clearError()
	lastError = nil
end

return errorHandler
