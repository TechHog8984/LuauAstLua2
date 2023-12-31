---@class (exact) Vector
---@field __index Vector
---@field new fun(): Vector
---@field private _size integer
---@field private _elements any[] The array of elements STARTING AT ZERO
local Vector = {};
Vector.__index = Vector;

---@return Vector # An empty vector
---@nodiscard
function Vector.new()
    ---@type Vector
    local self = setmetatable({
        _size = 0,
        _elements = {}
    }, Vector);

    return self;
end;

---@return integer _size
---@nodiscard
function Vector:size()
    return self._size;
end;
---@return boolean # returns true if the size of the vector is above zero
---@nodiscard
function Vector:empty()
    return self._size > 0;
end;
---@return any # The first element
---@nodiscard
function Vector:front()
    if self:empty() then
        error("front() called on an empty vector");
    end;

    return self._elements[0];
end;
---@return any # The last element
---@nodiscard
function Vector:back() --[[any]]
    if self:empty() then
        error("back() called on an empty vector");
    end;

    return self._elements[self._size - 1];
end;

---Adds a value to the end of the vector
---@param value any The value to be pushed
---@return nil
function Vector:pushBack(--[[any]] value)
    local old_size = self._size;
    self._size = old_size + 1;
    self._elements[old_size] = value;
end;
---Removes the last element from the vector
---@return nil
function Vector:popBack()
    if self:empty() then
        error("vector empty before pop");
    end;

    local old_size = self._size;
    self._size = old_size - 1;
    self._elements[old_size] = nil;
end;

return Vector;