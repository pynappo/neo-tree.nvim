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
  o.dirty = #o.unnormalized > 0
  o._cache = {}
  return o
end

---@return neotree.Path normalized_copy
function Path:copy()
  return Path:new()
end

---@param b neotree.Pathish
function Path:__div(b)
  return Path:new(self, b)
end

function Path.__tostring(self)
  self:normalize()
  if not self._cache.string then
    self._cache.string = (self.root or "") .. table.concat(self, utils.path_separator)
  end
  return self._cache.string
end

---Normalizes the path
---@return self neotree.Path
function Path:normalize()
  if not self.dirty then
    return self
  end

  for _, segment in ipairs(self.unnormalized) do
    if type(segment) == "string" then
      self:_append_string(segment)
    else
      assert(type(segment) == "table")
      if getmetatable(segment) == Path then
        ---@cast segment neotree.Path
        segment:normalize()
        if segment.root then
          self.root = segment.root
        end
      end
      for _, part in ipairs(segment) do
        self:_append_string(part)
      end
    end
  end

  self._cache = {}
  self.unnormalized = {}
  self.dirty = false

  return self
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

---@param str string
---@param relative boolean? Whether the str is known to be relative to this path or not
---@param fast boolean? Whether we should do some slow operations like normalizing path separators or not
function Path:_append_string(str, relative, fast)
  local prefix
  if relative == nil or not relative then
    prefix = extract_prefix(str)
    if prefix then
      relative = false
      str = str:sub(#prefix + 1)
      -- reset to the prefix
      self.root = prefix
      for i = 1, #self do
        self[i] = nil
      end
    end
  end

  if utils.is_windows and not fast then
    str = str:gsub("/", "\\")
  end

  local segment_iter = vim.gsplit(str, utils.is_windows and "\\" or "/", { plain = true })
  for segment in segment_iter do
    if segment == "" then
    elseif segment == ".." then
      if self.root then
        -- remove a segment
        self[#self] = nil
      else
        local prev = self[#self]
        if #self == 0 or prev == ".." then
          -- add a ..
          self[#self + 1] = segment
        elseif prev == "." then
          self[#self] = segment
        else
          -- remove the previous relative segment
          self[#self] = nil
        end
      end
    elseif segment == "." and #self > 0 then
      -- do nothing
    else
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

---@param base neotree.Pathish
---@vararg neotree.Pathish paths
---@return neotree.Path new_joined_path
function Path.join(base, ...)
  return Path:new(base, ...)
end

---@return string
function Path:parent()
  return tostring(self):match(self.sep)
end

---@return neotree.Path? new_parent_path
function Path:parent_path(levels_up)
  if #self == 0 then
    return nil
  end
  return Path:new(fast_list_extend({ self.root }, self, 0, #self - (levels_up or 1)))
end

return Path
