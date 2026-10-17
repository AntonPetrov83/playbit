local module = {}
playdate = module

require("playbit.geometry")
require("playdate.metadata")
require("playdate.sound")
require("playdate.file")
require("playdate.datastore")
require("playdate.accelerometer")
require("playdate.json")
require("playdate.geometry")

-- ████████╗██╗███╗   ███╗███████╗
-- ╚══██╔══╝██║████╗ ████║██╔════╝
--    ██║   ██║██╔████╔██║█████╗  
--    ██║   ██║██║╚██╔╝██║██╔══╝  
--    ██║   ██║██║ ╚═╝ ██║███████╗
--    ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝
                               
function module.getTime()
  local seconds = os.time()
  local date = os.date("*t", seconds)
  return {
    year = date.year,
    month = date.month,
    day = date.day,
    weekday = date.wday,
    hour = date.hour,
    minute = date.min,
    second = date.sec,
    -- TODO: PD also returns milliseconds to the next second, but time functions in native lua don't have millisecond precision
    millisecond = 0,
  }
end

function module.getCurrentTimeMilliseconds()
  return love.timer.getTime() * 1000
end

function module.getSecondsSinceEpoch()
  -- os.time() without params always returns in system local time, so we must convert to UTC
  local nowLocal = os.time()
  local nowTable = os.date("!*t", nowLocal)
  local nowUtc = os.time(nowTable)
  -- Playdate epoch, as described: https://sdk.play.date/2.6.0/Inside%20Playdate.html#f-getSecondsSinceEpoch
  local playdateEpochUtc = os.time({
    year = 2000,
    month = 1,
    day = 1,
    hour = 0,
    min = 0,
    sec = 0,
  })
  -- TODO: PD also returns milliseconds to the next second, but time functions in native lua don't have millisecond precision
  local milliseconds = 0
  return os.difftime(nowUtc, playdateEpochUtc), milliseconds
end

-- ██╗███╗   ██╗██████╗ ██╗   ██╗████████╗
-- ██║████╗  ██║██╔══██╗██║   ██║╚══██╔══╝
-- ██║██╔██╗ ██║██████╔╝██║   ██║   ██║   
-- ██║██║╚██╗██║██╔═══╝ ██║   ██║   ██║   
-- ██║██║ ╚████║██║     ╚██████╔╝   ██║   
-- ╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝    ╚═╝   
  
local lastActiveJoystick = nil
local isCrankDocked = false
local crankPos = 0
local lastCrankPos = 0

-- by default each button reads a virtual "pd_" input which is pressed by any of its bindings below,
-- playbit.input.setKeyMap() can still map a button to a single keyboard or gamepad input instead
module._buttonToKey = {
  up = "pd_up",
  down = "pd_down",
  left = "pd_left",
  right = "pd_right",
  a = "pd_a",
  b = "pd_b",
}

-- keyboard ("kb_") and gamepad ("js_") inputs work at the same time,
-- gamepad A and B follow the playdate layout: B is the lower left button and A the upper right one
module._buttonBindings = {
  up = { "kb_up", "js_dpup", "js_leftstickup" },
  down = { "kb_down", "js_dpdown", "js_leftstickdown" },
  left = { "kb_left", "js_dpleft", "js_leftstickleft" },
  right = { "kb_right", "js_dpright", "js_leftstickright" },
  a = { "kb_s", "js_b" },
  b = { "kb_a", "js_a" },
}

module.kButtonA = "a"
module.kButtonB = "b"
module.kButtonUp = "up"
module.kButtonDown = "down"
module.kButtonLeft = "left"
module.kButtonRight = "right"

local NONE = 0
local JUST_PRESSED = 1
local PRESSED = 2
local JUST_RELEASED = 3

local inputStates = {}

-- physical keyboard and gamepad inputs which are currently held
local physicalInputsDown = {}

local function updateVirtualButton(button)
  local held = false
  for _, input in ipairs(module._buttonBindings[button]) do
    if physicalInputsDown[input] then
      held = true
      break
    end
  end

  local key = "pd_"..button
  local wasHeld = inputStates[key] == JUST_PRESSED or inputStates[key] == PRESSED
  if held and not wasHeld then
    inputStates[key] = JUST_PRESSED
  elseif not held and wasHeld then
    inputStates[key] = JUST_RELEASED
  end
