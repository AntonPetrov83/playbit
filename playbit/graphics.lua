!if LOVE2D then
playbit = playbit or {}
local module = {}
playbit.graphics = module

-- #b0aea7
module.COLOR_WHITE = { 176 / 255, 174 / 255, 167 / 255, 1 }
-- #312f28
module.COLOR_BLACK = { 49 / 255, 47 / 255, 40 / 255, 1 }

module.colorWhite = module.COLOR_WHITE
module.colorBlack = module.COLOR_BLACK

-- draw modes
module.LINE  = 0
module.FILL  = 1
module.IMAGE = 2

module.shaders =
{
  final   = love.graphics.newShader("playbit/shaders/final.glsl"),
  color   = love.graphics.newShader("playbit/shaders/color.glsl"),
  pattern = love.graphics.newShader("playbit/shaders/pattern.glsl"),
  image   = { }
}

local shader = love.filesystem.read("playbit/shaders/image.glsl")
for i = 0, 9 do
  local src = "#define DRAW_MODE " .. i .. "\n" .. shader
  module.shaders.image[i] = love.graphics.newShader(src)
end

module.shaders.final:send("white", module.colorWhite)
module.shaders.final:send("black", module.colorBlack)

module.imageDrawMode = 0
module.drawOffset = { x = 0, y = 0}
module.drawColor = 1
module.backgroundColor = 0
module.activeFont = {}
module.drawMode = -1
module.canvas = love.graphics.newCanvas()
module.contextStack = {}
-- shared quad to reduce gc
module.quad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
module.lastClearColor = 1
module.drawPattern = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
module.debugDrawColor = { 1, 0, 0, 0.5 }

local canvasScale = 1
local canvasWidth = 400
local canvasHeight = 240
local canvasX = 0
local canvasY = 0
local windowWidth = 400
local windowHeight = 240
local fullscreen = false

local colorByIndex = {
  [0] = { 0, 0, 0, 1 },
  [1] = { 1, 1, 1, 1 },
  [2] = { 0, 0, 0, 0 }
}

--- Sets the scale of the canvas.
---@param scale number
function module.setCanvasScale(scale)
  canvasScale = scale
end

---Returns the current scale of the canvas.
---@return number
function module.getCanvasScale()
  return canvasScale
end

--- Sets the canvas size.
---@param width number
---@param height number
function module.setCanvasSize(width, height)
  canvasWidth = width
  canvasHeight = height
end

--- Returns the current canvas size.
---@return integer width
---@return integer height
function module.getCanvasSize()
  return canvasWidth, canvasHeight
end

--- Sets the canvas position within the window.
---@param x any
---@param y any
function module.setCanvasPosition(x, y)
  canvasX = x
  canvasY = y
end

--- Returns the current canvas position within the window.
---@return integer x
---@return integer y
function module.getCanvasPosition()
  return canvasX, canvasY
end

--- Sets the size of the window.
---@param width number
---@param height number
function module.setWindowSize(width, height)
  windowWidth = width
  windowHeight = height
end

--- Returns the current window size.
---@return integer width
---@return integer height
function module.getWindowSize()
  return windowWidth, windowHeight
end

--- Sets fullscreen (true) or window mode (false).
---@param enabled any
function module.setFullscreen(enabled)
  fullscreen = enabled
end

--- Returns if the game is in fullscreen (true) or window mode (false).
---@return boolean
function module.getFullscreen()
  return fullscreen
end

--- Sets the colors used when drawing graphics.
---@param white table An array of 4 values that correspond to RGBA that range from 0 to 1.
---@param black table An array of 4 values that correspond to RGBA that range from 0 to 1.
function module.setColors(white, black)
  module.colorWhite = white or module.COLOR_WHITE
  module.colorBlack = black or module.COLOR_BLACK

  module.shaders.final:send("white", module.colorWhite)
  module.shaders.final:send("black", module.colorBlack)
end

function module.clear(color)
  local c = colorByIndex[color]
  love.graphics.clear(c[1], c[2], c[3], c[4])
end

--- Sets the current drawing color for primitives.
function module.setDrawColor(color)
  module.usePattern = false
  module.drawColor = color
  local c = colorByIndex[color]
  module.shaders.color:send("drawColor", c)
end

local function unpackPattern(pattern)
  local pixels = {}
  for i = 1, 8 do
    for j = 7, 0, -1 do
      local b = bit.lshift(1, j)
      if bit.band(pattern[i], b) == b then
        table.insert(pixels, 1)
      else
        table.insert(pixels, 0)
      end
    end
  end
  return pixels
end

--- Sets the 8x8 pattern used for drawing of primitives.
function module.setPattern(pattern)
  module.usePattern = true
  module.drawPattern = pattern
  local pixels = unpackPattern(pattern)
  module.shaders.pattern:send("pattern", unpack(pixels))
end

local function copyAndSwapCanvases()
  local shader = love.graphics.getShader()

  -- create second canvas if needed of the same size.
  if not module.canvas2 then
    local w, h = module.canvas:getWidth(), module.canvas:getHeight()
    module.canvas2 = love.graphics.newCanvas(w, h)
  end

  -- copy original canvas to another one
  love.graphics.setCanvas(module.canvas2)
  love.graphics.setShader()
  love.graphics.draw(module.canvas)

  -- swap canvases.
  module.canvas, module.canvas2 = module.canvas2, module.canvas

  -- restore shader and the color
  love.graphics.setShader(shader)
end

--- Sets the current drawing mode for images.
function module.setImageDrawMode(mode)
  module.imageDrawMode = mode
  -- invalidate draw mode to set proper shader
  module.drawMode = -1
end

local function getShader(mode)
  if mode == module.LINE then
    return module.shaders.color
  end

  if mode == module.FILL then
    if module.usePattern then
      return module.shaders.pattern
    else
      return module.shaders.color
    end
  end

  if mode == module.IMAGE then
    return module.shaders.image[module.imageDrawMode]
  end
end

function module.setDrawMode(mode)
  if module.drawMode ~= mode then

    module.drawMode = mode

    local shader = getShader(mode)

    -- TODO: we have to do this before every drawing call.
    if shader:hasUniform("canvas") then
      copyAndSwapCanvases()
      shader:send("canvas", module.canvas2)
    end

    love.graphics.setShader(shader)
  end
end

function module.updateContext()
  if #module.contextStack == 0 then
    return
  end

  local activeContext = module.contextStack[#module.contextStack]

  -- love2d doesn't allow calling newImageData() when canvas is active
  love.graphics.setCanvas()
  local imageData = activeContext._canvas:newImageData()
  love.graphics.setCanvas(activeContext._canvas)

  -- update image
  activeContext.data:replacePixels(imageData)
end
!end