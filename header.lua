!if LOVE2D then
-- must be first, playbit and playdate modules rely on these functions too
require("playbit.compat")
require("playbit.graphics")

--[[ since there is no CoreLibs/playdate, this file should always
be included here so the methods are always available ]]--
require("playdate.playdate")
--[[ not really a way around including this one, but probably doesn't really
matter as all games are going to need to import graphics to draw stuff ]]--
require("playdate.graphics")

function import(path)
  if string.match(path, "^CoreLibs/") then
    path = string.gsub(path, "/", ".")
    path = string.gsub(path, "CoreLibs", "playdate")
    return require(path)
  end
  path = string.gsub(path, "/", ".")
  return require(path)
end

local firstFrame = true

-- initialize playbit window using initial love.window mode
local windowWidth, windowHeight, windowFlags = love.window.getMode()
playbit.graphics.setWindowSize(windowWidth, windowHeight)
playbit.graphics.setFullscreen(windowFlags.fullscreen)

-- window position to restore when switching back from fullscreen
local windowX, windowY, windowDisplay

playbit.graphics.canvas:setFilter("nearest", "nearest")

love.graphics.setDefaultFilter("nearest", "nearest")
love.graphics.setLineWidth(1)
love.graphics.setLineStyle("rough")

playdate.graphics.setBackgroundColor(playdate.graphics.kColorWhite)
playdate.graphics.setColor(playdate.graphics.kColorBlack)

math.randomseed(os.time())

playbit.graphics.fallbackFont = playdate.graphics.font.new("fonts/Phozon/Phozon")

local updateCoroutine
local transparentColor = { 0, 0, 0, 0 }

-- default presenter: draws the canvas to the screen with the final shader
local function present(canvas, x, y, scale, white, black)
  local shader = playbit.graphics.shaders.final
  shader:send("white", white)
  shader:send("black", black)
  shader:send("inverted", playdate.display.getInverted() and 1 or 0)
  shader:send("flip", playdate.display._flip)
  love.graphics.setShader(shader)
  love.graphics.draw(canvas, x, y, 0, scale, scale)
end

function love.draw()
  -- must be changed at start of frame when canvas is not active
  local newCanvasWidth, newCanvasHeight = playbit.graphics.getCanvasSize()
  local canvasWidth = playbit.graphics.canvas:getWidth()
  local canvasHeight = playbit.graphics.canvas:getHeight()
  if canvasWidth ~= newCanvasWidth or canvasHeight ~= newCanvasHeight then
    playbit.graphics.canvas = love.graphics.newCanvas(newCanvasWidth, newCanvasHeight)
  end

  -- must be changed at start of frame - love2d doesn't allow changing window size with canvas active
  local newWindowWidth, newWindowHeight = playbit.graphics.getWindowSize()
  local fullscreen = playbit.graphics.getFullscreen()
  local fullscreenType = playbit.graphics.getFullscreenType()
  local w, y, flags = love.window.getMode()
  if windowWidth ~= newWindowWidth or windowHeight ~= newWindowHeight or flags.fullscreen ~= fullscreen then
    if fullscreen and not flags.fullscreen then
      windowX, windowY, windowDisplay = flags.x, flags.y, flags.display
    elseif not fullscreen and flags.fullscreen then
      if windowX then
        flags.x, flags.y, flags.display = windowX, windowY, windowDisplay
      else
        -- the window started in fullscreen, so center it
        local desktopWidth, desktopHeight = love.window.getDesktopDimensions(flags.display)
        flags.x = math.floor((desktopWidth - newWindowWidth) / 2)
        flags.y = math.floor((desktopHeight - newWindowHeight) / 2)
      end
    end
    flags.fullscreen = fullscreen
    flags.fullscreentype = fullscreenType

    love.window.updateMode(newWindowWidth, newWindowHeight, flags)
    windowWidth = newWindowWidth
    windowHeight = newWindowHeight
  end

  -- render to canvas to allow 2x scaling
  love.graphics.setCanvas(playbit.graphics.canvas)

  --[[
    Love2d won't allow a canvas to be set outside of the draw function, so we need to do this on the first frame of draw.
    Otherwise setting the bg color outside of playdate.update() won't be consistent with PD.
  --]]
  if firstFrame then
    local c = playbit.graphics.lastClearColor
    love.graphics.clear(c.r, c.g, c.b, 1)
    firstFrame = false
  end

  -- love requires that this is set every loop
  local font = playbit.graphics.activeFont or playbit.graphics.fallbackFont
  love.graphics.setFont(font.data)

  -- push main transform for draw offset
  love.graphics.push()
  love.graphics.translate(playbit.graphics.drawOffset.x, playbit.graphics.drawOffset.y)

  -- input handlers before the main update
  playdate._updateInputHandlers()

  -- main update
  if not updateCoroutine or coroutine.status(updateCoroutine) == "dead" then
    updateCoroutine = coroutine.create(playdate.update)
  end

  local ok, err = coroutine.resume(updateCoroutine)
  if not ok then
    error(err)
  end

  -- pop main transform for draw offset
  love.graphics.pop()

  -- pop canvas
  love.graphics.setCanvas()

  -- store current shader
  local shader = love.graphics.getShader()

  -- draw canvas to screen
  local canvasScale = playbit.graphics.getCanvasScale()
  local canvasWidth, canvasHeight = playbit.graphics.getCanvasSize()
  -- fit into the actual window size, it differs from the requested one in fullscreen
  local screenWidth, screenHeight = love.graphics.getDimensions()
  local framebufferScale = math.min(screenWidth / canvasWidth, screenHeight / canvasHeight)
  local x, y = playbit.graphics.getCanvasPosition()
  x = math.floor((screenWidth - canvasWidth * framebufferScale) / 2) + x * framebufferScale
  y = math.floor((screenHeight - canvasHeight * framebufferScale) / 2) + y * framebufferScale
  local presenter = playbit.graphics.getPresenter() or present
  presenter(playbit.graphics.canvas, x, y, framebufferScale, playbit.graphics.colorWhite, playbit.graphics.colorBlack)

!if DEBUG then
  -- debug draw
  if playdate.debugDraw then
    -- PD sets white color when in the debug mode.
    playdate.graphics.setColor(1)

    love.graphics.setCanvas(playbit.graphics.canvas)
    love.graphics.clear(0, 0, 0, 1)

    -- push main transform for draw offset
    love.graphics.push()
    love.graphics.translate(playbit.graphics.drawOffset.x, playbit.graphics.drawOffset.y)

    playdate.debugDraw()

    -- pop main transform for draw offset
    love.graphics.pop()

    -- pop canvas
    love.graphics.setCanvas()

    -- white pixels are drawn in the debugDrawColor, black pixels are transparent
    -- always with the default presenter
    present(playbit.graphics.canvas, x, y, framebufferScale, playbit.graphics.debugDrawColor, transparentColor)
  end
!end

  -- reset back the shader
  love.graphics.setShader(shader)

  -- update emulated input
  playdate._updateInput()
end

!end