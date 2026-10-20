!if LOVE2D then
playbit = playbit or {}
local module = {}
playbit.graphics = module

module.SCR_WIDTH  = 400
module.SCR_HEIGHT = 240

-- #b0aea7
module.COLOR_WHITE = { 176 / 255, 174 / 255, 167 / 255, 1 }
-- #312f28
module.COLOR_BLACK = { 49 / 255, 47 / 255, 40 / 255, 1 }

module.colorWhite = module.COLOR_WHITE
module.colorBlack = module.COLOR_BLACK

local stencilShaderCode = love.filesystem.read("playbit/shaders/stencil.glsl")

-- drawing shaders get the stencil code and optional defines right after the "#pragma language" line
local function newDrawingShader(path, defines)
  local code = love.filesystem.read(path)
  local pragma, body = string.match(code, "^(#pragma[^\n]*\n)(.*)$")
  if not pragma then
    pragma, body = "", code
  end
  return love.graphics.newShader(pragma .. (defines or "") .. stencilShaderCode .. body)
end

module.shaders =
{
  final   = love.graphics.newShader("playbit/shaders/final.glsl"),
  color   = newDrawingShader("playbit/shaders/color.glsl"),
  pattern = newDrawingShader("playbit/shaders/pattern.glsl"),
  image   = { }
}

for i = 0, 9 do
  module.shaders.image[i] = newDrawingShader("playbit/shaders/image.glsl", "#define DRAW_MODE " .. i .. "\n")
end

module.shader = nil
module.drawOffset = { x = 0, y = 0}
module.drawColorIndex = 1
module.drawColor = module.colorWhite
module.backgroundColorIndex = 0
module.backgroundColor = module.colorBlack
module.activeFont = nil
module.imageDrawMode = 0
module.canvas = love.graphics.newCanvas()
module.contextStack = {}
-- shared quad to reduce gc
module.quad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
module.lastClearColor = module.colorWhite
module.drawPattern = nil
module.fallbackFont = nil
module.lineWidth = 1
module.debugDrawColor = { 1, 0, 0, 0.5 }

module.textToImageDrawMode = {
  ["copy"] = 0,
  ["inverted"] = 7,
  ["xor"] = 5,
  ["nxor"] = 6,
  ["whitetransparent"] = 1,
  ["blacktransparent"] = 2,
  ["fillwhite"] = 3,
  ["fillblack"] = 4
}

local canvasScale = 1
local canvasWidth = module.SCR_WIDTH
local canvasHeight = module.SCR_HEIGHT
local canvasX = 0
local canvasY = 0
local windowWidth = module.SCR_WIDTH
local windowHeight = module.SCR_HEIGHT
local fullscreen = false
local fullscreenType = "desktop"

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

--- Sets the fullscreen type either "desktop" (default) or "exclusive".
--- https://love2d.org/wiki/FullscreenType
---@param type any
function module.setFullscreenType(type)
  fullscreenType = type
end

--- Returns the current fullscreen type.
--- @param type any
--- @return string
function module.getFullscreenType(type)
  return fullscreenType
end

local presenter = nil

--- Sets the function that outputs the finished canvas to the screen, nil restores the default one.
--- The presenter draws the canvas at x, y scaled by scale. The canvas is 1-bit: red 1 is white, 0 is black,
--- white and black are the colors set with setColors().
---@param fn function|nil function(canvas, x, y, scale, white, black)
function module.setPresenter(fn)
  presenter = fn
end

--- Returns the custom presenter, nil if the default one is used.
---@return function|nil
function module.getPresenter()
  return presenter
end

--- Sets the colors used when drawing graphics.
---@param white table An array of 4 values that correspond to RGBA that range from 0 to 1.
---@param black table An array of 4 values that correspond to RGBA that range from 0 to 1.
function module.setColors(white, black)
  module.colorWhite = white or module.COLOR_WHITE
  module.colorBlack = black or module.COLOR_BLACK
end

local function copyAndSwapCanvases()
  local shader = love.graphics.getShader()

  -- create second canvas if needed of the same size.
  if not module.canvas2 then
    local w, h = module.canvas:getWidth(), module.canvas:getHeight()
    module.canvas2 = love.graphics.newCanvas(w, h)
  end

  -- copy original canvas to another one
  love.graphics.push()
  love.graphics.origin()
  love.graphics.setCanvas(module.canvas2)
  love.graphics.setShader()
  love.graphics.draw(module.canvas)
  love.graphics.pop()

  -- swap canvases.
  module.canvas, module.canvas2 = module.canvas2, module.canvas

  -- restore shader and the color
  love.graphics.setShader(shader)
end

local function getShader(mode, imageDrawMode)
  if mode == "line" then
    return module.shaders.color

  elseif mode == "fill" then
    if module.drawPattern then
      return module.shaders.pattern
    else
      return module.shaders.color
    end

  elseif mode == "image" then
    return module.shaders.image[imageDrawMode]
  end
end

