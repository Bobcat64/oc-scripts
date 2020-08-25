local event = require('event')
local conf = require('conf')

local mon = {}

local DEFAULT_CONFIG = '/etc/monitor.cfg'
local DEFAULT_INTERVAL = 1

local config = nil
local timers = nil
local monitors = nil


function mon.loadConfig(fname)
    checkArg(1, fname, 'string', 'nil')
    local meta = {
        __index={
            sides=require('sides'),
            colors=require('colors'),
            math=math
        }
    }
    local c = conf.loadConfig(fname or DEFAULT_CONFIG, setmetatable({}, meta))
    if c then
        mon.shutdown()
        config = c
        return config
    end
    return nil, 'Config not found or empty'
end

function mon.getConfig(name)
    checkArg(1, name, 'string', 'nil')
    if config and name then
        return config[name]
    end
    return config
end

function mon.getMonitor(name)
    checkArg(1, name, 'string')
    if type(monitors) ~= 'table' then return nil, 'Monitors not setup' end
    return monitors[name]
end

function mon.isRunning(name)
    checkArg(1, name, 'string')
    return timers ~= nil and timers[name] ~= nil
end

local function loadMonitor(config)
    if type(config) ~= 'table' or type(config.type) ~= 'string' then return nil, 'Invalid Monitor Configuration' end
    local lib = require('monitor/' .. config.type)
    return lib.create(config)
end

local function setupTimer(cfg, monitor)
    if type(monitor) ~= 'table' or type(cfg) ~='table' then
        return nil, 'Invalid Configuration'
    end

    local function handler()
        monitor:update()
    end
    return event.timer(cfg.interval or DEFAULT_INTERVAL, handler, math.huge)

end

function mon.setupMonitor(name, cfg)
    checkArg(1, name, 'string')
    checkArg(2, cfg, 'table', 'nil')
    if cfg == nil then
        if type(config) ~= 'table' or type(config[name]) ~= 'table' then return false, 'No Configuration found or loaded' end
        cfg = config[name]
    end

    --Default to having a name property that matches the configuration, so monitors know what they are called
    if not cfg.name then cfg.name = name end

    monitors = monitors or {}
    if monitors[name] == nil then
        local success, res = pcall(loadMonitor, cfg)
        if success then
            monitors[name] = res
            config[name] = cfg
        else
            return false, res
        end
    end

    local s, r = pcall(setupTimer, cfg, monitors[name])
    if s then
        timers = timers or {}
        timers[name] = r
    else
        return false, r
    end
            
    return monitors[name]
end

function mon.start()
    if (type(config) ~= 'table' or type(config.monitors) ~='table') then
        return nil, 'Invalid Configuration'
    end

    timers={}
    monitors=monitors or {}

    for name, cfg in pairs(config.monitors) do
        if type(cfg) == 'table' and cfg.enabled ~= false then
            local success, res = pcall(mon.setupMonitor, name, cfg)
            if not success then
                io.stderr:write('Error setting up "' .. name .. '" ' .. res .. '\n')
            end
        end
    end
end


function mon.shutdown(monName)
    checkArg(1, monName, 'string', 'nil')
    if type(timers) ~= 'table' then return nil, 'No Timers Running' end
    local didSomething = false
    for k,v in pairs(timers) do
        if monName == nil or k == monName then
            event.cancel(v)
            didSomething = true
            timers[k] = nil
            if monitors[k] and monitors[k].shutdown then
                monitors[k]:shutdown()
            end
        end
    end
    return didSomething
end

return mon