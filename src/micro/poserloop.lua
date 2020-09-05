trans = component.proxy(component.list('transposer')())
rom = component.proxy(component.list('eeprom')())
name = rom.getLabel()

sides = {[0] = "bottom",[1] = "top",[2] = "back",[3] = "front",[4] = "right",[5] = "left",bottom = 0,top = 1,  down = 0,  up = 1,  north = 2,  south = 3,  west = 4,  east = 5,  negy = 0,  posy = 1,  negz = 2,  posz = 3,  negx = 4,  posx = 5}

config={
  {src=sides.up, srcSlot=1, snk=sides.south, snkSlot=1, stock=64},
  {src=sides.south, srcSlot=2, snk=sides.up, snkSlot=9, stock=math.huge},
  {src=sides.up, srcSlot=2, snk=sides.north, snkSlot=1, stock=64},
  {src=sides.north, srcSlot=2, snk=sides.up, snkSlot=9, stock=math.huge}
}

computer.beep(1000,0.1)
computer.beep(1400,0.1)

function handleTrans(cfg)
  local amt = trans.getSlotStackSize(cfg.src, cfg.srcSlot or 1)
  if amt == nil then computer.beep('..') computer.pullSignal(0.5) return end
  if amt <= 0 then return end
  local snkCount = trans.getSlotStackSize(cfg.snk, cfg.snkSlot or 1)
  if snkCount == nil then computer.beep('..-') computer.pullSignal(0.5) return end
  local toMove = cfg.stock - snkCount
  if toMove <= 0 then return end
  if cfg.exact and amt < toMove then return end
  if cfg.snkSlot then
      trans.transferItem(cfg.src, cfg.snk, toMove, cfg.srcSlot, cfg.snkSlot)
  else
      trans.transferItem(cfg.src, cfg.snk, toMove, cfg.srcSlot)
  end
end
while true do
  for _, c in ipairs(config) do
    handleTrans(c)
  end
  computer.pullSignal(2)
end