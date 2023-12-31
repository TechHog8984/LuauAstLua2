local Char = require "src.Char";
local String = require "src.String";
local enum = require "src.enum";
local Lexeme = require "src.Lexeme";
local kReserved = require "src.kReserved";
local Position = require "src.Position";
local Location = require "src.Location";
local Vector = require "src.Vector"

local kReservedMap = {};
for k in next, kReserved do
    kReservedMap[k] = true;
end;

local string_char = string.char;

local LuauLexerLookaheadRemembersBraceType = false;

---@param char Char
---@return boolean
---@nodiscard
local function isLowerCaseLetter(char)
    local difference = char - Char['a'];

    return (difference and difference.b < 26) == true;
end;
---@param char Char
---@return boolean
---@nodiscard
local function isUpperCaseLetter(char)
    local difference = char - Char['A'];

    return (difference and difference.b < 26) == true;
end;
---@param char Char
---@return boolean
---@nodiscard
local function isAlpha(char)
    return isLowerCaseLetter(char) or isUpperCaseLetter(char);
end;
---@param char Char
---@return boolean
---@nodiscard
local function isHexLetter(char)
    local lower_difference = char - Char['a'];
    local upper_difference = char - Char['A'];

    return ((lower_difference and lower_difference.b < 6) or (upper_difference and upper_difference.b < 6)) == true;
end;
---@param char Char
---@return boolean
---@nodiscard
local function isDigit(char)
    local difference = char - Char['0'];
    return (difference and difference.b < 10) == true;
end;

---@param char Char
---@return boolean
---@nodiscard
local function isHexDigit(char)
    return isDigit(char) or isHexLetter(char);
end;
---@param char Char
---@return boolean
---@nodiscard
local function isNewLine(char)
    return char == Char.newline;
end;

local unescape_map = {
    [Char['a']] = Char['\a'],
    [Char['b']] = Char['\b'],
    [Char['f']] = Char['\f'],
    [Char['n']] = Char.newline,
    [Char['r']] = Char['\r'],
    [Char['t']] = Char['\t'],
    [Char['v']] = Char['\v']
}
local function unescape(char)
    return unescape_map[char] or char;
end;
---@param char Char
---@return boolean
---@nodiscard
local function isSpace(char)
    local ch = char.c;
    return char == Char.space or ch == '\t' or ch == '\r' or ch == '\n' or ch == '\v' or ch == '\f';
end;

---@enum BraceType
local BraceType = {
    InterpolatedString = 0,
    Normal = 1
};

---@class (exact) Lexer
---@field __index Lexer
---@field new fun(buffer: string, buffer_size: integer, names: AstNameTable): Lexer
---@field buffer String
---@field buffer_size integer
---@field offset integer
---@field line integer
---@field line_offset integer
---@field lexeme Lexeme
---@field previous_location Location
---@field names AstNameTable
---@field skip_comments boolean
---@field read_names boolean
---@field brace_stack Vector
local Lexer = {};
Lexer.__index = Lexer;

---@param buffer string
---@param buffer_size integer
---@param names AstNameTable
---@return Lexer
---@nodiscard
function Lexer.new(buffer, buffer_size, names)
    ---@type Lexer
    local self = setmetatable({
        buffer = String.new(buffer),
        buffer_size = buffer_size,
        offset = 0,
        line = 0,
        line_offset = 0,
        lexeme = Lexeme.new(Location.new(Position.new(0,0), 0), Lexeme.Type.Eof),
        names = names,
        skip_comments = false,
        read_names = true,
        brace_stack = Vector.new()
    }, Lexer);

    return self;
end;

---@param skip boolean
---@return nil
function Lexer:setSkipComments(skip)
    self.skip_comments = skip;
end;
---@param read boolean
---@return nil
function Lexer:setReadNames(read)
    self.read_names = read;
end;

---@return Location
---@nodiscard
function Lexer:previousLocation()
    return self.previous_location;
end;

---@param skip_comments boolean?
---@param update_previous_location boolean?
---@return Lexeme
---@nodiscard
function Lexer:next(skip_comments, update_previous_location)
    skip_comments = skip_comments == nil and self.skip_comments or skip_comments;
    update_previous_location = update_previous_location == nil and true or update_previous_location;

    -- in skip_comments mode, we reject valid comments
    repeat
        -- consume whitespace before the token
        while isSpace(self:peekch()) do
            self:consumeAny();
        end;

        if update_previous_location then
            self.previous_location = self.lexeme.location;
        end;

        self.lexeme = self:readNext();
        update_previous_location = false;
    until not (skip_comments and (self.lexeme.type == Lexeme.Type.Comment or self.lexeme.type == Lexeme.Type.BlockComment));

    return self.lexeme;
