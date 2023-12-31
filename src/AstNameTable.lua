local Lexeme = require "src.Lexeme";
local AstName = require "src.AstName";
local kReserved = require "src.kReserved";

---@class (exact) AstNameTableEntry
---@field new fun(value: AstName, length: integer, type_ :LexemeType): AstNameTableEntry
---@field value AstName
---@field length integer
---@field type LexemeType
local Entry = {};

---@param value AstName
---@param length integer
---@param type_ LexemeType
---@return AstNameTableEntry
function Entry.new(value, length, type_)
    local self = {
        value = value,
        length = length,
        type = type_
    };

    return self;
end;

---@param other AstNameTableEntry
---@return boolean
function Entry:__eq(other)
    return self.length == other.length and self.value.value == other.value.value;
end;

---@class (exact) AstNameTable
---@field __index AstNameTable
---@field new fun(): AstNameTable
---@field data AstNameTableEntry[]
local AstNameTable = {};
AstNameTable.__index = AstNameTable;

---@return AstNameTable
function AstNameTable.new()
    ---@type AstNameTable
    local self = setmetatable({
        data = {
            Entry.new(AstName.new(""), 0, Lexeme.Type.Eof)
        }
    }, AstNameTable);

    for i = Lexeme.Type.Reserved_BEGIN, Lexeme.Type.Reserved_END - 1 do
        self:addStatic(kReserved[i - Lexeme.Type.Reserved_BEGIN], i);
    end;

    return self;
end;

---@private
---@param ast_name AstName
---@param type_ LexemeType
---@return AstNameTableEntry?
function AstNameTable:findByNameAndType(ast_name, type_)
    for _, entry in next, self.data do
        if entry.value == ast_name and entry.type == type_ then
            return entry;
        end;
    end;
end;

---@private
function AstNameTable:findByNameAndLength(name, length)
    for _, entry in next, self.data do
        if entry.length == length and entry.value.value == name then
            return entry;
        end;
    end;
end;

---@param name string
---@param type_ LexemeType
---@return AstName
function AstNameTable:addStatic(name, type_)
    type_ = type_ == nil and Lexeme.Type.Name or type_;

    local ast_name = AstName.new(name);
    assert(not self:findByNameAndType(ast_name, type_));

    local entry = Entry.new(ast_name, #name, type_);
    table.insert(self.data, entry);

    return entry.value;
end;

---@param name string
---@param length integer
---@return AstName, LexemeType
function AstNameTable:getOrAddWithType(name, length)
    local found = self:findByNameAndLength(name, length);
    if found then
        return found.value, found.type;
    end;

    local entry = Entry.new(AstName.new(name), length, Lexeme.Type.Name);
    table.insert(self.data, entry);

    return entry.value, entry.type;
end;

---@param name string
---@param length integer
---@return AstName, LexemeType
---@nodiscard
function AstNameTable:getWithType(name, length)
    local found = self:findByNameAndLength(name, length);
    if found then
        return found.value, found.type;
    end;

    return AstName.new(), Lexeme.Type.Name;
end;

---@param name string
---@return AstName
function AstNameTable:getOrAdd(name)
    return (self:getOrAddWithType(name, #name));
end;

---@param name string
---@return AstName
---@nodiscard
function AstNameTable:get(name)
    return (self:getWithType(name, #name));
end;

return AstNameTable;