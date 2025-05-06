local Path = require("neo-tree.lib.path.posix")

describe("neotree.Path", function()
  it("normalizes paths", function()
    local p = Path:new("/test/../..")
    assert.are.same("/", tostring(p))
  end)
end)