end;

---@return nil
function Lexer:nextLine()
    while self:peekch() ~= Char.null and self:peekch() ~= Char['\r'] and not isNewLine(self:peekch()) do
        self:consume();
    end;
end;

---@return Lexeme
---@nodiscard
function Lexer:lookAhead()
    local current_offset = self.offset;
    local current_line = self.line;
    local current_line_offset = self.line_offset;
    local current_lexeme = self.lexeme;
    local current_previous_location = self.previous_location;
    local current_brace_stack_size = self.brace_stack:size();
    local current_brace_type = self.brace_stack:empty() and BraceType.Normal or self.brace_stack:back();

    local result = self:next();

    self.offset = current_offset;
    self.line = current_line;
    self.line_offset = current_line_offset;
    self.lexeme = current_lexeme;
    self.previous_location = current_previous_location;

    if LuauLexerLookaheadRemembersBraceType then
        if self.brace_stack:size() < current_brace_stack_size then
            self.brace_stack:pushBack(current_brace_type);
        elseif self.brace_stack:size() > current_brace_stack_size then
            self.brace_stack:popBack();
        end;
    end;

    return result;
end;
---@return Lexeme
---@nodiscard
function Lexer:current()
    return self.lexeme;
end;

---@param word string
---@return boolean
---@nodiscard
function Lexer:isReserved(word)
    return kReservedMap[word] == true;
end;

---@param look_ahead integer?
---@return Char
---@nodiscard
function Lexer:peekch(look_ahead)
    look_ahead = look_ahead == nil and 0 or look_ahead;
    return (self.offset + look_ahead < self.buffer_size) and self.buffer[self.offset + look_ahead] or Char.null;
end;

---@return Position
---@nodiscard
function Lexer:position()
    return Position.new(self.line, self.offset - self.line_offset);
end;

---@return nil
function Lexer:consume()
    -- consume() assumes current character is known to not be a newline; use consumeAny if this is not guaranteed
    assert(not isNewLine(self.buffer[self.offset]));

    self.offset = self.offset + 1;
end;
---@return nil
function Lexer:consumeAny()
    if isNewLine(self.buffer[self.offset]) then
        self.line = self.line + 1;
        self.line_offset = self.offset + 1;
    end;

    self.offset = self.offset + 1;
end;

---@return Lexeme
---@nodiscard
function Lexer:readCommentBody()
    local start = self:position();

    assert(self:peekch(0) == Char.hyphen and self:peekch(1) == Char.hyphen);
    self:consume();
    self:consume();

    local start_offset = self.offset;

    if self:peekch() == Char['['] then
        local sep = self:skipLongSeparator();

        if sep >= 0 then
            return self:readLongString(start, sep, Lexeme.Type.BlockComment, Lexeme.Type.BrokenComment);
        end
    end;

    -- fall back to single-line comment
    while (self:peekch() ~= Char.null and self:peekch() ~= Char['\r'] and not isNewLine(self:peekch())) do
        self:consume();
    end;

    return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.Comment, self.buffer:splice(start_offset, self.offset - start_offset), self.offset - start_offset);
end;
--- Given a sequence [===[ or ]===], returns:
--- 1. number of equal signs (or 0 if none present) between the brackets
--- 2. -1 if this is not a long comment/string separator
--- 3. -N if this is a malformed separator
---<br>
--- Does *not* consume the closing brace.
---@return integer
function Lexer:skipLongSeparator()
    local start = self:peekch();

    assert(start == Char['['] or start == Char[']']);
    self:consume();

    local count = 0;

    while (self:peekch() == Char.equals) do
        self:consume();
        count = count + 1;
    end;

    return (start == self:peekch()) and count or (-count) - 1;
end;

