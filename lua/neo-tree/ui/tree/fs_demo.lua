local TreeNode = require("neo-tree.ui.tree.node")
local utils = require("neo-tree.utils")

local uv = vim.uv or vim.loop

---@type neotree.ui.TreeNode.SourceOpts
local fs_source = {
  on_redraw = function() end,
  get_children = function(self, path)
    local stat = assert(uv.fs_lstat(path))
    if stat.type ~= "directory" then
      return nil
    end
    ---@type neotree.ui.TreeNode.Children
    local nodes = {}
    local iter = vim.fs.dir(path)
    for name, type in iter do
      local fullpath = utils.path_join(path, name)
      local stat = assert(uv.fs_lstat(fullpath))
      local node = TreeNode:new(
        fullpath,
        self,
        stat.type == "directory" and { more = vim.fs.dir(fullpath)() and true or false } or nil
      )
      node:set_text(name)
      nodes[#nodes + 1] = node
    end
    if iter() then
      nodes.more = true
    end
    vim.print(nodes)
    return nodes
  end,
}

---@param path string
---@return neotree.ui.TreeNode
local function create_file_treenode(path)
  local stat = assert(uv.fs_lstat(path))
  return TreeNode:new(
    uv.cwd(),
    fs_source,
    stat.type == "directory" and { more = vim.fs.dir(path)() and true or false } or nil
  )
end

---@return integer buffer
---@return neotree.ui.TreeNode root
local setup_split_buffer = function()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, "New neo-tree")
  local root = create_file_treenode(assert(uv.cwd()))
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
  root:draw_at(buf, 0)

  -- keymaps
  vim.keymap.set("n", "<CR>", function()
    local node = TreeNode.find_at_line()
    if not node then
      vim.print("No node at cursor pos")
      return
    end

    node:toggle()
  end, { buffer = buf })

  vim.keymap.set("n", "r", function()
    local node = TreeNode.find_at_line()
    if not node then
      vim.print("No node at cursor pos")
      return
    end

    vim.ui.input({ prompt = ("Rename node %s to:"):format(node:get_text()) }, function(new_text)
      node:set_text(assert(new_text))
    end)
  end, { buffer = buf })

  return buf, root
end

vim.api.nvim_create_user_command("NeotreeNew", function()
  setup_split_buffer()
end, {})
