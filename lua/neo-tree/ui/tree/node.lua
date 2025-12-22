local log = require("neo-tree.log")
local api = vim.api

---@class neotree.ui.TreeNode
---@field [integer] neotree.ui.TreeNode?
local TreeNode = {}
local tracking_ns = api.nvim_create_namespace("neo-tree.ui.tree.tracking")

---@type table<integer, neotree.ui.TreeNode>
local extmark_to_treenode = {}

---@class neotree.ui.tree.SourceOpts
---@field on_redraw fun(node)
---@field false fun(node)

---@param id string|integer
---@param source_opts neotree.ui.tree.SourceOpts?
---@return neotree.ui.TreeNode
function TreeNode:new(id, source_opts)
  local o = {}
  setmetatable(o, {
    __index = self,
    __tostring = function()
      return self.str(o)
    end,
  })
  self.id = id
  self.text = tostring(self.id)
  self.source = source_opts

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
  vim.b[buf].new_neotree_ui = true
  self:draw_at(start_line, buf)
end

---@param start_row integer 0-indexed
---@param buf integer? Defaults to 0
---@param end_row integer? 0-indexed
function TreeNode:draw_at(start_row, buf, end_row)
  buf = buf or vim.api.nvim_get_current_buf()

  local str = self:str()
  api.nvim_buf_set_lines(buf, start_row, start_row, true, { str })

  local tracking_extmark_id = api.nvim_buf_set_extmark(buf, tracking_ns, start_row, 0, {})
  extmark_to_treenode[tracking_extmark_id] = self
  self.tracking_extmark = tracking_extmark_id
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
---@param buf integer? Defaults to cursor line
---@return neotree.ui.TreeNode? node
function TreeNode.find_at_line(line, buf)
  buf = buf ~= 0 and buf or vim.api.nvim_get_current_buf()
  line = line or (api.nvim_win_get_cursor(0)[1] - 1)

  local extmarks_found = api.nvim_buf_get_extmarks(
    buf,
    tracking_ns,
    { line, 0 },
    { line, -1 },
    { details = true }
  )
  local text_at_line = vim.api.nvim_buf_get_lines(buf, line, line + 1, true)[1]
  text_at_line = vim.trim(text_at_line)
  if not text_at_line then
    return nil
  end

  local mindiff = math.huge
  local least_diff_node = nil
  local orig_len = #text_at_line
  for _, extmark in ipairs(extmarks_found) do
    local id = extmark[1]
    local node = extmark_to_treenode[id]
    if node then
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

vim.api.nvim_create_user_command("NeotreeNew", function()
  setup_split_buffer()
end, {})

local decoration_ns_id = api.nvim_create_namespace("neo-tree.ui.tree.decoration")
api.nvim_set_decoration_provider(decoration_ns_id, {
  on_start = function(_, tick) end,
  on_buf = function(_, bufnr, tick) end,
  on_win = function(_, winid, bufnr, top_row, bot_row)
    return vim.b[bufnr].new_neotree_ui and true or false
  end,
  on_line = function(_, winid, bufnr, row)
    local node = TreeNode.find_at_line(row, bufnr)
    if not node then
      vim.print("Could not find node at " .. row)
      return
    end
    api.nvim_buf_set_extmark(bufnr, decoration_ns_id, row, 0, {
      virt_text = {
        {
          "ephemeral for " .. node:str(),
          "ErrorMsg",
        },
      },
      ephemeral = true,
    })
  end,
  -- on_range = function(_, winid, bufnr, begin_row, begin_col, end_row, end_col) end,
})

return TreeNode