---@param start Position
---@param sep integer
---@param ok LexemeType
---@param broken LexemeType
---@return Lexeme
---@nodiscard
function Lexer:readLongString(start, sep, ok, broken)
    -- skip (second) [
    assert(self:peekch() == Char['[']);
    self:consume();

    local start_offset = self.offset;

    while self:peekch() ~= Char.null do
        if self:peekch() == Char[']'] then
            if self:skipLongSeparator() == sep then
                assert(self:peekch() == Char[']']);
                self:consume(); -- skip (second) ]

                local end_offset = self.offset - sep - 2;
                assert(end_offset >= start_offset);

                return Lexeme.new(Location.new(start, self:position()), ok, self.buffer:splice(start_offset, end_offset - start_offset), end_offset - start_offset);
            end;
        else
            self:consumeAny();
        end;
    end;

    return Lexeme.new(Location.new(start, self:position()), broken);
end;

---@return nil
function Lexer:readBackslashInString()
    assert(self:peekch() == Char.backslash);
    self:consume();
    local char = self:peekch();
    if char == Char['\r'] then
        self:consume();
        if self:peekch() == Char.newline then
            self:consumeAny();
        end;
    elseif char == Char.null then
        -- pass
---@diagnostic disable-next-line: undefined-field
    elseif char == Char.z then
        self:consume();
        while isSpace(self:peekch()) do
            self:consumeAny();
        end;
    else
        self:consumeAny();
    end;
end;

---@return Lexeme
---@nodiscard
function Lexer:readQuotedString()
    local start = self:position();

    local delimiter = self:peekch();
    assert(delimiter == Char.singlequote or delimiter == Char.quote);
    self:consume();

    local start_offset = self.offset;

    local char = self:peekch();
    while char ~= delimiter do
        if char == Char.null or char == Char['\r'] or char == Char.newline then
            return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenString);
        elseif char == Char.backslash then
            self:readBackslashInString();
            break;
        else
            self:consume();
        end;
        char = self:peekch();
    end;

    self:consume();

    return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.QuotedString, self.buffer:splice(start_offset, self.offset - start_offset - 1), self.offset - start_offset - 1);
end;

---@return Lexeme
---@nodiscard
function Lexer:readInterpolatedStringBegin()
    assert(self:peekch() == Char['`']);

    local start = self:position();
    self:consume();

    return self:readInterpolatedStringSection(start, Lexeme.Type.InterpStringBegin, Lexeme.Type.InterpStringSimple);
end;

---@param start Position
---@param format_type LexemeType
---@param end_type LexemeType
---@return Lexeme
---@nodiscard
function Lexer:readInterpolatedStringSection(start, format_type, end_type)
    local start_offset = self.offset;

    local char = self:peekch();
    while char ~= Char['`'] do
        if char == Char.null or char == Char['\r'] or char == Char.newline then
            return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenString);
        elseif char == Char.backslash then
---@diagnostic disable-next-line: undefined-field
            if self:peekch(1) == Char.u and self:peekch(2) == Char['{'] then
                self:consume(); -- backslash
                self:consume(); -- u
                self:consume(); -- {
            else
                self:readBackslashInString();
            end;
        elseif char == Char['{'] then
            self.brace_stack:pushBack(BraceType.InterpolatedString);

            if self:peekch(1) == Char['{'] then
                local broken_double_brace = Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenInterpDoubleBrace, self.buffer:splice(start_offset, self.offset - start_offset), self.offset - start_offset);
                self:consume();
                self:consume();
                return broken_double_brace;
            end;

            self:consume();
            return Lexeme.new(Location.new(start, self:position()), format_type, self.buffer:splice(start_offset, self.offset - start_offset - 1), self.offset - start_offset - 1);
        else
            self:consume();
        end;
        char = self:peekch();
    end;

    self:consume();

    return Lexeme.new(Location.new(start, self:position()), end_type, self.buffer:splice(start_offset, self.offset - start_offset - 1), self.offset - start_offset - 1);
end;

---@param start Position
---@param start_offset integer
---@return Lexeme
---@nodiscard
function Lexer:readNumber(start, start_offset)
    assert(isDigit(self:peekch()));

    -- This function does not do the number parsing - it only skips a number-like pattern.
    -- It uses the same logic as Lua stock lexer; the resulting string is later converted
    -- to a number with proper verification.

    repeat
        self:consume();
    until not (isDigit(self:peekch()) or self:peekch() == Char['.'] or self:peekch() == Char['_']);

