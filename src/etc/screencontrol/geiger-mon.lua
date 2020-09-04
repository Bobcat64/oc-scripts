local prefix = require("prefixunit")
local monitor = require('monitor')

function handle(settings)
    if not settings.monitor then 
        return 'No Monitor in settings', 0xFF0000
    end
    local m = monitor.getMonitor(settings.monitor)
    if not m then 
        return 'Monitor ' .. settings.monitor .. ' not found', 0xFF0000
    end

    local rads = m.state.radiation
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