-- GCSearch.lua
local function GCSearch(options)
    options = options or {}

    local prefixes = options.prefixes or {""}
    local blacklist = options.blacklist or {
        "=[C]",
        "Base64",
        "=RbxStu",
        "=Players",
        "=loadstring",
        "saveinstance",
        "=Workspace.Justin",
        "RequireOnlineModule",
    }
    local shouldHook = options.shouldHook or false
    local hookHandler = options.hookHandler or function(func, id, source)
        hookfunction(func, newcclosure(function(...)
				warn("hooked " ..id)
		end))
    end

    local groups = {}
    local garbage = getgc()

    local function matchesPrefix(str, data)
        str = str:lower()
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

        local group = groups[source]
        if not group then
            groups[source] = {withName = {}, withoutName = {}}
            group = groups[source]
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

            group.withoutName[key] = func
        end
    end

    for _, v in next, garbage do
        if type(v) == "thread" then
            for _, b in next, debug.getstack(1, v) do
                handleFunc(b)
            end
        else
            handleFunc(v)
        end
    end

    for source, funcs in pairs(groups) do
        print("--------------------------------")
        warn("Source:", source)

        if shouldHook then
            local function hook(func, id)
                local original
                original = hookfunction(func, newcclosure(function(...)
                    hookHandler(func, id, source)
                    return original(...)
                end))
            end

            for id, func in pairs(funcs.withName) do
                hook(func, id)
            end

            for id, func in pairs(funcs.withoutName) do
                hook(func, id)
            end
        else
            print("Functions:", funcs)
        end
    end

    print("--------------------------------")
    return groups
end

getgenv().search = GCSearch