end

local function setPhysicalInput(input, down)
  if (physicalInputsDown[input] == true) == down then
    return
  end
  physicalInputsDown[input] = down or nil

  -- also kept per physical input for buttons mapped directly with playbit.input.setKeyMap()
  inputStates[input] = down and JUST_PRESSED or JUST_RELEASED

  for button, inputs in pairs(module._buttonBindings) do
    for _, bound in ipairs(inputs) do
      if bound == input then
        updateVirtualButton(button)
      end
    end
  end
end

function module.buttonIsPressed(button)
  local key = module._buttonToKey[button]
  if not inputStates[key] then
    -- no entry, assume no input
    return false
  end

  return inputStates[key] == JUST_PRESSED or inputStates[key] == PRESSED
end

function module.buttonJustPressed(button)
  local key = module._buttonToKey[button]
  if not inputStates[key] then
    -- no entry, assume no input
    return false
  end

  return inputStates[key] == JUST_PRESSED
end

function module.buttonJustReleased(button)
  local key = module._buttonToKey[button]
  if not inputStates[key] then
    -- no entry, assume no input
    return false
  end

  return inputStates[key] == JUST_RELEASED
end

function module.getButtonState(button)
  local key = module._buttonToKey[button]
  local value = inputStates[key]
  return value == PRESSED, value == PRESSED, value == JUST_RELEASED
end

-- docked and undocked with the middle mouse button or by clicking the right stick of a gamepad
function module.isCrankDocked()
  return isCrankDocked
end

function module.getCrankChange()
    local change = playbit.geometry.angleDiff(lastCrankPos, crankPos)
    -- TODO: how does the playdate accelerate this?
    local acceleratedChange = change 
    return change, acceleratedChange
end

-- TODO: emulate via leftstick, keyboard...?
-- accelerometer defined in accelerometer.lua

function module.getCrankPosition()
  if module.isCrankDocked() then
    return 0
  end

  return crankPos
end

function love.joystickadded(joystick)
  -- always take most recently added joystick as active joystick
  lastActiveJoystick = joystick
end

function love.joystickremoved(joystick)
  if lastActiveJoystick == nil then
    return
  end

  if joystick:getID() == lastActiveJoystick:getID() then
    lastActiveJoystick = nil
  end
end

local function toggleCrankDocked()
  isCrankDocked = not isCrankDocked
  crankPos = 0
  --[[ also reset lastCrankPos since on PD, you cant
  dock the crank without rotating it back to 0 --]]
  lastCrankPos = 0
end

function love.gamepadpressed(joystick, gamepadButton)
  lastActiveJoystick = joystick
  setPhysicalInput("js_"..gamepadButton, true)

  if gamepadButton == "rightstick" then
    toggleCrankDocked()
  end
end

function love.gamepadreleased(joystick, gamepadButton)
  lastActiveJoystick = joystick
  setPhysicalInput("js_"..gamepadButton, false)
end

local STICK_PRESS = 0.5
local STICK_RELEASE = 0.3
local CRANK_STICK_DEADZONE = 0.5
local crankStickActive = false

-- a stick direction is pressed past STICK_PRESS and released below STICK_RELEASE to avoid flickering
local function setStickDirections(negativeInput, positiveInput, value)
  local negativeThreshold = physicalInputsDown[negativeInput] and STICK_RELEASE or STICK_PRESS
  local positiveThreshold = physicalInputsDown[positiveInput] and STICK_RELEASE or STICK_PRESS
  setPhysicalInput(negativeInput, value < -negativeThreshold)
  setPhysicalInput(positiveInput, value > positiveThreshold)
end

-- the right stick points the crank, like on playdate 0 is up and the angle grows clockwise
local function updateCrankFromStick(joystick)
  local x = joystick:getGamepadAxis("rightx")
  local y = joystick:getGamepadAxis("righty")
  if x * x + y * y < CRANK_STICK_DEADZONE * CRANK_STICK_DEADZONE then
    crankStickActive = false
    return
  end

  local degrees = math.deg(math.atan2(x, -y))
  if degrees < 0 then
    degrees = degrees + 360
  end

  crankPos = degrees
  if not crankStickActive then
    -- grabbing the stick at some angle should not turn the crank
    lastCrankPos = degrees
    crankStickActive = true
  end
