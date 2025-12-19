local log = require("neo-tree.log")
local api = vim.api

---@class neotree.ui.TreeNode
---@field [integer] neotree.ui.TreeNode?
local TreeNode = {}
local tracking_ns = api.nvim_create_namespace("neo-tree.ui.tree.tracking")
local main_ns = api.nvim_create_namespace("neo-tree.ui.tree")
local trackers_by_buffer = api.nvim_create_namespace("neo-tree.ui.tree")

local next_id = 0

---@param id string|integer
---@return neotree.ui.TreeNode
function TreeNode:new(id)
  local o = {}
  setmetatable(o, {
    __index = self,
    __tostring = function()
      return self.str(o)
    end,
  })
  self.id = id or next_id
  self.text = tostring(self.id)
  next_id = next_id + 1

  self.extmarks = {}
  self.open = {}
  return o
end

---@param self neotree.ui.TreeNode
---@return string str
function TreeNode.str(self)
  return self.text
end

---@param buf integer
function TreeNode:render(buf, start_line) end

---@param start_row integer 0-indexed
---@param buf integer? Defaults to 0
---@param end_row integer? 0-indexed
function TreeNode:draw_at(start_row, buf, end_row)
  end_row = end_row or start_row
  buf = buf or 0
  local str = self:str()
  api.nvim_buf_set_lines(buf, start_row, end_row, true, { str })
  local main_extmark = api.nvim_buf_set_extmark(buf, tracking_ns, start_row, 0, {
    invalidate = true, -- make it obvious
  })
  local extmarks_for_buf = self.extmarks[buf] or {}
  extmarks_for_buf[#extmarks_for_buf + 1] = main_extmark
  self.extmarks[buf] = extmarks_for_buf
end

---@param buf integer
---@param new_text string
function TreeNode:update_text(buf, new_text)
  for _, extmark_id in ipairs(self.extmarks[buf] or {}) do
    local extmark_details = vim.api.nvim_buf_get_extmark_by_id(buf, tracking_ns, extmark_id, {})
    local start_row = extmark_details[1]
    if extmark_details[3].invalid then
      vim.api.nvim_buf_del_extmark(buf, tracking_ns, extmark_id)
      return
    end

    local dmp = require("neo-tree.utils.diff-match-patch")
    local curline = api.nvim_buf_get_lines(buf, start_row, start_row + 1, true)
    local diffs = dmp.diff_main(curline[1], new_text)

    local cursor = 0
    for _, diff in ipairs(diffs) do
      local len_of_diff = #diff[2]
      if diff[1] == dmp.DIFF_DELETE then
        api.nvim_buf_set_text(buf, start_row, cursor, start_row, cursor + len_of_diff, {})
      elseif diff[1] == dmp.DIFF_INSERT then
        api.nvim_buf_set_text(buf, start_row, cursor, start_row, cursor, { diff[2] })
        cursor = cursor + len_of_diff
      else
        cursor = cursor + len_of_diff
      end
    end
  end
end

---@type vim.api.keyset.get_extmarks
local yes_details = { details = true }
---@return neotree.ui.TreeNode? node
function TreeNode.find_at_cursor()
  local curbuf = vim.api.nvim_get_current_buf()
  local curpos = api.nvim_win_get_cursor(curbuf)
  curpos[1] = curpos[1] - 1
  local extmarks_found =
    api.nvim_buf_get_extmarks(curbuf, tracking_ns, curpos, { curpos[1], -1 }, yes_details)
  local text_at_line = vim.api.nvim_buf_get_lines(curbuf, curpos[1], curpos[1] + 1, true)
  vim.print({
    extmarks_found = extmarks_found,
    text_at_line = text_at_line,
  })
  for _, extmark in ipairs(extmarks_found) do
    if not extmark[4].invalid then
    end
  end
end

local example_node = TreeNode:new("example")
vim.api.nvim_create_user_command("NodeHere", function()
  local curpos = vim.api.nvim_win_get_cursor(0)
  example_node:draw_at(curpos[1])
end, {})

return TreeNode
