local enum = require "src.enum";

---@alias LexemeType integer
local LexemeType = enum({
    {Eof = 0},

    -- 1..255 means actual character values
    {Char_END = 256},

    "Equal",
    "LessEqual",
    "GreaterEqual",
    "NotEqual",
    "Dot2",
    "Dot3",
    "SkinnyArrow",
    "DoubleColon",
    "FloorDiv",

    "InterpStringBegin",
    "InterpStringMid",
    "InterpStringEnd",
    -- An interpolated string with no expressions (like `x`)
    "InterpStringSimple",

    "AddAssign",
    "SubAssign",
    "MulAssign",
    "DivAssign",
    "FloorDivAssign",
    "ModAssign",
    "PowAssign",
    "ConcatAssign",

    "RawString",
    "QuotedString",
    "Number",
    "Name",

    "Comment",
    "BlockComment",

    "BrokenString",
    "BrokenComment",
    "BrokenUnicode",
    "BrokenInterpDoubleBrace",
    "Error",

    "Reserved_BEGIN",
    {ReservedAnd = "Reserved_BEGIN"},
    "ReservedBreak",
    "ReservedDo",
    "ReservedElse",
    "ReservedElseif",
    "ReservedEnd",
    "ReservedFalse",
    "ReservedFor",
    "ReservedFunction",
    "ReservedIf",
    "ReservedIn",
    "ReservedLocal",
    "ReservedNil",
    "ReservedNot",
    "ReservedOr",
    "ReservedRepeat",
    "ReservedReturn",
    "ReservedThen",
    "ReservedTrue",
    "ReservedUntil",
    "ReservedWhile",
    "ReservedChecked",
    "Reserved_END"
});
---@class (exact) Lexeme
---@field type LexemeType
---@field location Location
---@field length integer
---@field data string
---@field name string
---@field codepoint integer

local Lexeme = {
    Type = LexemeType
};
Lexeme.__index = Lexeme;

function Lexeme.new(...)
    ---@type Lexeme
    local self = setmetatable({}, Lexeme);

    local argc = select('#', ...);
    if argc == 2 then
        local location, arg2 = ...;
        ---@cast location Location
        ---@type LexemeType
        local type_;
        if type(arg2) == "number" then
            ---@cast arg2 LexemeType
            type_ = arg2;
        else
            ---@cast arg2 Char
            type_ = arg2.b --[[@as LexemeType]];
        end;
        self.type = type_;
        self.location = location;
        self.length = 0;
        -- self.data = nil
    elseif argc == 4 then
        local location, type_, data, size = ...;
        ---@cast location Location
        ---@cast type_ LexemeType
        ---@cast data string
        ---@cast size integer

        assert(type_ == LexemeType.RawString or type_ == LexemeType.QuotedString or type_ == LexemeType.InterpStringBegin or
                type_ == LexemeType.InterpStringMid or type_ == LexemeType.InterpStringEnd or type_ == LexemeType.InterpStringSimple or
                type_ == LexemeType.BrokenInterpDoubleBrace or type_ == LexemeType.Number or type_ == LexemeType.Comment or
                type_ == LexemeType.BlockComment);

        self.type = type_;
        self.location = location;
        self.length = size;
        self.data = data;

    elseif argc == 3 then
        local location, type_, name = ...;
        ---@cast location Location
        ---@cast type_ LexemeType
        ---@cast name string

        self.type = type_;
        self.location = location;
        self.length = 0;
        self.name = name;
    end;

    return self;
end;

return Lexeme;