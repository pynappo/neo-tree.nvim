--- A pathlib-like class suited for neo-tree's purposes.
local utils = require("neo-tree.utils")

---@enum neotree.Path.SpecialType
local pathtype = {
  WINDOWS_FILE = 0,
  WINDOWS_UNC = 1,
  LINUX_FILE = 2,
}

---@alias neotree.Pathish neotree.Path|string|string[]

---@class neotree.Path.Cache
---@field string string?

---@class neotree.Path
---@field [integer] string?
---@field root string
---@field private dirty boolean
---@field sep string
---@field private unnormalized (neotree.Pathish)[]
---
---@field private _cache neotree.Path.Cache
local Path = {}

function Path:new(...)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.unnormalized = { ... }
  o._cache = {}
  return o
end

---@return neotree.Path normalized_copy
function Path:copy()
  return Path:new()
end

function Path:__div(b)
  if getmetatable(b) == Path then
    ---@cast b neotree.Path
    return Path:new(unpack(b:normalize()))
  end
  if type(b) == "string" then
    return Path:new(tostring(self), b)
  end
end

function Path.__tostring(self)
  self:normalize()
  if not self._cache.string then
    self._cache.string = self.root .. table.concat(self, utils.path_separator)
  end
  return self._cache.string
end

---@param str string
---@return string? prefix The prefix of the absolute path, if the path is absolute.
---@return neotree.Path.SpecialType? alt If the prefix exists, whether the prefix is for non-regular paths
local extract_prefix = function(str)
  if utils.is_windows then
    local disk_prefix = str:match([=[^%a:[\\/]]=])
    if disk_prefix then
      return disk_prefix, nil
    end
    local unc_prefix = str:match([[\\]])
    if unc_prefix then
      return unc_prefix, pathtype.WINDOWS_UNC
    end
  else
    return str:match("^/"), nil
  end
  return nil, nil
end

---Normalizes the path
---@return self neotree.Path
function Path:normalize()
  if not self.dirty then
    return self
  end

  for _, segment in ipairs(self.unnormalized) do
    if type(segment) == "string" then
      segment = { segment }
    end
    assert(type(segment) == "table")
    if getmetatable(segment) == Path then
      ---@cast segment neotree.Path
      segment:normalize()
      if segment.root then
        self.root = segment.root
      end
    end
    for _, part in ipairs(segment) do
      -- normalize separators

      -- normalize paths
    end
  end

  self.unnormalized = {}
  self.dirty = false

  return self
end

---@param str
---@param relative boolean? Whether the str is known to be relative
function Path:_append_single_segment(str, relative)
  local prefix, parts = extract_prefix(str)
  if prefix then
    self.prefix = str
  end
end

local fast_list_extend
if table.move then
  ---@param dst any[]
  ---@param src any[]
  ---@param start integer?
  ---@param finish integer?
  fast_list_extend = function(dst, src, start, finish)
    table.move(src, start or 1, finish or #src, #dst, dst)
  end
else
  fast_list_extend = vim.list_extend
end

---@vararg string paths
---@return neotree.Path self
function Path:join(...)
  fast_list_extend(self.unnormalized, { ... })
  self.dirty = true
  return self
end

---@return string
function Path:parent()
  return tostring(self):match(self.sep)
end

---@param levels_up integer? How many levels up to go, default 1 level up
---@return Path
function Path:parent_path(levels_up)
  self:normalize()
  return Path:new(fast_list_extend({}, self, 0, #self - (levels_up or 1)))
end

function Path:up(levels) end

return Path
