local component = require("component")
local shell = require("shell")
local sides = require("sides")


local args, opts = shell.parse(...)

local function help()
    print([=[
USAGE:
    trans <SOURCE> <SINK> [<AMOUNT>] [<options>]
      Transfers AMOUNT or all if not specified from SOURCE side to SINK side
      Options:
        --src=<SLOT>
          Transfers from source SLOT, defaults to 1
        --sink=<SLOT>
          Transfers to sink SLOT
    
    trans {-c | --check} <SIDE> [<SLOT>]
      Prints stack contents of SIDE's SLOT (or the first 10 slots if not specified)
]=])
end

if #args < 2 and not opts.c and not opts.check then
    help()
    return
end

local trans = component.getPrimary("transposer")

local function resolveSide(valStr, typ)
    local res = sides[valStr]
    if res == nil then
        io.stderr:write("Invalid " .. typ .. ' side: "' .. valStr .. '"\n')
        return nil
    end
    return res
end
local source = resolveSide(args[1], 'source')

if opts.c or opts.check then
    local serial = require('serialization')
    local slt = nil
    if args[2] then
        slt = tonumber(args[2])
        if slt == nil then
            io.write('Invalid slot: "' .. '"\n')
            return
        end
        print(serial.serialize(trans.getStackInSlot(source, slt)))
        return
    end
    
    local stacks = trans.getAllStacks(source)
    if not stacks.count() then
        print('Inventory empty')
        return
    end
    for n = 1, stacks.count(), 1 do
        if n > 10 then break end
        local s = stacks[n]
        if s.name ~= 'minecraft:air' then
            print(n, serial.serialize(stacks[n]))
        end
    end
    return
end


local sink = resolveSide(args[2], 'sink')



local amount = math.huge
if args[3] then
    amount = tonumber(args[3])
    if amount == nil then
        io.stderr:write("Invalid amount: '" .. args[3] .. '"\n')
        help()
        return
    end
end

if source == nil or sink == nil then
    help()
    return
end

local srcSlot = 1
local sinkSlot = nil

if opts.src then srcSlot = tonumber(opts.src) or 1 end
if opts.sink then sinkSlot = tonumber(opts.sink) end

if sinkSlot then
    print(trans.transferItem(source, sink, amount, srcSlot, sinkSlot))
else
    print(trans.transferItem(source, sink, amount, srcSlot))
end

