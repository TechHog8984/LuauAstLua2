---@class (exact) Position
---@field __index Position
---@field new fun(line: integer, column: integer): Position
---@field line integer
---@field column integer
local Position = {};
Position.__index = Position;

---@param line integer
---@param column integer
---@return Position
---@nodiscard
function Position.new(line, column)
    ---@type Position
    local self = setmetatable({
        line = line,
        column = column
    }, Position);

    return self;
end;

---@param rhs Position
---@return boolean
---@nodiscard
function Position:__eq(rhs)
    return self.column == rhs.column and self.line == rhs.line;
end;

---@param rhs Position
---@return boolean
---@nodiscard
function Position:__lt(rhs)
    if self.line == rhs.line then
        return self.column < rhs.column;
    else
        return self.line < rhs.line;
    end;
end;

---@param rhs Position
---@return boolean
---@nodiscard
function Position:__le(rhs)
    return self == rhs or self < rhs;
end;

---@param start Position
---@param old_end Position
---@param new_end Position
---@return nil
function Position:shift(start, new_end, old_end)
    if self >= start then
        if self.line > old_end.line then
            self.line = self.line + (new_end.line - old_end.line);
        else
            self.line = new_end.line;
            self.column = self.column + (new_end.column - old_end.column);
        end;
    end;
end;

return Position;