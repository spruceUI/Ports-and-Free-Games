--- Read/write theme snapshots (settings file and presets) as Lua table files
---
--- File shape (all keys optional on read):
---   return { themeName = "...", fontFamily = "...", ..., colors = { background = "#RRGGBB", ... },
---            source = "user" | "built-in", displayName = "...", created = <os.time()> }
local logger = require("utils.logger")
local fail = require("utils.fail")

local themeFile = {}

local function quote(s)
	return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end

local function serializeValue(v)
	local t = type(v)
	if t == "string" then
		return quote(v)
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	end
	return nil
end

--- Serialise a snapshot table (one level of nesting for `colors`) to Lua source
function themeFile.serialize(t, header)
	local lines = { "-- " .. (header or "Aesthetic Spruce theme file"), "return {" }
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = t[k]
		if type(v) == "table" then
			lines[#lines + 1] = "\t" .. k .. " = {"
			local subkeys = {}
			for sk in pairs(v) do
				subkeys[#subkeys + 1] = sk
			end
			table.sort(subkeys)
			for _, sk in ipairs(subkeys) do
				local sv = serializeValue(v[sk])
				if sv then
					lines[#lines + 1] = "\t\t" .. sk .. " = " .. sv .. ","
				end
			end
			lines[#lines + 1] = "\t},"
		else
			local sv = serializeValue(v)
			if sv then
				lines[#lines + 1] = "\t" .. k .. " = " .. sv .. ","
			end
		end
	end
	lines[#lines + 1] = "}"
	return table.concat(lines, "\n") .. "\n"
end

function themeFile.write(path, t, header)
	local f, err = io.open(path, "w")
	if not f then
		return fail("Failed to write " .. path .. ": " .. tostring(err))
	end
	f:write(themeFile.serialize(t, header))
	f:close()
	return true
end

--- Load a theme file; the chunk runs in an empty environment so a preset cannot call into the app
function themeFile.read(path)
	local chunk, err = loadfile(path)
	if not chunk then
		return fail("Failed to load " .. path .. ": " .. tostring(err))
	end
	setfenv(chunk, {})
	local ok, result = pcall(chunk)
	if not ok or type(result) ~= "table" then
		return fail("Theme file did not return a table: " .. path .. " (" .. tostring(result) .. ")")
	end
	logger.debug("Loaded theme file " .. path)
	return result
end

return themeFile
