local module = {}
playdate.geometry.affineTransform = module

local meta = {}

meta.__index = meta

meta.__mul = function(a, b)
  error("[ERR] playdate.geometry.affineTransform.__mul is not yet implemented.")
end

module.__index = meta

function module.new(m11, m12, m21, m22, tx, ty)
  local o = {}

  if m11 then
    o.m11 = m11
    o.m12 = m12
    o.m21 = m21
    o.m22 = m22
    o.tx  = tx
    o.ty  = ty
  else
    o.m11 = 1
    o.m12 = 0
    o.m21 = 0
    o.m22 = 1
    o.tx  = 0
    o.ty  = 0
  end

  setmetatable(o, meta)
  return o
end

function meta:copy()
  return module.new(self.m11, self.m12, self.m21, self.m22, self.tx, self.ty)
end

function meta:unpack()
  return self.m11, self.m12, self.m21, self.m22, self.tx, self.ty
end

function meta:invert()
  error("[ERR] playdate.geometry.affineTransform:invert() is not yet implemented.")
end

function meta:reset()
  self.m11 = 1
  self.m12 = 0
  self.m21 = 0
  self.m22 = 1
  self.tx  = 0
  self.ty  = 0
end

function meta:concat(af)
  local m11 = self.m11 * af.m11 + self.m12 * af.m21
  local m12 = self.m11 * af.m12 + self.m12 * af.m22

  local m21 = self.m21 * af.m11 + self.m22 * af.m21
  local m22 = self.m21 * af.m12 + self.m22 * af.m22

  local tx  = self.m11 * af.tx  + self.m12 * af.ty + self.tx
  local ty  = self.m21 * af.tx  + self.m22 * af.ty + self.ty

  return module.new(m11, m12, m21, m22, tx, ty)
end

function meta:translate(dx, dy)
  error("[ERR] playdate.geometry.affineTransform:translate() is not yet implemented.")
end

function meta:translatedBy(dx, dy)
  error("[ERR] playdate.geometry.affineTransform:translatedBy() is not yet implemented.")
end

function meta:scale(sx, sy)
  error("[ERR] playdate.geometry.affineTransform:scale() is not yet implemented.")
end

function meta:scaledBy(sx, sy)
  error("[ERR] playdate.geometry.affineTransform:scaledBy() is not yet implemented.")
end

function meta:rotate(angle, pointOrX, y)
  error("[ERR] playdate.geometry.affineTransform:rotate() is not yet implemented.")
end

function meta:rotateBy(angle, pointOrX, y)
  error("[ERR] playdate.geometry.affineTransform:rotateBy() is not yet implemented.")
end

function meta:skew(sx, sy)
  error("[ERR] playdate.geometry.affineTransform:skew() is not yet implemented.")
end

function meta:skewedBy(sx, sy)
  error("[ERR] playdate.geometry.affineTransform:skewedBy() is not yet implemented.")
end

function meta:transformPoint(p)
  local nx, ny = self:transformXY(p.x, p.y)
  p.x = nx
  p.y = ny
end

function meta:transformedPoint(p)
  local nx, ny = self:transformXY(p.x, p.y)
  return playdate.geometry.point.new(nx, ny)
end

function meta:transformXY(x, y)
  local nx = x * self.m11 + y * self.m12 + self.tx
  local ny = x * self.m21 + y * self.m22 + self.ty
  return nx, ny
end

function meta:transformLineSegment(ls)
  error("[ERR] playdate.geometry.affineTransform:transformLineSegment() is not yet implemented.")
end

function meta:transformedLineSegment(ls)
  error("[ERR] playdate.geometry.affineTransform:transformedLineSegment() is not yet implemented.")
end

function meta:transformAABB(r)
  error("[ERR] playdate.geometry.affineTransform:transformAABB() is not yet implemented.")
end

function meta:transformedAABB(r)
  error("[ERR] playdate.geometry.affineTransform:transformedAABB() is not yet implemented.")
end

function meta:transformPolygon(p)
  error("[ERR] playdate.geometry.affineTransform:transformPolygon() is not yet implemented.")
end

function meta:transformedPolygon(p)
  error("[ERR] playdate.geometry.affineTransform:transformedPolygon() is not yet implemented.")
end
