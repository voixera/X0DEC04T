local VERSION = "0.1"
local HUB_NAME = "X0DEC04T"
local games = {
    [6739698191]      = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/ViolenceDistrict.lua",
    [10200395747]     = "https://raw.githubusercontent.com/voixera/X0DEC04T/refs/heads/main/GrowAGarden2.lua"
}

local universeId = game.GameId
local placeId    = game.PlaceId
local scriptURL  = games[universeId]

print(string.format("[%s v%s] PlaceId: %d | UniverseId: %d", HUB_NAME, VERSION, placeId, universeId))

if scriptURL then
    print(string.format("[%s] Game supported! UniverseId: %d", HUB_NAME, universeId))
    print(string.format("[%s] Loading script...", HUB_NAME))

    local ok, err = pcall(function()
        loadstring(game:HttpGet(scriptURL))()
    end)

    if not ok then
        warn(string.format("[%s] Gagal load script: %s", HUB_NAME, tostring(err)))
    end
else
    local msg = string.format(
        "\n[%s] Game belum didukung!\nPlaceId: %d\nUniverseId: %d!",
        HUB_NAME, placeId, universeId
    )
    warn(msg)
    print(msg)
end
