local kReserved = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while", "@checked"};

-- make kReserved start at zero
for i = 1, #kReserved + 1 do
    kReserved[i - 1] = kReserved[i];
end;

return kReserved;