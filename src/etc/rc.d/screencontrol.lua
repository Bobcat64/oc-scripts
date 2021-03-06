local component = require("component")
local event = require("event")
local serial = require('serialization')
local conf = require('conf')
local sides = require('sides')
local colors = require('colors')
local fs = require('filesystem')

local CFG_FNAME = '/etc/screencontrol.cfg'

local cfg
local scripts
local handlers
--local handlerSettings
--local timers

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
    if handlers then
        for tag, hndlr in pairs(handlers) do
            if type(hndlr.shutdown) == 'function' then
                pcall(hndlr.shutdown(tag, hndlr.settings))
            end
            hndlr.settings = nil
        end
    end
    handlers = nil
    scripts = nil
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
        io.stderr:write('Failed to load ' .. handler.script .. ': ' .. reason) --go to stderr?
        return nil
    end
    
    result, reason = xpcall(result, debug.traceback)
    if not result then
        scripts[fpath] = false
        io.stderr:write('Failed starting ' .. handler.script .. ': ' .. reason)
        return nil
    end

    scripts[fpath] = env
    return env
end

local foundScreen =true

local function setupTimer(tag, hndlr)
    if hndlr.enabled == false then return end
    if hndlr.timer ~= nil then return end
    
    local function timerHandler()        
        local scr = nil
        if (cfg.screenAddress) then
            scr = component.get(cfg.screenAddress, "screen_controller")
            if scr then scr = component.proxy(scr) end
        elseif component.isAvailable("screen_controller") then
            scr = component.getPrimary("screen_controller")
        end
        if not scr then 
            if foundScreen then --we previously found the screen
                foundScreen = false
                local msg = ""
                if cfg.screenAddress then msg = " with address: " .. tostring(cfg.screenAddress) end
                io.stderr:write('Error: Could not find screen_controller' .. msg .. '\n')
            end
            return
        end
        foundScreen=true
        hndlr.lib.update(scr, tag, hndlr.settings)
    end

    hndlr.timer = event.timer(hndlr.settings.interval or cfg.defaultInterval, timerHandler, math.huge)
    return 
end

local function setupHandler(tag, hconf)
    if type(handlers[tag]) == 'table' then return handlers[tag] end
    local hndlr = loadScript(hconf)
    if not hndlr then --loadScript should write an appropriate error        
        return nil
    end
    if type(hndlr.update) ~= 'function' then
        io.stderr:write('Handler "' .. tag .. '" does not define an update function')
        return nil
    end
    local settings = setmetatable({}, {__index=hconf})
    if type(hndlr.setup) == 'function' then
        local s, err = pcall(hndlr.setup, tag, settings)
        if not s then
            io.stderr:write('Error setting up handler: ' .. err)
            return nil --don't do anything further
        end
    end
    handlers[tag] = {lib = hndlr, settings=settings}
    return hndlr
end

--TODO: Have a global timer that refreshes a list of tags the controller has and load only the scripts when needed
local function setupHandlers()
    for tag, hconf in pairs(cfg.handlers) do
        local hndlr = setupHandler(tag, hconf)
        if hndlr then
            setupTimer(tag, hndlr)
        end
    end
end

local function printCfgValue(k)
    if type(cfg[k]) == 'table' then
        print(k..'=' .. serial.serialize(cfg[k], 15))
    else
        print(k .. '=' .. tostring(cfg[k]))
    end
end

function start()
    shutdown()
    
    cfg = conf.loadConfig(CFG_FNAME, setmetatable({}, {__index={sides=sides, colors=colors}}))
    cfg = cfg or {}
    --unload convienence tables

    if cfg.path == nil then cfg.path = '/etc/screencontrol' end
    if cfg.defaultInterval == nil then cfg.defaultInterval = 1 end

    if not cfg.handlers then
        io.stderr:write('ScreenControl: Warning - No handlers defined\n')
        cfg.handlers = {}
    end
    scripts = {}
    handlers = {}
    foundScreen = true --assume we found the screen so we print an error if we don't find it later
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
    print('Screen Controller stopped and unloaded')
end

function config(cmd, key, value)
    if cmd == nil or string.lower(cmd) == 'get' then
        if key then
            printCfgValue(key)
            return
        end
        for k,_ in pairs(cfg) do
            printCfgValue(k)
        end
    elseif string.lower(cmd) == 'set' then
        if not key then 
            io.stderr:write('Key required to set\nUSAGE:\n screencontrol config set <key> <value>\n')
            return
        end
        if key == 'handlers' then 
            io.stderr:write('Cannot setup handlers through commandline\n')
            return
        end
        if key == 'defaultInterval' then value = tonumber(value) end
        cfg[key] = value
    elseif string.lower(cmd) == 'save' then
        local s, e = conf.saveConfig(CFG_FNAME, cfg)
        if not s then
            io.stderr:write('Error saving config: ' .. e .. '\n')
            return
        end
        print('Configuration saved to ' .. CFG_FNAME)
    else
        io.stderr:write('Unknown command "' .. cmd .. '"\n')
        io.stderr:write([=[
USAGE:
  screencontrol config [get [<KEY>]]
    Prints value of current configuration key, or all keys if KEY is not provided
 
  screencontrol config set <KEY> [<VALUE>]
    Sets the configuration value of <KEY> to <VALUE>. If <VALUE> is not specified it is set to nil
    Cannot be used to setup handlers

  screencontrol config save
    Saves the current configuration
        ]=])
    end
end