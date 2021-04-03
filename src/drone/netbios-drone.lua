local m = component.proxy(component.list('modem')())
local name = component.proxy(component.list('eeprom')()).getLabel()
local PORT= 1
local h = {}
local c={}
local code = ''
local moving=false
local running=true
drone.setStatusText('Starting')
drone.setLightColor(0x0033FF)
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
    local s, r = pcall(c[cmd](ra, ...))
    if not s then
        m.close()
        m.open(PORT)
        m.send(ra, PORT, 'error', name, r)
        drone.setStatusText(r)
        computer.beep(1000, 0.2)
    end
end
function c.netload(_, d)
    if #d > 0 then
        code = code .. d
        drone.setStatusText('Receiving')
        drone.setLightColor(0x00AAAA)
        return
    end
    local ch, err = load(code, '=netbios', "t", setmetatable({}, {__index=_ENV, modem=m}))
    code = ''
    m.close()
    moving=false --don't resume moving after executing
    if not ch then error(err) end
    drone.setStatusText('Running')
    drone.setLightColor(0xEEEEEE)
    ch()
    m.close()
    m.open(PORT)
    drone.setStatusText('Waiting')
    drone.setLightColor(0xAAAA00)
end
function c.netload_clear()
    code = ''
end
function c.ping(ra, ...)
    m.send(ra, PORT, 'pong', name, ...)
end
function c.move(ra, x, y, z, timeout)
    if moving then error('Already Moving') end
    local deadline = computer.uptime() + (timeout or 5)
    drone.move(x, y, z)
    moving = true
    m.send(ra, PORT, 'moving', name, x, y, z)
    while moving and drone.getOffset() > 1 do
        if computer.uptime() > deadline then
            m.send(ra, PORT, 'move_timeout', name)
            moving = false
            return
        end
        pullSignal(0.5)
    end
    moving =false
    if drone.getOffset() <= 1 then m.send(ra, PORT, 'moved', name, x, y, z) end
end
function c.stop()
    if moving then
        moving = false
        m.broadcast(PORT, 'stopping', name)
    end
end
function c.shutdown(reboot)
    computer.shutdown(reboot or false)
end
m.open(PORT)
computer.beep(800,0.05)
computer.beep(1200,0.05)
m.broadcast(PORT, 'netboot', name)
while running do
    local e = pullSignal(5)
    if e == nil then
        drone.setStatusText('Waiting')
        drone.setLightColor(0xAAAA00)
        --if not code then m.broadcast(PORT, 'netboot', name) end
    end
end