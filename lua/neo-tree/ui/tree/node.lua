local log = require("neo-tree.log")

---@class neotree.ui.TreeNode.Children
---@field more integer|boolean?
---@field [integer] neotree.ui.TreeNode

---@class neotree.ui.TreeNode
---@field id integer
---@field depth integer
---@field buf integer?
---@field source neotree.ui.TreeNode.SourceOpts?
---@field children neotree.ui.TreeNode.Children?
---@field source_id any
---@field private _text string
local TreeNode = {}

local tracking_ns = vim.api.nvim_create_namespace("neo-tree.ui.tree.tracking")
local started = false

---@type table<integer, table<integer, neotree.ui.TreeNode>>
local extmark_to_treenode = setmetatable({}, {
  __index = function(t, k)
    rawset(t, k, {})
    return t[k]
  end,
})
local next_id = 0

---@class neotree.ui.TreeNode.SourceOpts
---@field on_redraw fun(node: neotree.ui.TreeNode)
---@field get_children fun(self: neotree.ui.TreeNode.SourceOpts, source_id: any):neotree.ui.TreeNode.Children[]?

---@param source_id any
---@param source neotree.ui.TreeNode.SourceOpts?
---@param children neotree.ui.TreeNode.Children?
---@return neotree.ui.TreeNode
function TreeNode:new(source_id, source, children)
  local o = {}
  setmetatable(o, self)
  ---@cast o neotree.ui.TreeNode
  self.__index = self

  o.id = next_id
  next_id = next_id + 1

  o.children = children
  o._text = tostring(source_id) or ("<base id: %s>"):format(o.id)
  if source then
    o.source = source
    o.source_id = assert(source_id)
  end
  o.depth = 0
  return o
end

function TreeNode:toggle()
  if self.expanded then
    self:collapse()
  else
    self:expand()
  end
end

