local Char = require "src.Char";

---@class (exact) String
---@field new fun(str: string): String
---@field splice fun(self: String, start: integer, length: integer): string
---@field empty fun(self: String): boolean
---@field find fun(self: String, char: Char): integer
---@field characters Char[]
---@field bytes integer[]
---@field length integer
local String = {};

---@param key any
---@return any
---@nodiscard
function String:__index(key)
    if type(key) == "number" then
        return self.characters[key];
    end;
    return rawget(self, key) or String[key];
end;

---@param table_ table
---@param position integer
local function remove(table_, position)
    local removed = table_[position];

    for index = position, #table_ do
        table_[index] = table_[index + 1];
    end;

    return removed;
end;
---@param key integer
---@param value any
---@nodiscard
function String:__newindex(key, value)
    if self:empty() then
        error("__newindex on a String expects a non-empty String");
    end;
    if type(key) ~= "integer" then
        error("__newindex on String expects key to be an integer");
    end;
    if type(value) ~= "nil" and (type(value) ~= "table" or getmetatable(value) ~= Char) then
        error("__newindex on String expects value to be a Char or nil");
    end;

    if value then
        if key <= self.length then
            error("__newindex on String expects key to be less than the length");
        end;
        if not self.characters[key] then
            self.length = self.length + 1;
        end;
        self.characters[key] = value;
        self.bytes[key] = value.b;
        return;
    end;

    self.length = self.length - 1;
    remove(self.characters, key);
    remove(self.bytes, key);
    self.characters[key] = nil;
    self.bytes[key] = nil;
end;

---@param str string
---@return String
---@nodiscard
function String.new(str)
    local length = 0;
    local characters = {};
    local bytes = {};
    local character;
    for char in str:gmatch('.') do
        character = Char.new(char);
        characters[length] = character;
        bytes[length] = character.b;
        length = length + 1;
    end;

    ---@type String
    local self = setmetatable({
        characters = characters,
        bytes = bytes,
        length = length
    }, String);

    return self;
end;

---@param start integer
---@param length integer
---@return string
function String:splice(start, length)
    local result = '';

    for i = start, start + length - 1 do
        result = result .. self[i].c;
    end;

    return result;
end;

---@return boolean
function String:empty()
    return self.length < 1;
end;

---@param char Char
---@return integer
function String:find(char)
    for index, byte in next, self.bytes do
        if byte == char.b then
            return index;
        end;
    end;
    return -1;
end;

return String;