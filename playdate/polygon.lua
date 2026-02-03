local module = {}
playdate.geometry.polygon = module

local meta = {}

meta.__index = meta

meta.__mul = function(a, b)
  error("[ERR] playdate.geometry.polygon.__mul is not yet implemented.")
end

module.__index = meta

function module.new(x1, y1, x2, y2, ...)
  local o = {}

  -- TODO !!!
  error("[ERR] playdate.geometry.polygon.new() is not yet implemented.")

  self._points = {}
  self._closed = false

  setmetatable(o, meta)
  return o
end

function meta:copy()
  local o = module.new(table.unpack(self._points))
  o._closed = self._closed
  return o
end

function meta:close()
  self._closed = true
end

function meta:isClosed()
  return self._closed
end

function meta:containsPoint(p, fillRule)
  error("[ERR] playdate.geometry.polygon:containsPoint() is not yet implemented.")
end

function meta:containsPoint(x, y, fillRule)
  error("[ERR] playdate.geometry.polygon:containsPoint() is not yet implemented.")
end

-- Returns multiple values (x, y, width, height) giving the axis-aligned bounding box for the polygon.
function meta:getBounds()
  error("[ERR] playdate.geometry.polygon:getBounds() is not yet implemented.")
end

function meta:getBoundsRect()
  error("[ERR] playdate.geometry.polygon:getBoundsRect() is not yet implemented.")
end

-- Returns the number of points in the polygon.
function meta:count()
  return #self._points / 2
end

-- Returns the total length of all line segments in the polygon.
function meta:length()
  error("[ERR] playdate.geometry.polygon:length() is not yet implemented.")
end

function meta:setPointAt(n, x, y)
  self._points[n * 2 + 1] = x
  self._points[n * 2 + 2] = y
end

-- TODO: Check the return type because Playdate docs does not specify it.
function meta:getPointAt(n)
  return self._points[n * 2 + 1], self._points[n * 2 + 2]
end

function meta:intersects(p)
  error("[ERR] playdate.geometry.polygon:intersects() is not yet implemented.")
end

function meta:pointOnPolygon(distance, extend)
  error("[ERR] playdate.geometry.polygon:pointOnPolygon() is not yet implemented.")
end

function meta:translate(dx, dy)
  local points = self._points
  local len = #points
  local i = 1

  while i < len do
    points[i] = points[i] + dx
    i = i + 1
    points[i] = points[i] + dy
    i = i + 1
  end
end
