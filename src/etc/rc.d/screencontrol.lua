local component = require("component")
local event = require("event")
local computer = require('computer')
local conf = require('conf')
local sides = require('sides')
local colors = require('colors')

local cfg

local timers

local function shutdown()
    local wasRunning = false
    if timers then
        for _, timer in pairs(timers) do
            if timer ~= nil then
                wasRunning = true
                event.cancel(timer)
            end
        end
    end
    timers = nil
    return wasRunning
end


function start()
    shutdown()
    cfg = conf.loadConfig('/etc/screencontrol.cfg', {sides=sides, colors=colors})
    cfg = cfg or {}
    
    
end

function stop()
    if shutdown() then
        print("Stopped Screen Controller service")
        return
    end
    print("Screen Controller service is not running")
end