---@diagnostic disable-next-line: undefined-field
    if self:peekch() == Char.e or self:peekch() == Char.E then
        self:consume();

        if self:peekch() == Char['+'] or self:peekch() == Char['-'] then
            self:consume();
        end;
    end;

    while isAlpha(self:peekch()) or isDigit(self:peekch()) or self:peekch() == Char['_'] do
        self:consume();
    end;

    return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.Number, self.buffer:splice(start_offset, self.offset - start_offset), self.offset - start_offset);
end;

---@return AstName, LexemeType
---@nodiscard
function Lexer:readName()
    assert(isAlpha(self:peekch()) or self:peekch() == Char['_']);

    local start_offset = self.offset;

    repeat
        self:consume();
    until not (isAlpha(self:peekch()) or isDigit(self:peekch()) or self:peekch() == Char['_']);

    local method = self.read_names and "getOrAddWithType" or "getWithType";
    return self.names[method](self.names, self.buffer:splice(start_offset, self.offset - start_offset), self.offset - start_offset);
end;

---@return Lexeme
---@nodiscard
function Lexer:readNext()
    local start = self:position();

    local char = self:peekch();
    if char == Char.null then
        return Lexeme.new(Location.new(start, 0), Lexeme.Type.Eof);
    elseif char == Char.hyphen then
        char = self:peekch(1);
        if char == Char['>'] then
            self:consume();
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.SkinnyArrow);
        elseif char == Char.equals then
            self:consume();
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.SubAssign);
        elseif char == Char['-'] then
            return self:readCommentBody();
        else
            self:consume();
            return Lexeme.new(Location.new(start, 1), Char.hyphen.b);
        end
    elseif char == Char['['] then
        local sep = self:skipLongSeparator();

        if sep >= 0 then
            return self:readLongString(start, sep, Lexeme.Type.RawString, Lexeme.Type.BrokenString);
        elseif sep == -1 then
            return Lexeme.new(Location.new(start, 1), Char['['].b);
        else
            return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenString);
        end
    elseif char == Char['{'] then
        self:consume();

        if not self.brace_stack:empty() then
            self.brace_stack:pushBack(BraceType.Normal);
        end;

        return Lexeme.new(Location.new(start, 1), Char['{'].b);
    elseif char == Char['}'] then
        self:consume();

        if self.brace_stack:empty() then
            return Lexeme.new(Location.new(start, 1), Char['}'].b);
        end;

        local brace_stack_top = self.brace_stack:back();
        self.brace_stack:popBack();

        if brace_stack_top ~= BraceType.InterpolatedString then
            return Lexeme.new(Location.new(start, 1), Char['}'].b);
        end;

        return self:readInterpolatedStringSection(self:position(), Lexeme.Type.InterpStringMid, Lexeme.Type.InterpStringEnd);
    elseif char == Char.equals then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.Equal);
        else
            return Lexeme.new(Location.new(start, 1), Char.equals.b);
        end;
    elseif char == Char['<'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.LessEqual);
        else
            return Lexeme.new(Location.new(start, 1), Char['<'].b);
        end;
    elseif char == Char['>'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.GreaterEqual);
        else
            return Lexeme.new(Location.new(start, 1), Char['>'].b);
        end;
    elseif char == Char['~'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.NotEqual);
        else
            return Lexeme.new(Location.new(start, 1), Char['~'].b);
        end;
    elseif char == Char.quote or char == Char.singlequote then
        return self:readQuotedString();
    elseif char == Char['`'] then
        return self:readInterpolatedStringBegin();
    elseif char == Char['.'] then
        self:consume();

        if self:peekch() == Char['.'] then
            self:consume();

            if self:peekch() == Char['.'] then
                self:consume();

                return Lexeme.new(Location.new(start, 3), Lexeme.Type.Dot3);
            elseif self:peekch() == Char.equals then
                self:consume();

                return Lexeme.new(Location.new(start, 3), Lexeme.Type.ConcatAssign);
            else
                return Lexeme.new(Location.new(start, 2), Lexeme.Type.Dot2);
            end;
        elseif isDigit(self:peekch()) then
            return self:readNumber(start, self.offset - 1);
        else
            return Lexeme.new(Location.new(start, 1), Char['.'].b);
        end;
    elseif char == Char['+'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.AddAssign);
        else
            return Lexeme.new(Location.new(start, 1), Char['+'].b);
        end;
    elseif char == Char['/'] then
        self:consume();

        char = self:peekch();

        if char == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.DivAssign);
        elseif char == Char['/'] then
            self:consume();

            if self:peekch() == Char.equals then
                self:consume();
                return Lexeme.new(Location.new(start, 2), Lexeme.Type.FloorDivAssign);
            else
                return Lexeme.new(Location.new(start, 2), Lexeme.Type.FloorDiv);
            end;
        else
            return Lexeme.new(Location.new(start, 1), Char['/'].b);
        end
    elseif char == Char['*'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.MulAssign);
        else
            return Lexeme.new(Location.new(start, 1), Char['*'].b);
        end;
    elseif char == Char['%'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.ModAssign);
        else
            return Lexeme.new(Location.new(start, 1), Char['%'].b);
        end;
    elseif char == Char['^'] then
        self:consume();

        if self:peekch() == Char.equals then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.PowAssign);
        else
            return Lexeme.new(Location.new(start, 1), Char['^'].b);
        end;
    elseif char == Char[':'] then
        self:consume();

        if self:peekch() == Char[':'] then
            self:consume();
            return Lexeme.new(Location.new(start, 2), Lexeme.Type.DoubleColon);
        else
            return Lexeme.new(Location.new(start, 1), Char[':'].b);
        end;
    elseif char == Char['('] or char == Char[')'] or char == Char[']'] or char == Char[';'] or
            char == Char[','] or char == Char['#'] or char == Char['?'] or char == Char['&'] or char == Char['|'] then
        char = self:peekch();
        self:consume();

        return Lexeme.new(Location.new(start, 1), char.b);
    else
        if isDigit(self:peekch()) then
            return self:readNumber(start, self.offset);
        elseif isAlpha(self:peekch()) or self:peekch() == Char['_'] then
            local name, type_ = self:readName();

            return Lexeme.new(Location.new(start, self:position()), type_, name.value);
        elseif self:peekch().b & 0x80 > 0 then
            return self:readUtf8Error();
        else
            char = self:peekch();
            self:consume();

            return Lexeme.new(Location.new(start, 1), char.b);
        end;
    end;
