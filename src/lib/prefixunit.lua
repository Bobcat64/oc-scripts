local prefixes = {
    {1e18, "E"},
    {1e15, "P"},
    {1e12, "T"},
    {1e9, "G"},
    {1e6, "M"},
    {1e3, "k"},
    {1, ""},
    {1e-3, "m"},
    {1e-6, "u"}, --Using 'u' for max compatability
    {1e-9, "n"},
    {1e-12, "p"},
    {1e-15, "f"},
}


return function (value, unit, fmt)
    checkArg(1, value, "number")
    checkArg(2, unit, "string")
    checkArg(3, fmt, "string", "nil")
    local p
    for i = 1, #prefixes do
        if value > prefixes[i][1] then
            p = prefixes[i]
            break
        end
    end
    if p == nil then --no matches... default to atto
        p = {1e-18, "a"}
    end

    value = value / p[1]

    if fmt == nil then
        if value >= 10 then
            fmt = "%.f "
        else
            fmt = "%.1f "
        end
    end

    return string.format(fmt .. "%s%s",  value, p[2], unit)
end