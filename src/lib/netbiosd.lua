local component = require('component')
local event = require('event')
local fs = require('filesystem')
local shell = require('shell')
local conf = require('conf')

--TODO: Move this into a file
local cfg = {
    port=1,
    startMessage = 'netboot',
    loadMessage = 'netload',
    dirPath = '/opt/netbios',
    maxPacketSize = 8192 --supposedly modems have a method to return this, but doesn't seem present in OC 1.7.5
}

local eventId = nil

local lib = {}

local function getModem()
    if cfg.modem then
        local m = component.get(cfg.modem, 'modem')
        if m == nil then return nil end
        return component.proxy(m)
    end
    if not component.isAvailable('modem') then return nil end
    return component.getPrimary('modem')
end

local function modemHandler(_, rcv, snd, port, dist, mtype, name)
    if port ~= cfg.port then return end
    if mtype ~= cfg.startMessage then return end
    
    if type(name) ~= 'string' then return end --invalid message
    
    local path = shell.resolve(fs.concat(cfg.dirPath, name))
    if not path then return end
    local f = io.open(path)
    if not f then return end

    local m = getModem()
    if not m then
        event.onError('netbiosd: Unable to find modem to respond to ' .. name)
    end
    --3 values sent, the load message, the name of the recipient, and the file contents itself
    local maxSize = cfg.maxPacketSize - 6 - #cfg.loadMessage - #name

    local segment = f:read(maxSize)
    while segment ~= nil do
        m.send(snd, port, cfg.loadMessage, name, segment)
        segment = f:read(maxSize)
    end
    --send final message to complete loading
    m.send(snd, port, cfg.loadMessage, name, segment)
    f:close()
end


function lib.loadConfig()
    local defConfig = {
        port=1,
        startMessage = 'netboot',
        loadMessage = 'netload',
        dirPath = '/opt/netbios',
        maxPacketSize = 8192 --supposedly modems have a method to return this, but doesn't seem present in OC 1.7.5
    }
    cfg = conf.loadConfig('/etc/netbiosd.cfg', setmetatable({}, {__index=defConfig, math=math}))
    if cfg == nil then cfg=defConfig end
    return lib.getConfig()
end

function lib.getConfig()
    return cfg
end

function lib.start()
    if not eventId then
        local m = getModem()
        if m == nil then error('Unable to find modem') end
        m.open(cfg.port)
        eventId = event.listen('modem_message', modemHandler)
        return true
    end
    return false, 'Already Running'
end

function lib.stop()
    if not eventId then
        return false, 'Not Running'
    end
    event.cancel(eventId)
    eventId = nil
    return true
end

lib.loadConfig()

return lib