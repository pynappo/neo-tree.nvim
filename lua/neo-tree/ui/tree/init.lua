---@class neotree.ui.Tree
local Tree = {}

local tracking_ns = vim.api.nvim_create_namespace("neo-tree.ui.tree.tracking")
local started = false

---@type table<integer, table<integer, neotree.ui.TreeNode>>
local next_id = 0

---A tree is responsible for holding 1 root node, as well as the range of lines that the tree's children visually
---occupy.
function Tree:new()
  local o = {}
  setmetatable(o, self)
  ---@cast o neotree.ui.TreeNode
  self.__index = self
  o.depth = 0
  return o
end