end;

---@return Lexeme
function Lexer:readUtf8Error()
    local start = self:position();
    local codepoint = 0;
    local size = 0;

    if (self:peekch().b & 128) == 0 then
        size = 1;
        codepoint = self:peekch().b & 0x7F;
    elseif (self:peekch().b & 224) == 192 then
        size = 2;
        codepoint = self:peekch().b & 31;
    elseif (self:peekch().b & 240) == 224 then
        size = 3;
        codepoint = self:peekch().b & 15;
    elseif (self:peekch().b & 248) == 240 then
        size = 4;
        codepoint = self:peekch().b & 7;
    else
        self:consume();
        return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenUnicode);
    end;

    self:consume();

    for _ = 1, size - 1 do
        if (self:peekch().b & 192) ~= 128 then
            return Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenUnicode);
        end;
        codepoint = codepoint << 6;
        codepoint = codepoint | (self:peekch().b & 63);
        self:consume();
    end;

    local result = Lexeme.new(Location.new(start, self:position()), Lexeme.Type.BrokenUnicode);
    result.codepoint = codepoint;
    return result;
end;

---@param data String
---@param code integer
---@return integer
local function toUtf8(data, code)
    -- U+0000..U+007F
    if code < 0x80 then
        data[0] = Char[code];
        return 1;
    -- U+0080..U+07FF
    elseif code < 0x800 then
        data[0] = Char[0xC0 | (code >> 6)];
        data[1] = Char[0x80 | (code & 0x3F)];
        return 2;
    -- U+0800..U+FFFF
    elseif code < 0x10000 then
        data[0] = Char[0xE0 | (code >> 12)];
        data[1] = Char[0x80 | ((code >> 6) & 0x3F)];
        data[2] = Char[0x80 | (code & 0x3F)];
        return 3;
    -- U+10000..U+10FFFF
    elseif code < 0x110000 then
        data[0] = Char[0xF0 | (code >> 18)];
        data[1] = Char[0x80 | ((code >> 12) & 0x3F)];
        data[2] = Char[0x80 | ((code >> 6) & 0x3F)];
        data[3] = Char[0x80 | (code & 0x3F)];
        return 4;
    else
        return 0;
    end;
end;

