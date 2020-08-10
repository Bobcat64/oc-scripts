local lib = {}

function lib.loadConfig(fname, env)
    local e = env or {}
    local data = loadfile(fname, nil, e)
    if data then
        pcall(data)
    end
    return e
end

function lib.saveConfig(fname, conf)
    local fs = require('filesystem')
    --check for readonly system
    local path = fs.path(fname)
    local root, err = fs.get(path)
    if root == nil then
        error("Filesystem not found: " .. err, 1)
    end
    if root.isReadOnly() then
        return false, 'Readonly Filesystem'
    end
    local s
    s, err = root.makeDirectory(path)
    if not s then return false, err end

    local f = io.open(fname, "w")
    if not f then return false, 'Could not open file for writing' end

    local serial = require('serialization')
    conf = conf or {}
    for k,v in pairs(conf) do
        f:write(k.."="..tostring(serial.serialize(v, math.huge)).."\n")
    end
    f:close()
    return true
end

return lib