function TreeNode:expand()
  vim.print("expand", self)
  if not self.children or (#self.children == 0 and not self.children.more) then
    return
  end

  if self.expanded then
    return
  end

  self.expanded = true
  if not self.tracking_extmark_id then
    return
  end

  local parent_row = self:_get_extmark_pos_and_details()
  local descendants = self:_get_descendants()
  if not descendants then
    return
  end

  local children_start_row = parent_row + 1
  local lines = {}
  for i, d in ipairs(descendants) do
    lines[i] = d:get_text(true)
  end
  vim.api.nvim_buf_set_lines(self.buf, children_start_row, children_start_row, false, lines)

  -- Set extmark trackers
  for i, d in ipairs(descendants) do
    d:_set_tracking_extmark_and_buf(self.buf, parent_row + i)
  end
end

function TreeNode:collapse()
  if not self.children then
    return
  end
  if not self.expanded then
    return
  end

  self.expanded = false

  if not self.tracking_extmark_id then
    return
  end
  local row = self:_get_extmark_pos_and_details()
  local linecount = self:_get_children_linecount()
  if linecount == 0 then
    return
  end

  vim.api.nvim_buf_clear_namespace(self.buf, tracking_ns, row + 1, row + 1 + linecount)
  vim.api.nvim_buf_set_lines(self.buf, row + 1, row + 1 + linecount, false, {})
end

---@private
---Returns descendants that are visible in order of how to draw them.
---@param visible_descendants neotree.ui.TreeNode[]?
---@return neotree.ui.TreeNode[]? visible_descendants Nil if node cannot have children.
function TreeNode:_get_descendants(visible_descendants)
  vim.print("get descendants", self)
  if self.source and self.source.get_children then
    self.children = self.source:get_children(self.source_id)
  end

  if not self.children then
    return nil
  end

  local child_depth = self.depth + 1
  visible_descendants = visible_descendants or {}
  for _, child in ipairs(self.children) do
    child.depth = child_depth
    visible_descendants[#visible_descendants + 1] = child
    if child.children and child.expanded then
      child:_get_descendants(visible_descendants)
    end
  end
  return visible_descendants
end

---@private
---@return integer linecount
function TreeNode:_get_children_linecount()
  local linecount = #self.children
  for _, child in ipairs(self.children) do
    if child.children and child.expanded then
      -- add the lines from the child
      linecount = linecount + child:_get_children_linecount()
    end
  end
  return linecount
end

---@param buf integer 0 for current buffer
---@param start_row integer 0-indexed
function TreeNode:draw_at(buf, start_row)
  buf = buf ~= 0 and buf or vim.api.nvim_get_current_buf()
  assert(not self.buf)

  vim.api.nvim_buf_set_lines(buf, start_row, start_row, true, { self:get_text(true) })
  self:_set_tracking_extmark_and_buf(buf, start_row)
end

---@private
---@param buf integer
---@param start_row integer
function TreeNode:_set_tracking_extmark_and_buf(buf, start_row)
  if self.tracking_extmark_id then
    if self:_get_extmark_pos_and_details() then
      error("previous tracking extmark should be deleted by now")
    end
  end
  self.buf = buf
  local tracking_extmark_id = vim.api.nvim_buf_set_extmark(buf, tracking_ns, start_row, 0, {})
  extmark_to_treenode[buf][tracking_extmark_id] = self
  self.tracking_extmark_id = tracking_extmark_id
  return tracking_extmark_id
end

---@return integer row
---@return integer col
---@return vim.api.keyset.extmark_details? details
function TreeNode:_get_extmark_pos_and_details()
  local tuple = vim.api.nvim_buf_get_extmark_by_id(
    self.buf,
    tracking_ns,
    assert(self.tracking_extmark_id),
    { details = false, hl_name = true }
  )
  return tuple[1], tuple[2], tuple[3]
end

---@param with_depth boolean?
function TreeNode:get_text(with_depth)
  if with_depth then
    return string.rep(" ", self.depth * 2) .. self._text
  else
    return self._text
  end
end

---@param new_text string
function TreeNode:set_text(new_text)
  self._text = new_text
  local extmark_id = self.tracking_extmark_id
  if not extmark_id then
    return
  end

  -- Apply minimal diff
  local extmark_details = vim.api.nvim_buf_get_extmark_by_id(self.buf, tracking_ns, extmark_id, {})
  local start_row = extmark_details[1]

  if not self.buf then
    return
  end
  local dmp = require("neo-tree.utils.diff-match-patch")
  local curline = vim.api.nvim_buf_get_lines(self.buf, start_row, start_row + 1, true)
  local diffs = dmp.diff_main(curline[1], new_text)

  local cursor = 0
  for _, diff in ipairs(diffs) do
    local len_of_diff = #diff[2]
    if diff[1] == dmp.DIFF_DELETE then
      vim.api.nvim_buf_set_text(self.buf, start_row, cursor, start_row, cursor + len_of_diff, {})
    elseif diff[1] == dmp.DIFF_INSERT then
      vim.api.nvim_buf_set_text(self.buf, start_row, cursor, start_row, cursor, { diff[2] })
      cursor = cursor + len_of_diff
    else
      cursor = cursor + len_of_diff
    end
  end
end

---@param line integer? Defaults to cursor line.
---@param buf integer? Defaults to current buffer.
---@return neotree.ui.TreeNode? node
function TreeNode.find_at_line(line, buf)
  buf = buf ~= 0 and buf or vim.api.nvim_get_current_buf()
  line = line or (vim.api.nvim_win_get_cursor(0)[1] - 1)

  local extmarks_found = vim.api.nvim_buf_get_extmarks(
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
  ---@type neotree.ui.TreeNode
  local least_diff_node = nil
  local orig_len = #text_at_line
  for _, extmark in ipairs(extmarks_found) do
    local id = extmark[1]
    local node = assert(extmark_to_treenode[buf][id])
    local str = node._text
    local diff = math.abs(orig_len - #str)
    if diff < mindiff then
      least_diff_node = node
      mindiff = diff
    end
  end

  return least_diff_node
end

local decoration_ns_id = vim.api.nvim_create_namespace("neo-tree.ui.tree.decoration")
vim.api.nvim_set_decoration_provider(decoration_ns_id, {
  on_start = function(_, tick)
    if not started then
      return false
    end
  end,
  on_buf = function(_, bufnr, tick) end,
  on_win = function(_, winid, bufnr, top_row, bot_row)
    local has_new_neo_tree_ui = vim.b[bufnr].new_neo_tree_ui and true or false
    if not has_new_neo_tree_ui then
      return false
    end
    local treenode_extmarks = vim.api.nvim_buf_get_extmarks(
      bufnr,
      tracking_ns,
      { top_row, 1 },
      { bot_row, -1 },
      {
        details = false,
      }
    )
    if #treenode_extmarks == 0 then
      return false
    end
  end,
  on_line = function(_, winid, bufnr, row)
    local node = TreeNode.find_at_line(row, bufnr)
    if not node then
      return
    end
    vim.api.nvim_buf_set_extmark(bufnr, decoration_ns_id, row, 0, {
      virt_text = {
        {
          "ephemeral for " .. node:get_text(),
          "ErrorMsg",
        },
      },
      ephemeral = true,
    })
  end,
  -- on_range = function(_, winid, bufnr, begin_row, begin_col, end_row, end_col) end,
})

return TreeNode
