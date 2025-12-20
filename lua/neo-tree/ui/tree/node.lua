local log = require("neo-tree.log")
local api = vim.api

---@class neotree.ui.TreeNode
---@field [integer] neotree.ui.TreeNode?
local TreeNode = {}
local tracking_ns = api.nvim_create_namespace("neo-tree.ui.tree.tracking")

---@type table<integer, neotree.ui.TreeNode>
local extmark_to_treenode = {}

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

  self.opened = false
  return o
end

function TreeNode:toggle()
  if self.opened then
    TreeNode:close()
  else
    TreeNode:open()
  end
end

function TreeNode:open()
  vim.print("open")
  self.opened = true
end

function TreeNode:close()
  vim.print("close")
  self.opened = false
end

---@param self neotree.ui.TreeNode
---@return string str
function TreeNode.str(self)
  return self.text
end

---@param buf integer
function TreeNode:render(buf, start_line)
  self:draw_at(start_line, buf)
end

---@param start_row integer 0-indexed
---@param buf integer? Defaults to 0
---@param end_row integer? 0-indexed
function TreeNode:draw_at(start_row, buf, end_row)
  buf = buf or vim.api.nvim_get_current_buf()

  local str = self:str()
  api.nvim_buf_set_lines(buf, start_row, start_row, true, { str })

  local tracking_extmark = api.nvim_buf_set_extmark(buf, tracking_ns, start_row, 0, {
    invalidate = true, -- make it obvious
  })
  extmark_to_treenode[tracking_extmark] = self
  self.tracking_extmark = tracking_extmark
end

---@param buf integer
---@param new_text string
function TreeNode:update_text(buf, new_text)
  local extmark_id = self.tracking_extmark
  if not extmark_id then
    return
  end

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

---@param line integer? Defaults to cursor line
---@return neotree.ui.TreeNode? node
function TreeNode.find_at_line(line)
  local curbuf = vim.api.nvim_get_current_buf()
  if not line then
    local curpos = api.nvim_win_get_cursor(0)
    line = curpos[1] - 1
  end

  local extmarks_found = api.nvim_buf_get_extmarks(
    curbuf,
    tracking_ns,
    { line, 0 },
    { line, -1 },
    { details = true }
  )
  local text_at_line = vim.api.nvim_buf_get_lines(curbuf, line, line + 1, true)[1]
  text_at_line = vim.trim(text_at_line)

  local mindiff = math.huge
  local least_diff_node = nil
  local orig_len = #text_at_line
  for _, extmark in ipairs(extmarks_found) do
    if extmark[4].invalid then
      vim.print("invalid", extmark)
    else
      local node = assert(extmark_to_treenode[extmark[1]])
      local str = node:str()
      local diff = math.abs(orig_len - #str)
      if diff < mindiff then
        least_diff_node = node
        mindiff = diff
      end
    end
  end

  return least_diff_node
end

---@return integer buffer
---@return neotree.ui.TreeNode root
local setup_split_buffer = function()
  local buf = vim.api.nvim_create_buf(false, true)
  local root = TreeNode:new("root")
  ---@type vim.api.keyset.cmd
  local args = {
    cmd = "sbuffer",
    args = { tostring(buf) },
    ---@diagnostic disable-next-line: missing-fields
    mods = {
      vertical = true,
    },
  }
  vim.cmd(args)
  root:render(buf, 0)

  -- keymaps
  vim.keymap.set("n", "<CR>", function()
    local node = TreeNode.find_at_line()
    if not node then
      return
    end

    node:toggle()
  end)

  return buf, root
end

setup_split_buffer()

return TreeNode
