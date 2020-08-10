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

local fromSlot = tonumber(opts.from)
local toSlot = nil
if fromSlot ~= nil then
  toSlot = robot.select()
  robot.select(fromSlot)
end

local verbose = opts.v or opts.verbose
local name = ""
if verbose and inv then
  local stack = inv.getStackInInternalSlot()
  if stack then name = stack.name .. " " end
end

local success = false
if slot then
  success = inv.dropIntoSlot(s, slot, amount)
else
  if s == sides.up then
    success = robot.dropUp(amount)
  elseif s == sides.down then
    success = robot.dropDown(amount)
  else
    success = robot.drop(amount)
  end
end

if verbose then
  print(name .. tostring(success))
end

if toSlot then robot.select(toSlot) end