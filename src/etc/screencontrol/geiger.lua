local component = require('component')
local prefix = require("prefixunit")

local function handle(settings)
    local g
    if settings.addr then
        local addr = component.get(settings.addr, "nc_geiger_counter") 
        if not addr then
            return "Geiger Counter Not Found", 0xFF0000
        end
        g = component.proxy(addr)
    else
        if not component.isAvailable("nc_geiger_counter") then
            return "Geiger Counter Not Found", 0xFF0000
        end
        g = component.getPrimary("nc_geiger_counter")
    end
    local rads = g.getChunkRadiationLevel()
    local severity = math.log(rads, 10) + 12
    local blue = math.max(0, math.min(0xFF, math.floor(0xFF - (severity * 0x33))))
    severity = severity - 9
    local yellow = math.max(0, math.min(0xFF, math.floor(0xFF - (severity * 0x33)))) * 0x100
    severity = 0xFF0000 + yellow + blue
    return prefix(rads, "Rad/t"), severity
end

function update(screen, tag, settings)
    local txt, clr = handle(settings)

    if clr == nil then
        clr = 0xFFFFFF
    end

    if (settings.lastCall or 0) > 5 or settings.lastVal ~= txt or settings.lastClr ~= clr then
        screen.setText(tag, txt, clr)
        settings.lastVal, settings.lastClr = txt, clr
        settings.lastCall = 0
    else
        settings.lastCall = (settings.lastCall or 0) + 1 --Ensure we set the text every now and then even if it hasn't changed
    end
end