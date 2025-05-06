--- A pathlib-like class suited for neo-tree's purposes.
local utils = require("neo-tree.utils")

---@enum neotree.Path.Type
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
---@field sep string
---@field type neotree.Path.Type
---@field private dirty boolean
---@field private unnormalized (neotree.Pathish)[]
---
---@field private _cache neotree.Path.Cache
local Path = {}

---The default, fastest constructor for creating a path
---@vararg neotree.Pathish
---@return neotree.Path new_path
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
    return Path:new(b)
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
---@return neotree.Path.Type? alt If the prefix exists, the type of the path given
local extract_prefix = function(str)
  if utils.is_windows then
    local disk_prefix = str:match([=[^%a:[\\/]]=])
    if disk_prefix then
      return disk_prefix, pathtype.WINDOWS_FILE
    end
    local unc_prefix = str:match([[\\]])
    if unc_prefix then
      return unc_prefix, pathtype.WINDOWS_UNC
    end
  else
    return str:match("^/"), pathtype.LINUX_FILE
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

---@param str string
---@param relative boolean? Whether the str is known to be relative to this path or not
---@param fast boolean? Whether we should do some slow operations like normalizing path separators or not
function Path:_append_string(str, relative, fast)
  local prefix, rest
  if relative == nil then
    prefix = extract_prefix(str)
    relative = prefix ~= nil
  end

  if utils.is_windows and not fast then
    str = str:gsub("/", "\\")
  end

  local segment_iter = vim.gsplit(str, utils.is_windows and "\\" or "/", { plain = true })
  if relative then
    for segment in segment_iter do
      if segment == ".." then
        self[#self] = nil
      elseif segment == "." then
        -- do nothing
      else
        self[#self + 1] = segment
      end
    end
  else
    self:clear()
    for segment in segment_iter do
      self[#self + 1] = segment
    end
  end
end

function Path:clear()
  self.prefix = nil
  local count = #self
  for i = 1, count do
    self[i] = nil
  end
end

local fast_list_extend
if table.move then
  ---@generic T: table
  ---@param dst T List which will be modified and appended to
  ---@param src any[]
  ---@param start integer?
  ---@param finish integer?
  ---@return T
  fast_list_extend = function(dst, src, start, finish)
    return table.move(src, start or 1, finish or #src, #dst, dst)
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
---@return neotree.Path
function Path:parent_path(levels_up)
  self:normalize()
  return Path:new(fast_list_extend({}, self, 0, #self - (levels_up or 1)))
end

function Path:up(levels) end

return Path
