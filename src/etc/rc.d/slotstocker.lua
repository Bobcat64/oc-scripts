local component = require('component')
local conf = require('conf')
local event = require('event')
local sides = require('sides')

local CONFIG_PATH = '/etc/slotstocker.cfg'

--[[
    **EXAMPLE CONFIG**
local tmrcfg = {
    enabled=false, --optional, by default handlers are enabled
    address="cccc",
    source='west',
    sourceSlot=1,
    sink='east',
    sinkSlot=1,
    stock=8,
    exact=true,
    interval=2
}
]]--

local timers = {}
local cfg = {}

local function setupTimer(name, config)
    if timers[name] ~= nil then return end
    if not config then
        io.stderr:write('SlotStocker: Handler "' .. name .. '" has no configuration\n')
        return false
    end
    
    if not config.stock or type(config.stock) ~= 'number' then
        io.stderr:write('SlotStocker: ' .. name .. ' has invalid stock value: ' .. config.stock)
        return false
    end

    local src = config.source
    if type(src) == 'string' then
        src = sides[src]
    end
    if src == nil then
        io.stderr:write('SlotStocker: ' .. name .. ' has invalid source: ' .. tostring(config.source))
        return false
    end

    local snk = config.sink
    if type(snk) == 'string' then
        snk = sides[snk]
    end
    if snk == nil then
        io.stderr:write('SlotStocker: ' .. name .. ' has invalid sink: ' .. tostring(config.sink))
        return false
    end

    if not config.sourceSlot then config.sourceSlot = 1 end
    
    local function timerHandler()
       local trans = nil
       if config.address then
            trans = component.get(config.address, "transposer")
            if trans then trans = component.proxy(trans) end
       elseif component.isAvailable("transposer") then
            trans = component.getPrimary("transposer")
       end
 
        if not trans then
            if not config.warnedMissing then
                config.warnedMissing = true
                io.stderr:write('Stocker: ' .. name .. ' transposer not found ' .. config.address or '' .. '\n')
            end
            return
        end
        config.warnedMissing = nil

        --does source have anything?
        local amt = trans.getSlotStackSize(src, config.sourceSlot)
        if amt <= 0 then return end

        local toMove = config.stock - trans.getSlotStackSize(snk, config.sinkSlot or 1)
        if toMove <= 0 then return end
        if config.exact and amt < toMove then return end
        if config.sinkSlot then
            trans.transferItem(src, snk, toMove, config.sourceSlot, config.sinkSlot)
        else
            trans.transferItem(src, snk, toMove, config.sourceSlot)
        end
    end

    timers[name] = event.timer(config.interval or 1, timerHandler, math.huge)
    return true
end

local function shutdown()
    local hadOne = false
    for _,v in pairs(timers) do
        if v ~= nil then
            hadOne = true
            event.cancel(v)
        end
    end
    timers = {}
    return hadOne
end


function start(handler)
    if not handler then
        shutdown()
        local env = {math=math, table=table}
        cfg = conf.loadConfig(CONFIG_PATH, setmetatable({}, {__index=env}))
        if not cfg then
            io.stderr:write('SlotStocker: No configuration found at: ' .. CONFIG_PATH)
            return
        end
        for k,v in pairs(cfg) do
            if v.enabled or v.enabled == nil then
                setupTimer(k, v)
            end
        end
    else
        if not cfg[handler] then
            io.stderr:write('No configuration found for: ' .. handler)
            return
        end
        if timers[handler] ~= nil then
            print(handler .. ' is running')
        end

        if setupTimer(handler, cfg[handler]) then
            print(handler .. ' started')
        else
            io.stderr:write('Error starting ' .. handler .. '\n')
        end
    end
end

function stop(handler)
    if not handler then
        if shutdown() then
            print('SlotStocker stopped')
        else
            print('SlotStocker not running')
        end
    else
        if timers[handler] == nil then
            print(handler .. ' is not running')
        else
            event.cancel(timers[handler])
            timers[handler] = nil
            print(handler .. ' stopped')
        end
    end
end

function list()
    for k,v in pairs(cfg) do
        local running = 'running'
        local warn = ''
        if timers[k] == nil then 
            running = 'not running'
        elseif v.warnedMissing then
            warn = 'not found ' .. tostring(v.address)
        end
        print(k, running, warn)
    end
end

function unload() --TODO allow selective unloading
    shutdown()
    require('rc').unload('slotstocker')
    print('SlotStocker stopped and unloaded')
end