local utils = require("neo-tree.utils")

---@alias neotree.sources.common.sorters.FieldProviderNames
---|"created"
---|"modified"
---|"name"
---|"size"
---|"type"
---|"git_status"
---|"diagnostics"

---@type table<neotree.sources.common.sorters.FieldProviderNames, fun(state: neotree.State?):neotree.Internal.SortFieldProvider>
return {
  created = function()
    return function(node)
      local stat = utils.get_stat(node)
      return stat.birthtime and stat.birthtime.sec or 0
    end
  end,
  modified = function()
    return function(node)
      local stat = utils.get_stat(node)
      return stat.mtime and stat.mtime.sec or 0
    end
  end,
  name = function()
    local config = require("neo-tree").config
    if config.sort_case_insensitive then
      return function(node)
        return node.path:lower()
      end
    else
      return function(node)
        return node.path
      end
    end
  end,
  size = function()
    return function(node)
      local stat = utils.get_stat(node)
      return stat.size or 0
    end
  end,
  type = function()
    return function(node)
      return node.ext or node.type
    end
  end,
  git_status = function(state)
    return function(node)
      local git_status_lookup = state.git_status_lookup or {}
      local git_status = git_status_lookup[node.path]
      if git_status then
        return git_status
      end

      if node.filtered_by and node.filtered_by.gitignored then
        return "!!"
      else
        return ""
      end
    end
  end,
  diagnostics = function(state)
    return function(node)
      local diag = state.diagnostics_lookup or {}
      local diagnostics = diag[node.path]
      if not diagnostics then
        return 0
      end
      if not diagnostics.severity_number then
        return 0
      end
      -- lower severity number means higher severity
      return 5 - diagnostics.severity_number
    end
  end,
}
