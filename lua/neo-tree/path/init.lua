--- A pathlib-like class suited for neo-tree's purposes.
local utils = require("neo-tree.utils")

---@class neotree.Path : metatable
---@field [integer] string?
---@field string string
---@field dirty boolean
---@field sep string

local Path = {}
local default_sep = utils.path_separator

function Path.__div(a, b) end
function Path.__tostring(self)
  if self.dirty then
    return self.string
  end
  return table.concat(self, default_sep)
end

function Path:new(...)
  local o = { ... }
  setmetatable(o, self)
  self.__index = self
  return o
end

local nvim_v09 = vim.version().minor > 8
---Normalizes the path
---@return string normalized
function Path:normalize()
  if self.string then
    return self.string
  end
end

local fast_list_extend
if table.move then
  ---@param dst any[]
  ---@param src any[]
  ---@param start integer?
  ---@param finish integer?
  fast_list_extend = function(dst, src, start, finish)
    table.move(src, start or 0, finish or #src, #dst, dst)
  end
else
  fast_list_extend = vim.list_extend
end

---@vararg string paths
function Path:join(...)
  fast_list_extend(self, { ... })
end

-- function Path:parent()
--   return string.match(tostring(self))
-- end
-- function Path:parent_path()
--   return string.match(tostring(self))
-- end

return Path
