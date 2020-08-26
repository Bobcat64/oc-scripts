local event = require('event')

local monCls = {}
local lib = {}
local component = require('component')

local function raiseChangeEvent(monitor)
    event.push('geiger_change', monitor.name or monitor.address, monitor.state)
    monitor._lastRadiation = monitor.state.radiation --set the last alerted about radiation level
end

local function significantChange(cur, orig)
    if type(orig) ~= type(cur) then return true end
    if type(cur) ~= 'number' then return false end
    if orig == cur then return false end
    if orig == 0 then return true end --avoid division by 0
    return math.abs((orig - cur) / orig) >= 0.03 --require a 3% change in value
end

function monCls:update()
    local g
    if self.address then
        local address = component.get(self.address, "nc_geiger_counter")
        if not address then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
            return nil, 'Geiger Component Not Found'
        end
        self.address = address
        g = component.proxy(address)
    else
        if not component.isAvailable("nc_geiger_counter") then
            if self.state ~= nil then
                self.state=nil
                raiseChangeEvent(self)
            end
           return nil, "Geiger Component Not Found"
        end
        g = component.getPrimary("nc_geiger_counter")
        self.address = g.address
    end

    local state = self.state or {}

    local val = g.getChunkRadiationLevel()
    local didChange = significantChange(self._lastRadiation, val)
    state.radiation = val

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