local tests = {}

-- gamepad input only exists on love2d
!if LOVE2D then
local updateInput = playdate._updateInput or playdate.updateInput

-- fake joystick for the stick axes
local function newJoystick(axes)
  return {
    getGamepadAxis = function(self, axis)
      return axes[axis] or 0
    end
  }
end

local function settleInput()
  updateInput()
  updateInput()
end

function tests.GamepadButton_PressesPlaydateButton()
  love.gamepadpressed(nil, "b")
  local pressed = playdate.buttonIsPressed(playdate.kButtonA)
  love.gamepadreleased(nil, "b")
  settleInput()

  pbAssert.IsTrue(pressed)
end

function tests.KeyboardAndGamepad_ButtonIsReleasedWhenBothAreReleased()
  love.keypressed("s")
  love.gamepadpressed(nil, "b")
  updateInput()
  love.keyreleased("s")
  local pressedAfterKeyRelease = playdate.buttonIsPressed(playdate.kButtonA)
  love.gamepadreleased(nil, "b")
  local releasedAfterBoth = playdate.buttonJustReleased(playdate.kButtonA)
  settleInput()

  pbAssert.IsTrue(pressedAfterKeyRelease)
  pbAssert.IsTrue(releasedAfterBoth)
end

function tests.LeftStick_PressesDirection()
  local joystick = newJoystick({})
  love.gamepadaxis(joystick, "leftx", -1)
  local pressed = playdate.buttonJustPressed(playdate.kButtonLeft)
  love.gamepadaxis(joystick, "leftx", 0)
  local released = playdate.buttonJustReleased(playdate.kButtonLeft)
  settleInput()

  pbAssert.IsTrue(pressed)
  pbAssert.IsTrue(released)
end

function tests.RightStick_PointsCrankClockwiseFromUp()
  local up = newJoystick({ righty = -1 })
  local right = newJoystick({ rightx = 1 })
  love.gamepadaxis(up, "righty", -1)
  local upPosition = playdate.getCrankPosition()
  love.gamepadaxis(right, "rightx", 1)
  local rightPosition = playdate.getCrankPosition()
  love.gamepadaxis(newJoystick({}), "rightx", 0)
  settleInput()

  pbAssert.AreEqual(upPosition, 0)
  pbAssert.AreEqual(rightPosition, 90)
end
!end

return tests
