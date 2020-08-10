local component = require('component')
local robot = require('robot')
local sides = require('sides')

local conf = require('conf')

local cfg = nil
local lib = {}

local function getNav()
    local n = component.navigation
    if n == nil then error('No Navigation Component found', 1) end
    return n
end

function lib.reloadConfig()
    cfg = conf.loadConfig('/etc/nav.cfg',{sides=sides}) or {}
    if not cfg.offset then cfg.offset = {0,0,0} end
    lib.locations = cfg.locations or {}
end

function lib.saveConfig()
    return conf.saveConfig('/etc/nav.cfg', cfg)
end

function lib.setOffset(x,y,z)
    cfg.offset[1] = x or 0
    cfg.offset[2] = y or 0
    cfg.offset[3] = z or 0
end

function lib.getAbsPostion()
    local x,y,z = getNav().getPosition()
    x = x + cfg.offset[1]
    y = y + cfg.offset[2]
    z = z + cfg.offset[3]
    return x,y,z
end

function lib.moveToward(absPos)
    local x,y,z = lib.getAbsPostion()
    x = absPos[1] - x - 0.5
    y = absPos[2] - y + 0.5
    z = absPos[3] - z - 0.5

    if x == 0 and y == 0 and z == 0 then return false, 'In Position' end

    if y < 0 and not robot.detectDown() then
        return robot.down()
    elseif y > 0 and not robot.detectUp() then
        return robot.up()
    end
    local nav = getNav()
    local facing, neg, fore
    local zaxis = false

    local function evalFacing()
        facing = nav.getFacing()
        neg, fore = robot.back, robot.forward
        if facing == sides.north or facing == sides.south then
            zaxis = true
            if facing == sides.north then neg, fore = robot.forward, robot.back end
        elseif facing == sides.west then
            zaxis = false
            neg, fore = robot.forward, robot.back
        end
    end
    evalFacing()

    local function moveZ()
        if z < 0 then
            return neg()
        elseif z > 0 then
            return fore()
        end
        return false, 'In Axis'
    end

    local function moveX()
        if x < 0 then
            return neg()
        elseif x > 0 then
            return fore()
        end
        return false, 'In Axis'
    end

    local r, err
    if zaxis then
        if moveZ() then return true end
        robot.turnLeft()
        evalFacing()
        if moveX() then
            return true
        else --attempt to get unstuck
            r, err = robot.forward()
            if r then robot.turnRight() end
            return r, err
        end
    else
        if moveX() then return true end
        robot.turnLeft()
        evalFacing()
        if moveZ() then
            return true
        else --attempt to get unstuck
            r, err = robot.forward()
            if r then robot.turnRight() end
            return r, err
        end
    end
end

function lib.turnToFace(facing)
    checkArg(1, facing, 'number')
    if facing == sides.up or facing == sides.down then return end --ignore invalid facings
    local cur = getNav().getFacing()
    if facing == cur then return end
    local n,s,w,e = sides.north, sides.south, sides.west, sides.east
    local l,r,a = robot.turnLeft, robot.turnRight, robot.turnAround
    local m = {
        --to   --from
        [n] = {[s]=a,[w]=r,[e]=l},
        [s] = {[n]=a,[w]=l,[e]=r},
        [w] = {[n]=l,[s]=r,[e]=a},
        [e] = {[n]=r,[s]=l,[w]=a}
    }
    m[facing][cur]()
end

function lib.navigateTo(pos, maxIter)
    maxIter = maxIter or 100
    local os = require('os')
    local i = 0
    local nomoves = 0 --number of times we have not moved
    local moved, reason = lib.moveToward(pos)
    while reason ~= 'In Position' do
        os.sleep(0.1)
        if not moved then
            nomoves = nomoves + 1
            if nomoves > 4 then
                return false, 'Stuck' --not very descriptive...
            end
            robot.turnLeft()
        else
            nomoves = 0
        end
        moved, reason = lib.moveToward(pos)
        i = i + 1
        if i > maxIter then return false, 'Max Iterations reached' end
    end
    return true
end

lib.reloadConfig()

return lib