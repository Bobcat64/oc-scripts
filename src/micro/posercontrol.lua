m = component.proxy(component.list('modem')())
taddr = component.list('transposer')()
rom = component.proxy(component.list('eeprom')())
name = rom.getLabel()
PORT=12
sides = {
  [0] = "bottom",
  [1] = "top",
  [2] = "back",
  [3] = "front",
  [4] = "right",
  [5] = "left",
  bottom = 0,
  top = 1,
  down = 0,
  up = 1,
  north = 2,
  south = 3,
  west = 4,
  east = 5,
  negy = 0,
  posy = 1,
  negz = 2,
  posz = 3,
  negx = 4,
  posx = 5
}

m.open(PORT)

computer.beep(800,0.1)
computer.beep(1200,0.1)

m.broadcast(PORT, 'posercontrol-on', name)

while true do
  e = table.pack(computer.pullSignal(1))
  if e and e[1] == 'modem_message' and e[4] == 12 then
    if e[6] == name then
      --except for DB related functions, all parameters are numbers or boolean
      --if we were given a string, use the sides lookup to make it a number
      --index 7 is the function to call
      for i=8,#e do
        if type(e[i]) == 'string' then
          e[i] = sides[e[i]]
        end
      end
      ret = table.pack(pcall(component.invoke, taddr, e[7], table.unpack(e, 8)))
      if not ret[1] then
        computer.beep(900,0.3)
        m.send(e[3], PORT, name, 'error', ret[2]:sub(1, 6000))
      else
        --the getFluidInTank returns a table, which will cause this to fail...
        m.send(e[3], PORT, name, table.unpack(ret, 2))
      end
    elseif e[6] == 'ping' then
      m.send(e[3], PORT, 'pong', name)
    elseif e[6] == 'poser-rename' and e[7] then
      name = e[7]
      rom.setLabel(name)
      computer.beep(1000,0.1)
      computer.beep(1050,0.1)
      m.send(e[3], PORT, name, 'renamed')
    end
  end
end