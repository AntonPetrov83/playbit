local build = require("build")

build.build({ 
  assert = true,
  debug = true,
  platform = "playdate",
  output = "_tests_pdx",
  clearBuildFolder = true,
  fileProcessors = {
    lua = build.luaProcessor,
    wav = build.waveProcessor,
    aseprite = build.skipFile,
  },
  files = {
    -- essential playbit files for playdate
    { "playbit", "playbit" },
    -- project
    { "fonts/", "fonts" },
    { "tests/src/main.lua", "main.lua" },
    { "tests/src/suites", "suites/" },
    { "tests/src/metadata.json", "pdxinfo",
      {
        json = { build.pdxinfoProcessor, { incrementBuildNumber = false } }
      }
    }
  },
})