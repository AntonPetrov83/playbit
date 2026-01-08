function drawText()
  playdate.graphics.clear(1)
  playdate.graphics.drawText("HELLO WORLD", 0, 0)
end

return {
  { "drawText", drawText },
}