end

function love.gamepadaxis(joystick, axis, value)
  lastActiveJoystick = joystick

  if axis == "leftx" then
    setStickDirections("js_leftstickleft", "js_leftstickright", value)
  elseif axis == "lefty" then
    setStickDirections("js_leftstickup", "js_leftstickdown", value)
  elseif (axis == "rightx" or axis == "righty") and not isCrankDocked then
    updateCrankFromStick(joystick)
  end
end

function love.mousepressed(x, y, button, istouch, presses)
  if button ~= 3 then
    return
  end

  toggleCrankDocked()
end

function love.wheelmoved(x, y)
  if isCrankDocked then
    return
  end

  -- TODO: emulate PD crank acceleration?
  -- TODO: configure scroll sensitivity?
  crankPos = crankPos + -y * 6
  
  if crankPos < 0 then
    crankPos = 359
  elseif crankPos > 359 then
    crankPos = 0
  end
end

-- emulate the keys that PD simulator supports
-- https://sdk.play.date/Inside%20Playdate.html#c-keyPressed
local supportedCallbackKeys = {
  ["1"] = true,
  ["2"] = true,
  ["3"] = true,
  ["4"] = true,
  ["5"] = true,
  ["6"] = true,
  ["7"] = true,
  ["8"] = true,
  ["9"] = true,
  ["0"] = true,
  ["q"] = true,
  ["w"] = true,
  ["e"] = true,
  ["r"] = true,
  ["t"] = true,
  ["y"] = true,
  ["u"] = true,
  ["i"] = true,
  ["o"] = true,
  ["p"] = true,
  ["a"] = true,
  ["s"] = true,
  ["d"] = true,
  ["f"] = true,
  ["g"] = true,
  ["h"] = true,
  ["j"] = true,
  ["k"] = true,
  ["l"] = true,
  ["z"] = true,
  ["x"] = true,
  ["c"] = true,
  ["v"] = true,
  ["b"] = true,
  ["n"] = true,
  ["m"] = true,
  [";"] = true,
  ["'"] = true,
  [","] = true,
  ["."] = true,
  ["/"] = true,
  ["\\"] = true,
  ["`"] = true,
}

function love.keypressed(key)
  setPhysicalInput("kb_"..key, true)

  --[[ Playdate only has a limited range of supported keys, so Playbit exposes the separate
  `playbit.keyPressed` handler so that it can be used to listen to any keypress under love2d. ]]--
  if playbit.keyPressed then
    playbit.keyPressed(key)
  end
  if supportedCallbackKeys[key] then
    if playdate.keyPressed then
      playdate.keyPressed(key)
    end
  end
end

function love.keyreleased(key)  
  setPhysicalInput("kb_"..key, false)

  if playbit.keyReleased then
    playbit.keyReleased(key)
  end

  if supportedCallbackKeys[key] then
    if playdate.keyReleased then
      playdate.keyReleased(key)
    end
  end
end

function module.updateInput()
  -- only update keys that are mapped
  for k,v in pairs(module._buttonToKey) do
    if inputStates[v] == JUST_PRESSED then
      inputStates[v] = PRESSED
    elseif inputStates[v] == JUST_RELEASED then
      inputStates[v] = NONE
    end
  end
  lastCrankPos = crankPos
end

-- ██╗     ██╗   ██╗ █████╗ 
-- ██║     ██║   ██║██╔══██╗
-- ██║     ██║   ██║███████║
-- ██║     ██║   ██║██╔══██║
-- ███████╗╚██████╔╝██║  ██║
-- ╚══════╝ ╚═════╝ ╚═╝  ╚═╝
                         
function table.indexOfElement(table, element)
  for i = 1, #table do
    if table[i] == element then
      return i
    end
  end
  return nil
end

function printTable(...)
	error("[ERR] printTable() is not yet implemented.")
end

-- debug TODO: make a fancy header
function sample()
  error("[ERR] sample() is not yet implemented.")
end

function where()
  error("[ERR] where() is not yet implemented.")
end

function module.apiVersion()
  -- TODO: return Playbit version instead?
  error("[ERR] playdate.apiVersion() is not yet implemented.")
end