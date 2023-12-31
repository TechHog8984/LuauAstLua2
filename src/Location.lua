local Position = require "src.Position";

---@class (exact) Location
---@field __index Location
---@field new fun(arg1: Position|Location?, arg2: Position|Location|integer?): Location
---@field begin Position
---@field end_ Position
local Location = {};
Location.__index = Location;

---this code is ugly sorry
---@param arg1 Position|Location?
---@param arg2 Position|Location|integer?
---@param arg1type type
---@param arg2type type
---@return Position?, Position?
---@nodiscard
local function getBeginAndEnd(arg1, arg2, arg1type, arg2type)
    if arg1type == "nil" and arg2type == "nil" then
        return Position.new(0,0), Position.new(0,0);
    end;

    local arg1_is_table = arg1type == "table";
    local arg2_is_table = arg2type == "table";

    local arg1meta, arg2meta = arg1_is_table and getmetatable(arg1), arg2_is_table and getmetatable(arg2);

    local a = arg1_is_table and arg1meta == Position;
    local b = arg2_is_table and arg2meta == Position;
    if a and b then
        ---@cast arg1 Position
        ---@cast arg2 Position
        return arg1, arg2;
    end;
    if a and arg2type == "number" then
        ---@cast arg1 Position
        return arg1, Position.new(arg1.line, arg1.column + arg2);
    end;

    a = arg1_is_table and arg1meta == Location;
    b = arg2_is_table and arg2meta == Location;
    if a and b then
        ---@cast arg1 Location
        ---@cast arg2 Location
        return arg1.begin, arg2.end_;
    end;
end;

---@param arg1 Position|Location?
---@param arg2 Position|Location|integer?
---@return Location
---@nodiscard
function Location.new(arg1, arg2)
    local begin, end_ = getBeginAndEnd(arg1, arg2, type(arg1), type(arg2));

    ---@type Location
    local self = setmetatable({
        begin = begin,
        end_ = end_
    }, Location);

    return self;
end;

---@param rhs Location
---@return boolean
---@nodiscard
function Location:__eq(rhs)
    return self.begin == rhs.begin and self.end_ == rhs.end_;
end;

---@param l Location
---@return boolean
---@nodiscard
function Location:encloses(l)
    return self.begin <= l.begin and self.end_ >= l.end_;
end;
---@param l Location
---@return boolean
---@nodiscard
function Location:overlaps(l)
    return (self.begin <= l.begin and self.end_ >= l.begin) or (self.begin <= l.end_ and self.end_ >= l.end_) or (self.begin >= l.begin and self.end_ <= l.end_);
end;
---@param p Position
---@return boolean
---@nodiscard
function Location:contains(p)
    return self.begin <= p and p < self.end_;
end;
---@param p Position
---@return boolean
---@nodiscard
function Location:containsClosed(p)
    return self.begin <= p and p <= self.end_;
end;

---@param other Location
---@return nil
function Location:extend(other)
    if other.begin < self.begin then
        self.begin = other.begin;
    end;
    if other.end_ > self.end_ then
        self.end_ = other.end_;
    end;
end;

---@param start Position
---@param old_end Position
---@param new_end Position
function Location:shift(start, old_end, new_end)
    self.begin:shift(start, old_end, new_end);
    self.end_:shift(start, old_end, new_end);
end;

return Location;