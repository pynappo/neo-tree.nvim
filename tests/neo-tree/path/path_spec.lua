local Path = require("neo-tree.lib.path.posix")

describe("neotree.Path", function()
  it("normalizes paths", function()
    local p = Path:new("/test/../..")
    local p = Path:new("/test/../..")
  end)
end)
