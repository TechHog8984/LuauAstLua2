---@param items any[]
---@return { [string]: integer }
---@nodiscard
local function enum(items)
    local result = {};

    local last_value = -1;
    for _, key in ipairs(items) do
        local value;
        if type(key) == "table" then
            key, value = next(key);
            if type(value) == "string" then
                value = result[value];
            end;
        else
            value = last_value + 1;
        end;
        last_value = value;
        result[key] = value;
    end;

    return result;
end;

return enum;