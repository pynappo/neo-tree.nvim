local TreeNode, tracking_ns_id = require("neo-tree.ui.tree.node")
local utils = require("neo-tree.utils")
local devicons = require("nvim-web-devicons")

local uv = vim.uv or vim.loop

---@type table<string, uv.fs_stat.result>
local stats = {}
---@param path string
local lstat = function(path)
  local stat, err, code = uv.fs_lstat(path)
  stats[path] = stat
  return stat, err, code
end

local icon_extmarks = {}
local expandable_extmarks = {}
local expanded_virt_text = { { ">", "Comment" }, { " " } }
local closed_virt_text = { { "v", "Comment" }, { " " } }
---@type neotree.ui.TreeNode.SourceOpts
local fs_source = {
  on_redraw_win = function(winid, bufnr, top_row, bot_row, node, extmark_info)
    local path = node.source_id
    local stat = stats[path]
    -- local text = node:get_text()
    local spaces = node.depth * 2
    if spaces >= 2 and node.children then
      expandable_extmarks[path] = vim.api.nvim_buf_set_extmark(
        bufnr,
        TreeNode.namespaces.decoration_on_win,
        extmark_info[2],
        spaces - 2,
        {
          id = expandable_extmarks[path],
          virt_text = node.expanded and expanded_virt_text or closed_virt_text,
          virt_text_pos = "overlay",
        }
      )
    end

    local parent, name = utils.split_path(path)
    if name then
      local icon, hl = devicons.get_icon(name)
      if icon then
        icon_extmarks[path] = vim.api.nvim_buf_set_extmark(
          bufnr,
          TreeNode.namespaces.decoration_on_win,
          extmark_info[2],
          spaces,
          {
            id = icon_extmarks[path],
            virt_text = { { icon, hl }, { " ", "Normal" } },
            virt_text_pos = "inline",
          }
        )
      end
    end
  end,
  on_redraw_line = function(winid, bufnr, row, node)
    local path = node.source_id
    local stat = stats[path]
    local text = node:get_text()
    local spaces = node.depth * 2

    if stat and stat.type == "directory" then
      vim.api.nvim_buf_set_extmark(bufnr, TreeNode.namespaces.decoration_ephemeral, row, spaces, {
        end_row = row,
        end_col = spaces + #text,
        hl_group = "Directory",
        ephemeral = true,
      })
    end
  end,
  get_children = function(self, path)
    local stat = assert(lstat(path))
    if stat.type ~= "directory" then
      return nil
    end
    ---@type neotree.ui.TreeNode.Children
    local nodes = {}
    local iter = vim.fs.dir(path)
    for name, type in iter do
      local fullpath = utils.path_join(path, name)
      local stat = assert(lstat(fullpath))
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
    return nodes
  end,
}

---@param path string
---@return neotree.ui.TreeNode
local function create_file_treenode(path)
  local stat = assert(lstat(path))
  return TreeNode:new(
    uv.cwd(),
    fs_source,
    stat.type == "directory" and { more = vim.fs.dir(path)() and true or false } or nil
  )
end

local id = 0
---@return integer buffer
---@return neotree.ui.TreeNode root
local setup_split_buffer = function()
  local buf = vim.api.nvim_create_buf(true, true)
  id = id + 1
  vim.api.nvim_buf_set_name(buf, ("New neo-tree %s"):format(id))
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
      if #vim.trim(new_text) == 0 then
        return
      end

      node:set_text(new_text)
    end)
  end, { buffer = buf })

  return buf, root
end

vim.api.nvim_create_user_command("NeotreeNew", function()
  setup_split_buffer()
end, {})
