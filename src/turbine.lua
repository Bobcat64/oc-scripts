local component = require("component")
local shell = require("shell")

local args, opts = shell.parse(...)

local function showHelp()
    print("Usage: turbine [options] [on|off|clear]"..[[
  -f --full  Display all statistics
  -h --help  Display this help

  on         Sets the turbine active
  off        Deactivates turbine (redstone could keep it going)
  clear      Clears all materials
]]
    )
end

if opts.h or opts.help then
    showHelp()
    return
end

-- for now just display stats for the default component
local turbine = component.nc_turbine

if not turbine then
    print("Turbine component not found")
    return 1
end

if not turbine.isComplete() then
    print("Turbine structure is incomplete")
    return 1
end

local cmd = args[1]
if cmd then
    if string.lower(args[1]) == "on" then
        turbine.activate()
    elseif string.lower(args[1]) == "off" then
        turbine.deactivate()
    elseif string.lower(args[1]) == "clear" then
        turbine.clearAllMaterial()
    else
        showHelp()
        return
    end
end
local stored = turbine.getEnergyStored()
local capacity = turbine.getEnergyCapacity()
local status = (turbine.isTurbineOn() and "active") or "inactive"
local processing = turbine.isProcessing()
if processing then status = "running" end
print(string.format("%dx%dx%d Turbine %s"
    , turbine.getLengthX()
    , turbine.getLengthY()
    , turbine.getLengthZ()
    , status))
print(string.format("%3.1f%% Stored: %d", (stored / capacity) * 100, stored))

if processing or opts.full or opts.f then
    print("Power: " .. tostring(turbine.getPower()))
    print("Input Rate: " .. tostring(turbine.getInputRate()))
end
if opts.full or opts.f then
    print(string.format("Energy Capacity: %g", turbine.getEnergyCapacity()))
    print(string.format("Dynamo Parts: %d", turbine.getNumberOfDynamoParts()))
    print(string.format("Conductivity: %.1f%%", turbine.getCoilConductivity() * 100))
    print()
    print("Blade Efficiency Expansion Ideal")
    local eff = table.pack(turbine.getBladeEfficiencies())
    local exp = table.pack(turbine.getExpansionLevels())
    for i, idl in ipairs(table.pack(turbine.getIdealExpansionLevels())) do
        print(string.format("%5d %10.2f %9.2f %5.2f", i, eff[i] * 100, exp[i] * 100, idl * 100))
    end
end