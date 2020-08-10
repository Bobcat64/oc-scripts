local component = require('component')
local sides = require('sides')
local inv = component.inventory_controller
local robot = require('robot')
local shell = require('shell')
local args, opts = shell.parse(...)

--TODO: Documentation

local slot = tonumber(opts.slot)
local amount = tonumber(args[1]) or math.huge

local s = sides.forward
if opts.u or opts.up then s = sides.up end
if opts.d or opts.down then s = sides.down end

local toSlot = tonumber(opts.to)
local oldSlot = nil
if toSlot ~= nil then
  oldSlot = robot.select()
  robot.select(toSlot)
end

local verbose = opts.v or opts.verbose
local name = ""
if verbose and inv then
  local stack = inv.getStackInSlot(s)
  if stack then name = stack.name .. " " end
end

local success = false
if slot then
  success = inv.suckFromSlot(s, slot, amount)
else
  if s == sides.up then
    success = robot.suckUp(amount)
  elseif s == sides.down then
    success = robot.suckDown(amount)
  else
    success = robot.suck(amount)
  end
end

if verbose then
  print(name .. tostring(success))
end

if toSlot then robot.select(oldSlot) end