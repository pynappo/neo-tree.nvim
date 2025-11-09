local api = vim.api

---@class neotree.ui.TreeNode
---@field [integer] neotree.ui.TreeNode?
local TreeNode = {}
local ns = api.nvim_create_namespace("neo-tree.ui.tree")

local next_id = 0

function TreeNode:new(id)
  local o = {}
  setmetatable(o, {
    __index = self,
    __tostring = self.str,
  })
  self.id = id or next_id
  self.text = tostring(self.id)
  next_id = next_id + 1

  self.extmarks = {}
  return o
end

---@param self neotree.ui.TreeNode
---@return string str
function TreeNode.str(self)
  return tostring(self.text)
end

---@param buf integer
function TreeNode:render(buf, start_line)
  local nodes = {
    self,
    unpack(self),
  }
end
---@param line integer
---@param buf integer?
function TreeNode:draw_at(line, buf, extmark_update)
  buf = buf or 0
  local str = self:str()
  api.nvim_buf_set_lines(buf, line, line, true, { str })
  self.extmark_id = api.nvim_buf_set_extmark(buf, ns, line, 0, {
    end_col = #str,
    hl_group = "WarningMsg",
  })
end

function TreeNode:find_extmark(buf)
  buf = buf or 0
  local current_extmark_details = api.nvim_buf_get_extmark_by_id(buf, ns, self.extmark_id, {
    details = true,
  })
  return next(current_extmark_details) and current_extmark_details or nil
end

function TreeNode:find_line(buf)
  buf = buf or 0
  local extmark_details = self:find_extmark(buf)
  return extmark_details and extmark_details[1]
end

local dmp = require("neo-tree.utils.diff-match-patch")
local empty = {}
---@param buf integer
---@param new_text string
function TreeNode:update_text(buf, new_text)
  local lnum = self:find_line(buf)
  assert(lnum)
  local curline = api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)
  local diffs = dmp.diff_main(curline[1], new_text)
  local cursor = 0
  for _, diff in ipairs(diffs) do
    local len_of_diff = #diff[2]
    if diff[1] == dmp.DIFF_DELETE then
      api.nvim_buf_set_text(buf, lnum - 1, cursor, lnum - 1, cursor + len_of_diff, empty)
    elseif diff[2] == dmp.DIFF_ADD then
      api.nvim_buf_set_text(buf, lnum - 1, cursor, lnum - 1, cursor, { diff[2] })
      cursor = cursor + len_of_diff
    else
      cursor = cursor + len_of_diff
    end
  end
end
return TreeNode
