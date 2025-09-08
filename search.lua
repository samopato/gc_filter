local shouldHook = false
local prefixes = {""} --scan everything
local blacklist = {
	"=[C]",
	"Base64",
	"=RbxStu",
	"=Players",
	"=loadstring",
	"saveinstance",
	"=.Justin",
	"RequireOnlineModule",
}

local garbage = getgc(true)
local groups = {}

local function matchesPrefix(str, data)
	local str = str:lower()

	for _, prefix in pairs(data) do
		if str:sub(1, #prefix) == prefix:lower() then
			return true
		end
	end
	return false
end

local function handleFunc(func)
	if type(func) ~= "function" then 
		return
	end

	local data = debug.getinfo(func)
	local source = data.source
	if not matchesPrefix(source, prefixes) or matchesPrefix(source, blacklist) then
		return
	end

	local group = groups[data.source]
	if not group then
		groups[data.source] = {withName = {}, withoutName = {}}
		group = groups[data.source]
	end

	if data.name then
		group.withName[data.name] = func
	else
		local baseKey = tostring(data.currentline)
		local key = baseKey
		local i = 2

		while group.withoutName[key] do
			key = baseKey .. "_" .. i
			i += 1
		end

		print(key)
		group.withoutName[key] = func
	end
end

local function search()
	for _, v in next, garbage do
		if type(v) == "thread" then
			for _, b in next, debug.getstack(1, v) do
				handleFunc(b)
			end
		else
			handleFunc(v)
		end
	end

	for i,v in pairs(groups) do        
		print("--------------------------------")

		warn(i)
		warn(v)

		if not shouldHook then
			continue
		end
		
		local function hook(func, id) 
			local original; original = hookfunction(func, newcclosure(function(...)
				warn("hooked " ..id)
			end))
		end

		for id, func in next, v.withoutName do
			hook(func, id)
		end
		
		for id, func in next, v.withName do
			hook(func, id)	
		end
	end

	print("--------------------------------")
end

search()
