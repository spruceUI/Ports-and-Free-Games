--- Navigation Utilities
--- Spatial navigation algorithms for UI focus management

local NavigationUtils = {}

local DIRECTIONS = {
	up = { x = 0, y = -1 },
	down = { x = 0, y = 1 },
	left = { x = -1, y = 0 },
	right = { x = 1, y = 0 },
}

-- Get the center point of a component
local function getComponentCenter(component)
	return {
		x = component.x + component.width / 2,
		y = component.y + component.height / 2,
	}
end

-- Calculate distance between two points
local function getDistance(point1, point2)
	local dx = point2.x - point1.x
	local dy = point2.y - point1.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Check if component B is in the correct direction from component A
local function isInDirection(fromComponent, toComponent, direction)
	local fromCenter = getComponentCenter(fromComponent)
	local toCenter = getComponentCenter(toComponent)
	local dirVector = DIRECTIONS[direction]
	if not dirVector then
		return false
	end
	local actualVector = {
		x = toCenter.x - fromCenter.x,
		y = toCenter.y - fromCenter.y,
	}
	local dotProduct = actualVector.x * dirVector.x + actualVector.y * dirVector.y
	return dotProduct > 0
end

-- Calculate alignment score for navigation
local function calculateAlignmentScore(fromComponent, toComponent, direction)
	local fromCenter = getComponentCenter(fromComponent)
	local toCenter = getComponentCenter(toComponent)
	if direction == "up" or direction == "down" then
		local horizontalDistance = math.abs(toCenter.x - fromCenter.x)
		local maxWidth = math.max(fromComponent.width, toComponent.width)
		return horizontalDistance / maxWidth
	else
		-- For horizontal navigation, check vertical alignment
		local verticalDistance = math.abs(toCenter.y - fromCenter.y)
		local maxHeight = math.max(fromComponent.height, toComponent.height)
		return verticalDistance / maxHeight
	end
end

-- Calculate navigation score for a candidate component (lower is better)
local function calculateNavigationScore(fromComponent, toComponent, direction)
	if not isInDirection(fromComponent, toComponent, direction) then
		return math.huge
	end
	local fromCenter = getComponentCenter(fromComponent)
	local toCenter = getComponentCenter(toComponent)
	local distance = getDistance(fromCenter, toCenter)
	local alignmentScore = calculateAlignmentScore(fromComponent, toComponent, direction)
	return distance + (alignmentScore * 100)
end

-- Find the best candidate component for navigation
function NavigationUtils.findBestCandidate(fromComponent, candidates, direction)
	local bestCandidate = nil
	local bestScore = math.huge
	for _, candidate in ipairs(candidates) do
		-- Special case: if direction is up and candidate is a list above fromComponent, prefer it
		if direction == "up" and candidate.items and candidate.y + candidate.height <= fromComponent.y then
			return candidate
		end
		local score = calculateNavigationScore(fromComponent, candidate, direction)
		if score < bestScore then
			bestScore = score
			bestCandidate = candidate
		end
	end
	return bestCandidate
end

-- Utility functions for wrapping navigation
function NavigationUtils.findTopMostComponent(components)
	local topMost = nil
	local minY = math.huge

	for _, component in ipairs(components) do
		if component.y < minY then
			minY = component.y
			topMost = component
		end
	end
	return topMost
end

function NavigationUtils.findBottomMostComponent(components)
	local bottomMost = nil
	local maxY = -math.huge

	for _, component in ipairs(components) do
		local bottomY = component.y + component.height
		if bottomY > maxY then
			maxY = bottomY
			bottomMost = component
		end
	end
	return bottomMost
end

function NavigationUtils.findLeftMostComponent(components)
	local leftMost = nil
	local minX = math.huge

	for _, component in ipairs(components) do
		if component.x < minX then
			minX = component.x
			leftMost = component
		end
	end
	return leftMost
end

function NavigationUtils.findRightMostComponent(components)
	local rightMost = nil
	local maxX = -math.huge

	for _, component in ipairs(components) do
		local rightX = component.x + component.width
		if rightX > maxX then
			maxX = rightX
			rightMost = component
		end
	end
	return rightMost
end

return NavigationUtils