---@param data String
---@return boolean
---@nodiscard
function Lexer:fixupQuotedString(data)
    if data:empty() or data:find(Char.backslash) == -1 then
        return true;
    end;

    local length = data.length;
    local write = 0;

    local i = 0;
    while i < length do
        if data[i] ~= Char.backslash then
            write = write + 1;
            data[write] = data[i];
            i = i + 1;
        else
            if i + 1 == length then
                return false;
            end;

            local escape = data[i + 1];
            i = i + 1; -- skip \e

            if escape == Char.newline then
                write = write + 1;
                data[write] = Char.newline;
            elseif escape == Char['\r'] then
                write = write + 1;
                data[write] = Char.newline;
                if i < length and data[i] == Char.newline then
                    i = i + 1;
                end;
            elseif escape == Char.null then
                return false;
---@diagnostic disable-next-line: undefined-field
            elseif escape == Char.x then
                -- hex escape codes are exactly 2 hex digits long
                if i + 2 > length then
                    return false;
                end;

                local code = 0;

                for j = 0, 1 do
                    local char = data[i + j];
                    if not isHexDigit(char) then
                        return false;
                    end;

---@diagnostic disable-next-line: undefined-field
                    local offset = isDigit(char) and char - Char['0'] or (isLowerCaseLetter(char) and char - Char.a or isUpperCaseLetter(char) and char - Char.A) + 10;
                    code = 16 * code + offset;
                end;

                write = write + 1;
                data[write] = string_char(code);
                i = i + 2;
---@diagnostic disable-next-line: undefined-field
            elseif escape == Char.z then
                while i < length and isSpace(data[i]) do
                    i = i + 1;
                end;
---@diagnostic disable-next-line: undefined-field
            elseif escape == Char.u then
                -- unicode escape codes are at least 3 characters including braces
                if i + 3 > length then
                    return false;
                end;

                if data[i] ~= Char['{'] then
                    return false;
                end;
                i = i + 1;

                if data[i] == Char['}'] then
                    return false;
                end;

                local code = 0;

                for _ = 0, 15 do
                    if i == length then
                        return false;
                    end;

                    local char = data[i];

                    if char == Char['}'] then
                        break;
                    end;

                    if not isHexDigit(char) then
                        return false;
                    end;

---@diagnostic disable-next-line: undefined-field
                    local offset = isDigit(char) and char - Char['0'] or (isLowerCaseLetter(char) and char - Char.a or isUpperCaseLetter(char) and char - Char.A) + 10;
                    code = 16 * code + offset;
                    i = i + 1;
                end;

                if i == length or data[i] ~= Char['}'] then
                    return false;
                end;
                i = i + 1;

                local utf8 = toUtf8(data[write], code);
                if utf8 == 0 then
                    return false;
                end;

                write = write + utf8;
            else
                if isDigit(escape) then
                    local code = escape - Char['0'].b;

                    for _ = 0, 1 do
                        if i == length or not isDigit(data[i]) then
                            break;
                        end;

                        code = 10 * code + (data[i] - Char['0']);
                        i = i + 1;
                    end;

                    if code > 0xff then
                        return false;
                    end;

                    write = write + 1;
                    data[write] = string_char(code);
                else
                    write = write + 1;
                    data[write] = unescape(escape);
                end;
            end;
        end;
    end;

    assert(write <= length);
    -- no resize here since String newindex already does it O_o

    return true;
end;
---@param data String
---@return nil
function Lexer:fixupMultilineString(data)
    if data:empty() then
        return;
    end;

    -- Lua rules for multiline strings are as follows:
    -- - standalone \r, \r\n, \n\r and \n are all considered newlines
    -- - first newline in the multiline string is skipped
    -- - all other newlines are normalized to \n

    -- Since our lexer just treats \n as newlines, we apply a simplified set of rules that is sufficient to get normalized newlines for Windows/Unix:
    -- - \r\n and \n are considered newlines
    -- - first newline is skipped
    -- - newlines are normalized to \n

    -- This makes the string parsing behavior consistent with general lexing behavior - a standalone \r isn't considered a new line from the line
    -- tracking perspective

    if data[0] == Char['\r'] and data[1] == Char.newline then
        data[0] = nil;
        data[0] = nil;
    elseif data[0] == Char.newline then
        data[0] = nil;
    end;

    -- parse the rest of the string, converting newlines as we go
    local i = 0;
    while i < data.length do
        if data[i] == Char['\r'] and data[i + 1] == Char.newline then
            data[i] = Char.newline;
            data[i + 1] = nil;
        end;
        i = i + 1;
    end;
end;

return Lexer;