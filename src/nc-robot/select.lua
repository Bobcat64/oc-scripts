local robot = require('robot')
local args = table.pack(...)

if #args == 0 then
  print(robot.select())
  return
end

print(robot.select(tonumber(args[1])))