local computer = require("computer")
local component = require("component")
local event = require("event")
local g = component.gpu

local CTK = {}

CTK.char = "  " --draw character, used to determine if we are double drawing or not
CTK.draws = {} -- holds funcs for different texture draw methods
CTK.loads = {} -- holds funcs for different texture load methods
CTK.texList = {} -- list of all loaded textures
CTK.vars = {} -- holds arbitrary data
--CTK.vars.mode -- determines what draw/load functions are used




function CTK.refreshPallet()
    g.setPaletteColor(0, 0x0f0f0f)
    g.setPaletteColor(1, 0x1e1e1e)
    g.setPaletteColor(2, 0x2d2d2d)
    g.setPaletteColor(3, 0x3c3c3c)
    g.setPaletteColor(4, 0x4b4b4b)
    g.setPaletteColor(5, 0x5a5a5a)
    g.setPaletteColor(6, 0x696969)
    g.setPaletteColor(7, 0x787878)
    g.setPaletteColor(8, 0x878787)
    g.setPaletteColor(9, 0x969696)
    g.setPaletteColor(10, 0xa5a5a5)
    g.setPaletteColor(11, 0xb4b4b4)
    g.setPaletteColor(12, 0xc3c3c3)
    g.setPaletteColor(13, 0xd2d2d2)
    g.setPaletteColor(14, 0xe1e1e1)
    g.setPaletteColor(15, 0xf0f0f0)
end

function CTK.drawFast(tex)
	--set buffer to the tex
	if g.setActiveBuffer(tex.ID) == nil then
		print("Malformed Fast Texture")
		return
	end
	
	--copy tex to swap buffer screen
	g.bitblt(1, tex.x * #CTK.char - 1, tex.y)
	
	--set buffer back to screen NEED?
	--g.setActiveBuffer(0)
	return
end

function CTK.drawSlow(tex)

	--read size of textures x and y
	local w = #tex.pixels
	local h = #tex.pixels[1]
  
  	--set buffer to the swap buffer
	if g.setActiveBuffer(1) == nil then
		print("No buffer set")
		return
	end

  --read each to get pallet table index then render each pixel
  for y = 1, h, 1 do
    for x = 1, w, 1 do
      local color = CTK.pallet[string.byte(tex.pixels[x][y])]
      g.setBackground(tonumber(color))
      g.set((x-1+tex.x) * #CTK.char - 1, y + tex.y - 1, CTK.char)
    end
  end

	--set buffer back to screen
	g.setActiveBuffer(0)
	return
end

function CTK.drawTrans(tex)

end

function CTK.draw(tex)
	--Use the correct function based off mode
	local func = CTK.draws[CTK.vars.mode]
	if(func) then
		func(tex)
	else
		print "Malformed mode flag"
	end
end

function CTK.loadFast(path)
  --open file
  local file = io.open(path, "rb")

  --check if nil
  if file == nil then
    print("File not found.")
    return
  end

  --read size of image x and y
  local line = file:read("*l")
  local w = line
  line = file:read("*l")
  local h = line

  --allocate buffer and set it active
  local bufferID = g.allocateBuffer(tonumber(w) * #CTK.char, tonumber(h))
  g.setActiveBuffer(bufferID)

  --read 1 byte to get pallet table index
  for y = 1, h, 1 do
    for x = 1, w, 1 do
      local index = file:read(1)
      local color = CTK.pallet[string.byte(index)]
      g.setBackground(tonumber(color))
	  g.set(x * #CTK.char - 1 ,y, CTK.char)
    end
  end

  --close file
  io.close(file)

  --set buffer back to screen
   g.setActiveBuffer(0)
   
  --return buffer
  local tex = {}
  tex.ID = bufferID
  tex.x = 1
  tex.y = 1
  table.insert(CTK.texList, tex)
  return #CTK.texList
end

function CTK.loadSlow(path)
  
  --open file
  local file = io.open(path, "rb")

  --check if nil
  if file == nil then
    print("File not found.")
    return
  end

  --read size of image x and y GET RID OF SOON
  local line = file:read("*l")
  local w = line
  line = file:read("*l")
  local h = line

  --create table the size we need for the tex
  local tex = {}
  tex.pixels = {}
  for i = 1, w do
    tex.pixels[i] = {}
  end

  --read 1 byte to get pallet table index
  for y = 1, h, 1 do
    for x = 1, w, 1 do
      local index = file:read(1)
      tex.pixels[x][y] = index
    end
  end

  --close file
  io.close(file)

	--set texture pos
	tex.x = 1
	tex.y = 1
	table.insert(CTK.texList, tex)
  return #CTK.texList
end

function CTK.loadTrans(path)

end

function CTK.load(path)
	--Use the correct function based off mode
	local func = CTK.loads[CTK.vars.mode]
	if(func) then
		return func(path)
	else
		print "Malformed mode flag"
	end
end

function CTK.close()
	--clear all data related to CTK
	for k in pairs (CTK.texList) do
    CTK.texList[k] = nil
	end

	g.freeAllBuffers()
	g.setActiveBuffer(0)
end

function CTK.init(renderMode)
	--set render mode
	CTK.vars.mode = renderMode
	
	--load draw funcs
	CTK.draws = {
		[1] = CTK.drawFast,
		[2] = CTK.drawSlow,
		[3] = CTK.drawTrans
	}
	
	--load load funcs
	CTK.loads = {
		[1] = CTK.loadFast,
		[2] = CTK.loadSlow,
		[3] = CTK.loadTrans
	}
	
	--clear all buffers and create a full screen buffer to use for swapping to the main screen
	g.freeAllBuffers()
	g.allocateBuffer()

  --generate pallet table
  CTK.pallet = {}
  for count = 0, 239, 1 do
    local pRed = count % 6
    local pGreen = math.floor(count / 30)
    local pBlue = math.floor((count - pGreen * 30) / 6)
    
    local rTable = {"00", "33", "66", "99", "CC", "FF"}
    local gTable = {"00", "24", "49", "6D", "92", "B6", "BD", "FF"}
    local bTable = {"00", "40", "80", "C0", "FF"}
  
    pRed = rTable[pRed+1]
    pGreen = gTable[pGreen+1]
    pBlue = bTable[pBlue+1]
  
    local pColor = "0x"
    pColor = pColor .. pRed
    pColor = pColor .. pGreen
    pColor = pColor .. pBlue
    CTK.pallet[count] = pColor
  end
  
  table.insert(CTK.pallet, "0x0F0F0F")
  table.insert(CTK.pallet, "0x1E1E1E")
  table.insert(CTK.pallet, "0x2D2D2D")
  table.insert(CTK.pallet, "0x3C3C3C")
  table.insert(CTK.pallet, "0x4B4B4B")
  table.insert(CTK.pallet, "0x5A5A5A")
  table.insert(CTK.pallet, "0x696969")
  table.insert(CTK.pallet, "0x787878")
  table.insert(CTK.pallet, "0x878787")
  table.insert(CTK.pallet, "0x969696")
  table.insert(CTK.pallet, "0xA5A5A5")
  table.insert(CTK.pallet, "0xB4B4B4")
  table.insert(CTK.pallet, "0xC3C3C3")
  table.insert(CTK.pallet, "0xD2D2D2")
  table.insert(CTK.pallet, "0xE1E1E1")
  table.insert(CTK.pallet, "0xF0F0F0")
end

function CTK.resolve()
	--draw all loaded textures
	for i,v in ipairs(CTK.texList) do
		CTK.draw(v)
	end

	--buffer swap
	g.setActiveBuffer(1)
	g.bitblt()
end


return CTK