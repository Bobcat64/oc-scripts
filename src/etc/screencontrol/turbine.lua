local prefix = require("prefixunit")
local component = require('component')

local function handle(settings)
    local t
    if settings.addr then
        local addr = component.get(settings.addr, "nc_turbine")
        if not addr then
            return "Turbine Component Not Found", 0xFF0000
        end
        t = component.proxy(addr)
    else
        if not component.isAvailable("nc_turbine") then
            return "Turbine Component Not Found", 0xFF0000
        end
        t = component.getPrimary("nc_turbine")
    end

    if t.isProcessing() then
        local res =
            string.format("Turbine %s %s"
                , prefix(t.getInputRate() / 1000, "b", "%.f")
                , prefix(t.getPower(), "RF/t"))
        return res, 0x00FF00
    end

    if not t.isTurbineOn() then
        return "Turbine Inactive", 0xAAAA00
    end

    if not t.isComplete() then
        return "Turbine Incomplete", 0xFF0000
    end

    return "Turbine Ready", 0xFFFFFF
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