local VERSION  = "0.2"
local HUB_NAME = "X0DEC04T"
local GAMES = {
    [6739698191]      = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/ViolenceDistrict.luau",
    [10200395747]     = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/GrowAGarden2.lua",
    [6911148748]      = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/CDID.luau",
    [90226220017920]  = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/RA.lua",
    [136020512003847] = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/SDBR.lua",
}

local function log(msg)
    print(string.format("[%s v%s] %s", HUB_NAME, VERSION, tostring(msg)))
end

local function err(msg)
    warn(string.format("[%s v%s] ERROR: %s", HUB_NAME, VERSION, tostring(msg)))
end

local function httpGet(url)
    local raw = nil
    local ok, result = pcall(function()
        if syn and syn.request then
            local res = syn.request({ Url = url, Method = "GET" })
            if res and res.StatusCode == 200 then
                raw = res.Body
            else
                error("Status " .. tostring(res and res.StatusCode or "nil"))
            end
        elseif http and http.request then
            local res = http.request({ Url = url, Method = "GET" })
            if res and res.StatusCode == 200 then
                raw = res.Body
            else
                error("Status " .. tostring(res and res.StatusCode or "nil"))
            end
        elseif request then
            local res = request({ Url = url, Method = "GET" })
            if res and res.StatusCode == 200 then
                raw = res.Body
            else
                error("Status " .. tostring(res and res.StatusCode or "nil"))
            end
        else
            raw = game:HttpGet(url)
        end
    end)
    if not ok then
        error("httpGet failed: " .. tostring(result))
    end
    if not raw or raw == "" then
        error("httpGet returned empty body for: " .. url)
    end
    return raw
end

local function safeLoadstring(src, chunkName)
    local fn, compileErr
    if loadstring then
        fn, compileErr = loadstring(src, chunkName)
    else
        fn, compileErr = load(src, chunkName)
    end
    if not fn then
        error("Compile error: " .. tostring(compileErr))
    end
    return fn
end

local function resolveIds()
    local universeId = game.GameId
    local placeId    = game.PlaceId
    if universeId == 0 then
        pcall(function()
            local ms   = game:GetService("MarketplaceService")
            local info = ms:GetProductInfo(placeId)
        end)
    end

    return universeId, placeId
end

local function main()
    log("Starting loader...")
    local universeId, placeId = resolveIds()
    log(string.format("PlaceId=%d | UniverseId=%d", placeId, universeId))
    local scriptURL = GAMES[universeId]
    if not scriptURL then
        scriptURL = GAMES[placeId]
    end

    if not scriptURL then
        local supported = {}
        for id in pairs(GAMES) do
            table.insert(supported, tostring(id))
        end
        err(string.format(
            "Game not supported!\n  PlaceId    = %d\n  UniverseId = %d\n  Supported IDs: %s",
            placeId, universeId, table.concat(supported, ", ")
        ))
        return
    end

    log("Game supported! Fetching script from:\n  " .. scriptURL)
    local src   = nil
    local tries = 3
    local lastErr = "unknown"
    for attempt = 1, tries do
        local ok, result = pcall(function()
            src = httpGet(scriptURL)
        end)
        if ok and src then
            log(string.format("Fetch OK (attempt %d/%d) — %d bytes", attempt, tries, #src))
            break
        else
            lastErr = tostring(result)
            err(string.format("Fetch attempt %d/%d failed: %s", attempt, tries, lastErr))
            if attempt < tries then
                task.wait(1.5)
            end
        end
    end

    if not src then
        err("All fetch attempts failed. Last error: " .. lastErr)
        return
    end

    log("Compiling...")
    local fn, compileErr = pcall(function()
        return safeLoadstring(src, "=" .. HUB_NAME)
    end)

    if not fn then
        err("Compile failed: " .. tostring(compileErr))
        return
    end

    local scriptFn = compileErr

    if type(scriptFn) ~= "function" then
        err("safeLoadstring did not return a function.")
        return
    end

    log("Executing...")
    local runOk, runErr = pcall(scriptFn)

    if not runOk then
        err("Runtime error: " .. tostring(runErr))
    else
        log("Script executed successfully.")
    end
end

local ok, fatal = pcall(main)
if not ok then
    warn(string.format("[%s v%s] FATAL: %s", HUB_NAME, VERSION, tostring(fatal)))
end
