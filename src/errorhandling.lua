local string_format = string.format;
local check_type_message = "Expected type '%s'; got '%s'";
---@param value any
---@param expected_type type
---@return nil
local function checkType(value, expected_type)
    if type(value) == expected_type then
        return;
    end;
    error(string_format(check_type_message, expected_type, type(value)));
end;

return {
    checkType = checkType
};