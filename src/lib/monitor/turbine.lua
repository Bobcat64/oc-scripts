local event = require('event')

local monCls = {}
local lib = {}
local component = require('component')

local function raiseChangeEvent(monitor)
    event.push('turbine_change', monitor.name or monitor.address, monitor.state)
    monitor._lastInputRate = monitor.state.inputRate
    monitor._lastPower = monitor.state.power
end

local function significantChange(cur, orig)
    if type(orig) ~= type(cur) then return true end
    if type(cur) ~= 'number' then return false end
    if orig == cur then return false end
    if orig == 0 then return true end
    return math.abs((orig - cur) / orig) >= 0.05 --require a 5% change in value
end

function monCls:update()
    local t
    if self.address then
        local address = component.get(self.address, "nc_turbine")
        if not address then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
            return nil, 'Turbine Component Not Found'
        end
        self.address = address
        t = component.proxy(address)
    else
        if not component.isAvailable("nc_turbine") then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
           return nil, "Turbine Component Not Found"
        end
        t = component.getPrimary("nc_turbine")
        self.address = t.address
    end

    local state = self.state or {}

    local val = t.isProcessing()
    local didChange = val ~= state.isProcessing
    state.isProcessing = val

    val = t.isTurbineOn()
    didChange = didChange or val ~= state.isOn
    state.isOn = val

    val = t.isComplete()
    didChange = didChange or val ~= state.isComplete
    state.isComplete = val

    val = t.getInputRate()
    didChange = didChange or significantChange(self._lastInputRate, val)
    state.inputRate = val

    val = t.getPower()
    didChange = didChange or significantChange(self._lastPower, val)
    state.power = val

    self.state = state

    if didChange then raiseChangeEvent(self) end

    return self.state
end

function monCls:shutdown() end

function lib.create(settings)
    local instance = {}
    if (type(settings) == 'table') then
        instance.name = settings.name
        instance.address = settings.address
    end
    return setmetatable(instance, {__index=monCls})
end

return lib