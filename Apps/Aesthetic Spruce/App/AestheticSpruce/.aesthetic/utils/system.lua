--- System utilities
--- This module avoids using `love.filesystem` since most functions are not sandboxed
local errorHandler = require("error_handler")
local commands = require("utils.commands")
local logger = require("utils.logger")
local environment = require("utils.environment")
local system = {}
local fail = require("utils.fail")

-- Function to check if file exists
function system.fileExists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	logger.warning("File does not exist: " .. path)
	return false
end

-- Copy a file or directory using rsync, creating parent directories as needed
function system.copy(sourcePath, destinationPath)
	if not sourcePath or not destinationPath then
		return fail("Source and destination paths required for copy")
	end

	if not system.fileExists(sourcePath) and not system.isDir(sourcePath) then
		return fail("Source does not exist: " .. tostring(sourcePath))
	end

	-- Ensure parent directory of destination exists
	if not system.ensurePath(destinationPath) then
		return fail("Failed to create destination directory: " .. destinationPath)
	end

	local osType = environment.getOS()
	local rsyncCmd
	if osType == "macos" then
		rsyncCmd = string.format('rsync -aq "%s" "%s"', sourcePath, destinationPath)
	else
		rsyncCmd = string.format('rsync -a -W -z0 --info=none "%s" "%s"', sourcePath, destinationPath)
	end

	if commands.executeCommand(rsyncCmd) ~= 0 then
		return fail("rsync command failed: " .. rsyncCmd)
	end

	return true
end

--- Ensures a directory exists, creating it if necessary
--- If path points to a file, creates the parent directory
--- If path points to a directory, creates that directory
function system.ensurePath(path)
	if not path then
		logger.error("No path provided to ensurePath")
		errorHandler.setError("No path provided to ensurePath")
		return false
	end

	-- If path ends with a slash, treat as directory path
	-- Otherwise, extract parent directory from potential file path
	local dir
	if path:match("/$") then
		dir = path:sub(1, -2) -- Remove trailing slash
	else
		dir = path:match("(.+)/[^/]+$") or path
	end

	local result = os.execute('mkdir -p "' .. dir .. '"')
	if not result then
		logger.error("Failed to create directory (" .. dir .. "): " .. tostring(result))
		errorHandler.setError("Failed to create directory (" .. dir .. "): " .. tostring(result))
		return false
	end
	return true
end

-- Function to check if a path is a directory using `test -d`
function system.isDir(path)
	if not path then
		return false
	end
	local cmd = string.format('test -d "%s"', path)
	-- Use os.execute instead of commands.executeCommand to avoid printing
	local result = os.execute(cmd)
	return result == 0
end

-- Get environment variable, setting error if not found
function system.getEnvironmentVariable(name)
	local value = os.getenv(name)
	if value == nil then
		logger.error("Environment variable not found: " .. name)
		return fail("Environment variable not found: " .. name)
	end
	logger.info(string.format("Environment variable [%s] = '%s'", name, value))
	return value
end

-- Remove a directory and all its contents recursively
function system.removeDir(dir)
	if not dir then
		return fail("No directory path provided to removeDir")
	end

	-- Check if directory exists before attempting removal
	local checkCmd = string.format('test -d "%s"', dir)
	if commands.executeCommand(checkCmd) ~= 0 then
		logger.warning("Directory does not exist for removal: " .. dir)
		return true -- Return true since there's nothing to remove
	end

	return commands.executeCommand('rm -rf "' .. dir .. '"')
end

-- Create a simple text file with the given content
function system.createTextFile(filePath, content)
	local file = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to create file: " .. filePath)
		return false
	end
	file:write(content)
	file:close()
	return true
end

