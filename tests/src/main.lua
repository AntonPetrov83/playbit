@@"header.lua"
import("CoreLibs/graphics")

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

function playdate.update()
  local paths = playdate.file.listFiles("suites")
  for i=1, #paths do
    local path = paths[i]
    -- strip the extension
    path = string.sub(path, 1, #path - 4)
    local tests = playdate.file.load("suites/"..path)()
    for j=1, #tests do
      local test = tests[j]
      local testName = path.."_"..test[1]
      test[2]()

!if LOVE2D then
      love.graphics.setCanvas()
      local actualData = playbit.graphics.canvas:newImageData()
      local expectedData = love.image.newImageData("images/expected/"..testName..".png")
      if not doImagesMatch(expectedData, actualData) then
        print(testName.."=fail")
      else
        print(testName.."=pass")
      end
      love.filesystem.createDirectory("images/actual")
      actualData:encode("png", "images/actual/"..testName..".png")
      love.graphics.setCanvas(playbit.graphics.canvas)
!else
      local image = playdate.graphics.getWorkingImage()
      playdate.simulator.writeToFile(image, "tests/src/images/expected/"..testName..".png")
!end
    end
  end
  
!if LOVE2D then
  love.event.quit()
!else
  playdate.simulator.exit()
!end
end

