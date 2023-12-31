---@class (exact) AstName
---@field __index AstName
---@field new fun(value:string?): AstName
---@field value string
local AstName = {};
AstName.__index = AstName;

---@param value string?
---@return AstName
function AstName.new(value)
    local self = setmetatable({
        value = value
    }, AstName);

    return self;
end;

---@param rhs AstName
---@return boolean
function AstName:__eq(rhs)
    return self.value == rhs.value;
end;

---@param rhs AstName
---@return boolean
function AstName:__lt(rhs)
    error("unimplemented");
end;

return AstName;