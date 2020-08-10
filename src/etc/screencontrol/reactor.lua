local component = require('component')

local function handle(settings)
    local addr = component.get(settings.addr, "nc_salt_fission_reactor")
    local r
    if addr then
        r = component.proxy(addr)
    else
        if not component.isAvailable("nc_salt_fission_reactor") then
            return "Reactor Component Not Found", 0xFF0000
        end
        r = component.getPrimary("nc_salt_fission_reactor")
    end

    if not r.isComplete() then
        return "Reactor Incomplete", 0xFF0000
    end

    if not r.isReactorOn() then
        return "Reactor Inactive", 0xAAAA00
    end

    local heat = r.getRawHeatingRate()
    local cool = r.getCoolingRate()
    local clr = 0x00FF00
    local status = "On"
    if heat > cool then
        clr = 0xFF0000
        status = "HOT!"
    elseif (cool + 10) < heat then --handle grace zone
        clr = 0x0099FF
        status = "Cold"
    end
    local net = heat - cool

    return string.format("Reactor %s %+d heat", status, net), clr
end

function update(screen, tag, settings)
    local txt, clr = handle(settings)

    if clr == nil then
        clr = 0xFFFFFF
    end

    if settings.lastCall > 5 or settings.lastVal ~= txt or settings.lastClr ~= clr then
        screen.setText(tag, txt, clr)
        settings.lastVal, settings.lastClr = txt, clr
        settings.lastCall = 0
    else
        settings.lastCall = (settings.lastCall or 0) + 1 --Ensure we set the text every now and then even if it hasn't changed
    end
end