-- Modify a file using a function that processes its content
-- modifierFunc receives the file content and should return (modifiedContent, success)
function system.modifyFile(filePath, modifierFunc)
	-- Read the file content
	local file, err = io.open(filePath, "r")
	if not file then
		errorHandler.setError("Failed to open file (" .. filePath .. "): " .. err)
		return false
	end

	local fileContent = file:read("*all")
	file:close()

	-- Modify the content using the provided function
	local modifiedContent, success = modifierFunc(fileContent)
	if not success then
		return false
	end

	-- Write the updated content back to the file
	file, err = io.open(filePath, "w")
	if not file then
		errorHandler.setError("Failed to write to file (" .. filePath .. "): " .. err)
		return false
	end

	file:write(modifiedContent)
	file:close()
	return true
end

-- Read the entire content of a file
function system.readFile(filePath)
	-- Check if file exists to provide better error message
	if not system.fileExists(filePath) then
		return nil
	end

	-- Standard file reading
	-- Note: For larger files (>10MB), memory mapping with dd would be more efficient:
	-- dd if=filePath bs=4M
	local file, err = io.open(filePath, "r")
	if not file then
		errorHandler.setError("Failed to open file for reading (" .. filePath .. "): " .. err)
		return nil
	end

	local content = file:read("*all")
	file:close()

	if not content then
		errorHandler.setError("Failed to read content from file: " .. filePath)
		return nil
	end

	return content
end

-- Write content to a file, creating directories if needed
function system.writeFile(filePath, content)
	-- Ensure the directory exists
	if not system.ensurePath(filePath) then
		return fail("Failed to create directory for file: " .. filePath)
	end

	local file, err = io.open(filePath, "wb")
	if not file then
		return fail("Failed to open file for writing (" .. filePath .. "): " .. err)
	end

	local success = file:write(content)
	file:close()

	if not success then
		return fail("Failed to write content to file: " .. filePath)
	end

	return true
end

-- List files in a directory matching a pattern (returns table of filenames, not full paths)
function system.listFiles(dir, pattern)
	if not dir or not pattern then
		errorHandler.setError("Directory and pattern required for listFiles")
		return {}
	end
	local cmd = string.format('ls "%s"/%s 2>/dev/null', dir, pattern)
	local handle = io.popen(cmd)
	if not handle then
		errorHandler.setError("Failed to list files in directory: " .. dir)
		return {}
	end
	local result = handle:read("*a")
	handle:close()
	local files = {}
	for filename in string.gmatch(result, "[^\n]+") do
		local name = filename:match("([^/]+)$")
		if name then
			table.insert(files, name)
		end
	end
	return files
end

-- Function to list contents of a directory
function system.listDir(dir)
	if not dir then
		errorHandler.setError("No directory path provided to listDir")
		return nil
	end

	-- Check if directory exists before listing
	local checkCmd = string.format('test -d "%s"', dir)
	if commands.executeCommand(checkCmd) ~= 0 then
		logger.warning("Directory does not exist for listing: " .. dir)
		-- Return an empty table if the directory doesn't exist (graceful handling)
		return {}
	end

	-- Use ls -a1 to list all entries (including hidden) one per line
	local cmd = string.format('ls -a1 "%s"', dir)
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		logger.error("Failed to execute list directory command")
		errorHandler.setError("Failed to execute list directory command")
		return nil
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		logger.error("List directory command failed: " .. result)
		errorHandler.setError("List directory command failed: " .. result)
		return nil
	end

	local items = {}
	-- Split output into lines and add to table, excluding '.' and '..'
	for item in result:gmatch("[^\n]+") do
		if item ~= "." and item ~= ".." then
			table.insert(items, item)
		end
	end

	return items
end

-- Function to check if a path is a file using `test -f`
function system.isFile(path)
	if not path then
		return false
	end
	local cmd = string.format('test -f "%s"', path)
	-- Use os.execute instead of commands.executeCommand to avoid printing
	local result = os.execute(cmd)
	return result == 0
end

-- Remove a file at the given path
function system.removeFile(path)
	if not path then
		return fail("No file path provided to removeFile")
	end
	if not system.isFile(path) then
		logger.warning("File does not exist for removal: " .. path)
		return true -- Nothing to remove
	end
	local ok, err = os.remove(path)
	if not ok then
		return fail("Failed to remove file: " .. tostring(err))
	end
	return true
end

return system
