local errorhandling = require "src.errorhandling";
local checkType = errorhandling.checkType;

local string_byte = string.byte;
local string_char = string.char;

local cache = {}; --[=[@as Char[]]=]

---@class Char
---@field c string The character as a lua stsring
---@field b integer The byte representing the character
local Char = {};
Char.__index = Char;

---@param character string
---@return Char
---@nodiscard
function Char.new(character)
    checkType(character, "string");
    if #character ~= 1 then
        error("Expected a string with a length of 1; actual length: " .. #character);
    end;

    ---@type Char
    local self = cache[character] or setmetatable({
        c = character,
        b = string_byte(character),
    }, Char);
    cache[character] = self;

    return self;
end;

---@param other Char
---@return boolean
---@nodiscard
function Char:__eq(other)
    return self.c == other.c;
end;

---@param other Char
---@return Char?
---@nodiscard
function Char:__add(other)
    local byte = self.b + other.b;
    if byte > 255 then
        return nil;
    end;
    return Char.new(string_char(byte));
end;
---@param other Char
---@return Char?
---@nodiscard
function Char:__sub(other)
    local byte = self.b - other.b;
    if byte < 0 then
        return nil;
    end;
    return Char.new(string_char(byte));
end;

pcall(function()
    local index = 0;
    local ch = string_char(index);
    local char;
    while ch do
        char = Char.new(ch);
        Char[ch] = char;
        Char[index] = char;
        index = index + 1;
        ch = string_char(index);
    end;
end);

Char.null = Char['\0'];
Char.space = Char[' '];
Char.newline = Char['\n'];
Char.hyphen = Char['-'];
Char.backslash = Char['\\'];
Char.singlequote = Char['\''];
Char.quote = Char['"'];
Char.equals = Char['='];

return Char;