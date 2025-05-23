local typecheck = {}

---Type but also supports "callable" like neovim does.
---@see _G.type
function typecheck.match(obj, expected)
  if type(obj) == expected then
    return true
  end
  if expected == "callable" and vim.is_callable(obj) then
    return true
  end
  return false
end

local errors = {}

---@alias neotree.LuaType type|"callable"
---@alias neotree.Validator<T> elem_or_list<neotree.LuaType>|fun(value: T):boolean?,string?

---A simplified version of vim.validate
---@generic T
---@param name string
---@param value T
---@param validator neotree.Validator<T>
---@param optional? boolean Whether value can be nil
---@param message? string message when validation fails
function typecheck.validate(name, value, validator, optional, message)
  local matched, errmsg, errinfo
  if type(validator) == "string" then
    matched = typecheck.match(value, validator)
  elseif type(validator) == "table" then
    for _, v in ipairs(validator) do
      matched = typecheck.match(value, v)
      if matched then
        break
      end
    end
  elseif vim.is_callable(validator) and value ~= nil then
    matched, errinfo = validator(value)
  end
  matched = matched or (optional and value == nil)
  if not matched then
    local expected_types = type(validator) == "string" and { validator } or validator
    ---@cast expected_types -string
    if optional then
      expected_types[#expected_types + 1] = "nil"
    end
    ---@type string
    local expected
    if vim.is_callable(expected_types) then
      expected = "?"
    else
      ---@cast expected_types -function
      expected = table.concat(expected_types, "|")
    end

    errmsg = ("%s: %s, got %s"):format(
      name,
      message or ("expected " .. expected),
      message and value or type(value)
    )
    if errinfo then
      errmsg = errmsg .. ", Info: " .. errinfo
    end
    error(errmsg, 2)
  end
  return matched
end

typecheck.schema = {}

---Allows for easier validation of table types
---@generic T string
---@param name string Argument name
---@param value T Argument value
---@param validator neotree.Validator<T>
---@param optional? boolean Argument is optional (may be omitted)
---@param advice? string message when validation fails
---@return boolean valid
---@return string? errmsg
function typecheck.schema.create_checker(name) end
