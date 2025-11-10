local api = vim.api

---@class neotree.ui.TreeNode
---@field [integer] neotree.ui.TreeNode?
local TreeNode = {}
local ns = api.nvim_create_namespace("neo-tree.ui.tree")
local log = require("neo-tree.log")

local next_id = 0

local nodes = {}
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

  self.extmarks_for_buf = {}
  nodes[#nodes + 1] = o
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
---@param buf integer?
---@param end_row integer? 0-indexed
function TreeNode:draw_at(start_row, buf, end_row)
  end_row = end_row or start_row
  buf = buf or 0
  local str = self:str()
  api.nvim_buf_set_lines(buf, start_row, end_row, true, { str })
  local extmark_id = api.nvim_buf_set_extmark(buf, ns, start_row, 0, {
    hl_group = "WarningMsg",
    invalidate = true,
    virt_text = { {
      self.id,
      "ErrorMsg",
    } },
    virt_text_pos = "eol_right_align",
  })
  local extmarks_for_buf = self.extmarks_for_buf[buf] or {}
  extmarks_for_buf[#extmarks_for_buf + 1] = extmark_id
  self.extmarks_for_buf[buf] = extmarks_for_buf
end

local dmp = require("neo-tree.utils.diff-match-patch")
local empty = {}

---@param buf integer
---@param new_text string
function TreeNode:update_text(buf, new_text)
  for _, extmark_id in ipairs(self.extmarks_for_buf[buf] or {}) do
    local extmark_details = vim.api.nvim_buf_get_extmark_by_id(buf, ns, extmark_id, {})
    local start_row = extmark_details[1]
    if extmark_details[3].invalid then
      log.error("invalidated")
      vim.api.nvim_buf_del_extmark(buf, ns, extmark_id)
      return
    end

    local curline = api.nvim_buf_get_lines(buf, start_row, start_row + 1, true)
    local diffs = dmp.diff_main(curline[1], new_text)

    local cursor = 0
    for _, diff in ipairs(diffs) do
      local len_of_diff = #diff[2]
      if diff[1] == dmp.DIFF_DELETE then
        api.nvim_buf_set_text(buf, start_row, cursor, start_row, cursor + len_of_diff, empty)
      elseif diff[1] == dmp.DIFF_INSERT then
        api.nvim_buf_set_text(buf, start_row, cursor, start_row, cursor, { diff[2] })
        cursor = cursor + len_of_diff
      else
        cursor = cursor + len_of_diff
      end
    end
  end
end

return TreeNode
