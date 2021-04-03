local m = component.proxy(component.list('modem')())
local name = component.proxy(component.list('eeprom')()).getLabel()
local PORT= 1
local h = {}
local c={}
local code = ''
local function dispatch(evt, ...)
    if h[evt] then
        pcall(h[evt], ...)
        return true
    end
    return false
end
local function pullSignal(timeout)
    local e = table.pack(computer.pullSignal(timeout))
    dispatch(table.unpack(e))
    return table.unpack(e)
end
function h.modem_message(_, ra, p, _, cmd, n, ...)
    if p ~= PORT then return end
    if cmd == nil then return end
    if n ~= name then return end
    if c[cmd] == nil then return end
    local s, r = pcall(c[cmd], ra, ...)
    if not s then
        m.close()
        m.open(PORT)
        m.send(ra, PORT, 'error', name, r)
        computer.beep(1000, 0.2)
    end
end
function c.netload(_, d)
    if d ~= nil and type(d) == 'string' and #d > 0 then
        code = code .. d
        return
    end
    local ch, err = load(code, '=netbios', "t", setmetatable({modem=m}, {__index=_G}))
    code = ''    
    if not ch then error(err) end
    m.close()
    ch()
    m.close()
    m.open(PORT)
end
function c.netload_clear()
    code = ''
end
function c.ping(ra, ...)
    m.send(ra, PORT, 'pong', name, ...)
end
function c.beep(_, ...)
    computer.beep(...)
end
function c.shutdown(_, reboot)
    computer.shutdown(reboot or false)
end
m.open(PORT)
computer.beep(800,0.05)
computer.beep(1200,0.05)
m.broadcast(PORT, 'netboot', name)
while true do 
    pullSignal()
end