-- lzw.lua

local char = string.char
local type = type
local tconcat = table.concat

local basedictcompress = {}
local basedictdecompress = {}
for i = 0, 255 do
    local ic, iic = char(i), char(i, 0)
    basedictcompress[ic] = iic
    basedictdecompress[iic] = ic
end

local function dictAddB(str, dict, a, b)
    if a >= 256 then
        a, b = 0, b + 1
        if b >= 256 then
            dict = {}
            b = 1
        end
    end
    dict[char(a, b)] = str
    a = a + 1
    return dict, a, b
end

local function decompress(input)
    if type(input) ~= "string" then
        return nil, "string expected, got " .. type(input)
    end

    if #input < 1 then
        return nil, "invalid input - not a compressed string"
    end

    local control = input:sub(1, 1)
    if control == "u" then
        return input:sub(2)
    elseif control ~= "c" then
        return nil, "invalid input - not a compressed string"
    end
    input = input:sub(2)
    local len = #input

    if len < 2 then
        return nil, "invalid input - not a compressed string"
    end

    local dict = {}
    local a, b = 0, 1

    local result = {}
    local n = 1
    local last = input:sub(1, 2)
    result[n] = basedictdecompress[last] or dict[last]
    if not result[n] then
        return nil, "could not find last from dict. Invalid input?"
    end
    n = n + 1

    for i = 3, len, 2 do
        local code = input:sub(i, i + 1)
        local lastStr = basedictdecompress[last] or dict[last]
        if not lastStr then
            return nil, "could not find last from dict. Invalid input?"
        end
        local toAdd = basedictdecompress[code] or dict[code]
        if toAdd then
            result[n] = toAdd
            n = n + 1
            dict, a, b = dictAddB(lastStr .. toAdd:sub(1, 1), dict, a, b)
        else
            local tmp = lastStr .. lastStr:sub(1, 1)
            result[n] = tmp
            n = n + 1
            dict, a, b = dictAddB(tmp, dict, a, b)
        end
        last = code
    end
    return tconcat(result)
end

local function httpGetWrapper(url)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        return content
    else
        return nil
    end
end

-- Return the module table
return {
    decompress = decompress,
    httpGetWrapper = httpGetWrapper
}
