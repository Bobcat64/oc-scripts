local component = require("component")
local event = require("event")
local computer = require('computer')
local conf = require('conf')
local sides = require('sides')
local colors = require('colors')
local fs = require('filesystem')


local cfg
local scripts
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
    scripts = nil --Probably should have a shutdown function to call for each handler
    return wasRunning
end

local function loadScript(handler)
    local fpath = handler.script
    if not fpath then return end --error?
    fpath = fs.concat(cfg.path, fpath)
    
    --return any cached scripts
    if scripts[fpath] == false then 
        return nil --if we failed to load previously, don't keep retrying
    elseif scripts[fpath] then
        return scripts[fpath]
    end

    local env = setmetatable({}, {__index=_G})
    local result, reason = loadfile(fpath, 't', env)
    if not result then
        scripts[fpath] = false
        print('Failed to load ' .. handler.script .. ': ' .. reason) --go to stderr?        
        return nil
    end
    
    result, reason = xpcall(result, debug.traceback)
    if not result then
        scripts[fpath] = false
        print('Failed starting ' .. handler.script .. ': ' .. reason)
        return nil
    end

    scripts[fpath] = env
    return env
end


local function setupTimer(tag, hconf)
    if timers[tag] ~= nil then return end
    if not hconf then return end
    
    local hndlr = loadScript(hconf)
    if not hndlr then return end
    local tagconf = setmetatable({}, {__index=hconf})

    local function timerHandler()
        if not component.isAvailable("screen_controller") then
            return
        end
    
        local scr = component.getPrimary("screen_controller")
        hndlr.update(scr, tag, tagconf)
    end

    timers[tag] = event.timer(hconf.interval or cfg.defaultInterval, timerHandler, math.huge)
end

--TODO: Have a global timer that refreshes a list of tags the controller has and load only the scripts when needed
local function setupHandlers()
    for tag, hconf in pairs(cfg.handlers) do
        setupTimer(tag, hconf)
    end
end


function start()
    shutdown()
    cfg = conf.loadConfig('/etc/screencontrol.cfg', {sides=sides, colors=colors})
    cfg = cfg or {}

    if cfg.path == nil then cfg.path = '/etc/screencontrol' end
    if cfg.defaultInterval == nil then cfg.defaultInterval = 1 end

    if not cfg.handlers then
        print('Warning - No handlers defined')
        cfg.handlers = {}
    end
    scripts = {}

    setupHandlers()

end

function stop()
    if shutdown() then
        print("Stopped Screen Controller service")
        return
    end
    print("Screen Controller service is not running")
end

function unload() --TODO allow selective unloading
    shutdown()
    require('rc').unload('screencontrol')
end