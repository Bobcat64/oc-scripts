local shell = require('shell')
args, opts = shell.parse(...)

local rnav = require('robotnav')

if opts.r or opts.reload then rnav.reloadConfig() end

local loc = rnav.locations[args[1]]

if not args[1] or not loc then
  print("locations:")
  for l, _ in pairs(rnav.locations) do
    print(" " .. l)
  end
  return
end

local s, err = rnav.navigateTo(loc, tonumber(opts.max))
if not s then
  print(err)
  return
end

if (opts.f or opts.face) and #loc > 3 and loc[4] then
  rnav.turnToFace(loc[4])
end
