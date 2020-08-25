local event = require('event')

local monCls = {}
local lib = {}
--Reactor Monitor
local component = require('component')

local function raiseChangeEvent(monitor)
    event.push('reactor_change', monitor.name or monitor.address, monitor.state)
end


function monCls:update()
    local r
    if self.address then
        local address = component.get(self.address, "nc_salt_fission_reactor")
        if not address then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
            return nil, 'Reactor Component Not Found'
        end
        self.address = address
        r = component.proxy(address)
    else
        if not component.isAvailable("nc_salt_fission_reactor") then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
           return nil, "Reactor Component Not Found"
        end
        r = component.getPrimary("nc_salt_fission_reactor")
        self.address = r.address
    end

    local state = self.state or {}
    
    local val = r.isComplete()
    local didChange = val ~= state.isComplete
    state.isComplete = val

    val = r.isReactorOn()
    didChange = didChange or val ~= state.isOn
    state.isOn = val

    val = r.getRawHeatingRate()
    didChange = didChange or val ~= state.HeatingRate
    state.HeatingRate = val
    
    val = r.getCoolingRate()
    didChange = didChange or val ~= state.coolingRate
    state.coolingRate = val

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