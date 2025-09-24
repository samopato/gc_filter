-----------------------------------------
-- // GC Scanning
-----------------------------------------

local function getDefaultBlacklist()
	local blacklist = {
		"=[C]",
		"Base64",
		"=RbxStu", 
		"=Players",
		"=loadstring",
		"saveinstance",
		"RequireOnlineModule",
	}
	
	-- Add player names to blacklist
	for _,v in pairs(game:GetService("Players"):GetPlayers()) do 
		table.insert(blacklist, "=.".. v.Name)
	end
	
	return blacklist
end

local function matchesPrefix(str, data)
	local str = str:lower()
	for _, prefix in pairs(data) do
		if str:sub(1, #prefix) == prefix:lower() then
			return true
		end
	end
	return false
end

local function handleFunc(func, prefixes, blacklist, groups)
	if type(func) ~= "function" then 
		return
	end
	
	-- Safely get debug info
	local success, data = pcall(debug.getinfo, func)
	if not success or not data then
		return
	end
	
	local source = data.source or "Unknown"
	
	-- Check prefix and blacklist
	if not matchesPrefix(source, prefixes) or matchesPrefix(source, blacklist) then
		return
	end
	
	-- Initialize group if it doesn't exist
	local group = groups[source]
	if not group then
		groups[source] = {withName = {}, withoutName = {}}
		group = groups[source]
	end
	
	-- Add function to appropriate category
	if data.name and data.name ~= "" then
		group.withName[data.name] = func
	else
		local baseKey = tostring(data.currentline or "unknown")
		local key = baseKey
		local i = 2
		while group.withoutName[key] do
			key = baseKey .. "_" .. i
			i = i + 1
		end
		group.withoutName[key] = func
	end
end

local function scan(prefixes, shouldHook, blacklist)
	-- Set defaults if not provided
	prefixes = prefixes or {""}  -- scan everything by default
	shouldHook = shouldHook or false
	blacklist = blacklist or getDefaultBlacklist()
	
	local groups = {}
	
	-- Get garbage collection data safely
	local success, garbage = pcall(getgc, true)
	if not success then
		warn("Failed to get garbage collection data")
		return groups
	end
	
	-- Process garbage collection data
	for _, v in next, garbage do
		if type(v) == "thread" then
			-- Handle thread stack
			local stackSuccess, stack = pcall(debug.getstack, 1, v)
			if stackSuccess and stack then
				for _, func in next, stack do
					handleFunc(func, prefixes, blacklist, groups)
				end
			end
		else
			-- Handle direct functions
			handleFunc(v, prefixes, blacklist, groups)
		end
	end
	
	return groups
end

-----------------------------------------
-- // Window
-----------------------------------------
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local Window = ReGui:Window({
	Title = "GC Inspector",
	Size = UDim2.fromOffset(400, 300)
})

local Group = Window:List({
	UiPadding = 2,
	HorizontalFlex = Enum.UIFlexAlignment.Fill,
})

local TabsBar = Group:List({
	Border = true,
	UiPadding = 5,
	BorderColor = Window:GetThemeKey("Border"),
	BorderThickness = 1,
	HorizontalFlex = Enum.UIFlexAlignment.Fill,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	FlexMode = Enum.UIFlexMode.None,
})

local currentNodes = {} -- Keep track of current tree nodes for clearing

local function clearPreviousNodes()
	for _, node in pairs(currentNodes) do
		node:Remove()
	end
	currentNodes = {}
end

local function getAmmount(t)
local count = #t or 0

for _,v in next, t do
count += 1
end

return count
end

local function render(data)
	clearPreviousNodes()
	
	if not data or next(data) == nil then
		local noDataLabel = TabsBar:Label({
			Text = "No functions found"
		})
		table.insert(currentNodes, noDataLabel)
		return
	end
	
	for name, script in pairs(data) do
		local scriptTree = TabsBar:TreeNode({ Title = name })
		table.insert(currentNodes, scriptTree)
		
		-- Create withName section
		if next(script.withName) then
			local withList = scriptTree:TreeNode({ Title = "withName (" .. getAmmount(script.withName) .. ")" })
			for funcName, func in pairs(script.withName) do
				withList:Label({
					Text = funcName
				})
			end
		end
		
		-- Create withoutName section  
		if next(script.withoutName) then
			local withoutList = scriptTree:TreeNode({ Title = "withoutName (" .. getAmmount(script.withoutName) .. ")" })
			for key, func in pairs(script.withoutName) do
				withoutList:Label({
					Text = key
				})
			end
		end
	end
end

-- Scan button
Window:Button({
	Text = "Refresh Scan",
	Callback = function()
		local data = scan({""}, false, nil) -- Use defaults: scan everything, no hook, default blacklist
		render(data)
		local count = 0
		for _ in pairs(data) do count = count + 1 end
	end
})

-- Clear button
Window:Button({
	Text = "Clear Results",
	Callback = function()
		clearPreviousNodes()
	end
})

-- Initial scan
local initialData = scan({""}, false, nil) -- Use defaults
render(initialData)