--[[Wallwalking by Addi--]]

-- Shared files
for k, name in ipairs({
    "sh/init.lua",
}) do
    if (SERVER) then
        AddCSLuaFile("wallwalking/" .. name)
    end
    include("wallwalking/" .. name)
end
--[[
-- Server files
if (SERVER) then
    for k, name in ipairs({
    }) do
        include("wallwalking/" .. name)
    end
end

-- Main client files
for k, name in ipairs({-
}) do
    if (SERVER) then
        AddCSLuaFile("wallwalking/" .. name)
    else
        include("wallwalking/" .. name)
    end
end
--]]