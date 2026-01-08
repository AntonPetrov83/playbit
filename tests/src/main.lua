@@"header.lua"

local font = playdate.graphics.font.new("fonts/Phozon/Phozon")
playdate.graphics.setFont(font)

-- playdate saves images in B&W so adjust playbit shader
!if LOVE2D then
playbit.graphics.setColors({1,1,1,1}, {0,0,0,1})
!end

function doImagesMatch(dataA, dataB)
  -- assume both images are playdate sized i.e. 400x240 pixels
  for x = 0, 399 do
    for y = 0, 239 do
      if dataA:getPixel(x, y) ~= dataB:getPixel(x, y) then
        return false
      end
    end
  end
  return true
end

function test_drawText()
  playdate.graphics.clear(1)
  playdate.graphics.drawText("HELLO WORLD", 0, 0)
end

function playdate.update()
  test_drawText()

!if LOVE2D then
  love.graphics.setCanvas()
  local screenData = playbit.graphics.canvas:newImageData()
  local fileData = love.image.newImageData("images/test_draw.png")
  if not doImagesMatch(fileData, screenData) then
    print("images do not match")
  end
!else
  local image = playdate.graphics.getWorkingImage()
  playdate.simulator.writeToFile(image, "tests/src/images/test_draw.png")
!end
  
!if LOVE2D then
  love.event.quit()
!else
  playdate.simulator.exit()
!end
end

