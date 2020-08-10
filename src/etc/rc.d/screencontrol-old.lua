local component = require("component")
local event = require("event")
local prefix = require("prefixunit")
local computer = require('computer')

local timerId

local hndlr = {}
local handled = {}

function hndlr.TurbineStatus()
    if not component.isAvailable("nc_turbine") then
        return "Turbine Component Not Found", 0xFF0000
    end
    local t = component.getPrimary("nc_turbine")

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

function hndlr.ReactorStatus()
    if not component.isAvailable("nc_salt_fission_reactor") then
        return "Reactor Component Not Found", 0xFF0000
    end
    local r = component.getPrimary("nc_salt_fission_reactor")

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

function hndlr.GeigerStatus()
    if not component.isAvailable("nc_geiger_counter") then
        return "Geiger Counter Not Found", 0xFF0000
    end
    local g = component.getPrimary("nc_geiger_counter")

    local rads = g.getChunkRadiationLevel()
    local severity = math.log(rads, 10) + 12
    local blue = math.max(0, math.min(0xFF, math.floor(0xFF - (severity * 0x33))))
    severity = severity - 9
    local yellow = math.max(0, math.min(0xFF, math.floor(0xFF - (severity * 0x33)))) * 0x100
    severity = 0xFF0000 + yellow + blue
    return prefix(rads, "Rad/t"), severity
end

local function handleTimer(...)
    if not component.isAvailable("screen_controller") then
        return
    end

    local scr = component.getPrimary("screen_controller")
    local tags = scr.getTags --Implemented as a property instead of a function, also will return repeats
    
    local deadline = computer.uptime() + 0.35
    for _, tag in ipairs(tags) do
        local func = hndlr[tag]
        if func ~= nil and not handled[tag] then
            handled[tag] = true
            local success, val, clr = pcall(func)
            
            if clr == nil then
                clr = 0xFFFFFF
            end
            if success then
                local r, err = pcall(scr.setText, tag, val, clr)
                if not r then
                    scr.setText(tag, "Err " .. err, 0xFF0000)
                end
            else
                scr.setText(tag, "Err: " .. val, 0xFF2222)
            end
            if computer.uptime() > deadline then
                return --exit without resetting the handled table
            end
        end
    end
    --went through all tags, flag all items as no longer handled for next run
    handled = {}
end

local function shutdown()
    local wasRunning = false
    if timerId then
        event.cancel(timerId)
        wasRunning = true
    end
    timerId = nil
    handled = {}
    return wasRunning
end


function start()
    shutdown()
    timerId = event.timer(1.5, handleTimer, math.huge)
end

function stop()
    if shutdown() then
        print("Stopped Screen Controller service")
        return
    end
    print("Screen Controller service is not running")
end