-- current stencil as { image = love image, tiled = boolean } or nil
module.stencil = nil
-- incremented on every stencil change, so each shader gets the new uniforms once
module.stencilVersion = 0
local shaderStencilVersions = setmetatable({}, { __mode = "k" })

---@param image any love image used as the stencil, nil to clear it
---@param tiled boolean
function module.setStencil(image, tiled)
  if image then
    module.stencil = { image = image, tiled = tiled }
  else
    module.stencil = nil
  end
  module.stencilVersion = module.stencilVersion + 1
end

-- ordered dither matrices, values are thresholds from 0 to size*size-1
local ditherMatrices = {
  [5] = { size = 2, 0, 2, 3, 1 },
  [6] = { size = 4, 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 },
  [7] = { size = 8,
     0, 32,  8, 40,  2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44,  4, 36, 14, 46,  6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
     3, 35, 11, 43,  1, 33,  9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47,  7, 39, 13, 45,  5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
  }
}

-- returns 8 rows of a pattern where a set bit (most significant = leftmost pixel) marks level fraction of pixels
function module.getDitherPatternRows(level, ditherType)
  local matrix = ditherMatrices[ditherType or 7]
  if not matrix then
    error("[ERR] Dither type "..tostring(ditherType).." is not yet implemented.")
  end

  local size = matrix.size
  local threshold = level * size * size
  local rows = {}
  for y = 0, 7 do
    local row = 0
    for x = 0, 7 do
      if matrix[(y % size) * size + (x % size) + 1] < threshold then
        row = row + 2 ^ (7 - x)
      end
    end
    rows[y + 1] = row
  end
  return rows
end

-- rows from the (pattern), (row1, ..., row8) or (level, [ditherType]) forms of the stencil pattern functions
function module.getStencilPatternRows(...)
  local first = ...
  if type(first) == "table" then
    return first
  elseif select("#", ...) >= 8 then
    return { ... }
  else
    return module.getDitherPatternRows(...)
  end
end

local patternImages = {}

-- 8x8 image of the pattern rows, white where a bit is set, cached since patterns are often animated
function module.getPatternImage(rows)
  local key = table.concat(rows, ",", 1, 8)
  local image = patternImages[key]
  if not image then
    local imageData = love.image.newImageData(8, 8)
    for y = 0, 7 do
      local row = rows[y + 1]
      for x = 0, 7 do
        local c = math.floor(row / 2 ^ (7 - x)) % 2
        imageData:setPixel(x, y, c, c, c, 1)
      end
    end
    image = love.graphics.newImage(imageData)
    patternImages[key] = image
  end
  return image
end

local function sendStencil(shader)
  if shaderStencilVersions[shader] == module.stencilVersion then
    return
  end
  shaderStencilVersions[shader] = module.stencilVersion

  local stencil = module.stencil
  if stencil then
    shader:send("stencil", stencil.image)
    shader:send("stencilSize", { stencil.image:getWidth(), stencil.image:getHeight() })
    shader:send("stencilMode", stencil.tiled and 2 or 1)
  else
    shader:send("stencilMode", 0)
  end
end

function module.setDrawMode(mode, imageDrawMode)
  local shader = getShader(mode, imageDrawMode or module.imageDrawMode)
  sendStencil(shader)
  if module.shader ~= shader then
    module.shader = shader
    -- TODO: we have to do this before every drawing call.
    if shader:hasUniform("canvas") then
      copyAndSwapCanvases()
      shader:send("canvas", module.canvas2)
    end
    love.graphics.setShader(shader)
  end
end

-- Copies the current content of the image into its context canvas.
function module.beginContextImage(image)
  if not image._canvas then
    image._canvas = love.graphics.newCanvas(image:getSize())
  end

  local canvas = love.graphics.getCanvas()
  local shader = love.graphics.getShader()
  local r, g, b, a = love.graphics.getColor()
  local blendMode, alphaMode = love.graphics.getBlendMode()

  love.graphics.setCanvas(image._canvas)
  love.graphics.push()
  love.graphics.origin()
  love.graphics.setShader()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("replace", "premultiplied")
  love.graphics.draw(image.data, 0, 0)
  love.graphics.setBlendMode(blendMode, alphaMode)
  love.graphics.setColor(r, g, b, a)
  love.graphics.setShader(shader)
  love.graphics.pop()
  love.graphics.setCanvas(canvas)
end

-- Copies what was drawn into the active context canvas back into its image.
-- Drawing goes into a canvas, so the image itself is only updated when the context
-- is switched (pushContext/popContext) instead of after every draw call.
function module.updateContext()
  -- contexts pushed without an image keep drawing into the nearest image below them
  local image = nil
  for i = #module.contextStack, 1, -1 do
    image = module.contextStack[i].image
    if image then
      break
    end
  end

  if not image then
    return
  end

  -- love2d doesn't allow calling newImageData() when canvas is active
  local canvas = love.graphics.getCanvas()
  love.graphics.setCanvas()
  local imageData = image._canvas:newImageData()
  love.graphics.setCanvas(canvas)

  -- update image
  image.data:replacePixels(imageData)
end
!end
