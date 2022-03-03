--[[Wallwalkikng by Addi

    This is pretty cursed, not gonna lie, but it works way better than I ever expected it to.

    Hi, thanks for checking out my addon. This was inspired by Mee's Seamless portals
    which uses Player:SetHull() to allow players to enter portals without colliding with
    walls/floors. Here, I use it to modify player collisions on the go to let them walk
    through walls without falling through the floor.

    You can use it and make changes as you like (pls give credit), and find more info
    in the README on Github: https://github.com/itsmeaddof123/gmod-wallwalking

    This file contains the wallwalking system--]]

-- Holds everything in the addon
wallwalking = wallwalking or {}

-- ConVars
local wallwalking_enabled = CreateConVar("wallwalking_enabled", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enable or disable wallwalking", 0, 1)
local wallwalking_max = CreateConVar("wallwalking_max", 4, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How far can you wallwalk?", 1) -- Cost grows exponentially, I don't recommend setting this above 4 
local wallwalking_min = CreateConVar("wallwalking_min", 0.5, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How close should you be to an obstruction before wallwalking?", 0.1, 1) -- 0.5 Seems good, I don't recommend changing this
local wallwalking_gap = CreateConVar("wallwalking_gap", 1.25, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How much of a gap should there be between potential hulls?", 0.5) -- 1.25 seems good, I don't recommend putting this below 1 or above 2

-- Utility function to check if the player will fit in a given spot
local function playerwillfit(ply, pos)
    if (not IsValid(ply)) then
        return
    end

    -- Use defaults for these if they weren't provided in the function call
    pos = pos or ply:GetPos()
    local scale = ply:GetModelScale()
    
    -- TraceHull around the given position with the player's size
    local tr = {
        start = pos,
        endpos = pos,
        filter = ply,
        mins = scale * Vector(-16, -16, 0),
        maxs = scale * Vector(16, 16, ply:Crouching() and 36 or 72),
        mask = MASK_PLAYERSOLID,
    }
    local trace = util.TraceHull(tr)

    -- If something was hit
    if (trace.Hit) then
        return false
    end

    return true
end

-- Traces downward from the given position, ignoring the given player, and finding the length.
local dist = 1000
local function tracedown(pos, ply)
    -- Downward trace
    local tr = {
        start = pos,
        endpos = pos + Vector(0, 0, -dist),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    }
    local trace = util.TraceLine(tr)

    -- If something was hit, find the distance
    if (trace.Hit) then
        return pos.z - trace.HitPos.z
    end

    -- Return the default distance
    return dist
end

-- Finds a set of possible target positions
local function findtargets(ply, returnall) -- returnall is for debug only
    -- TODO(itsmeaddof123) In the future, I may redo the process of scanning for possible target positions:
        -- Get player movement direction and normalize it. That will act as "x"
        -- Find the vector orthonormal to that on the flat plane. That will act as "y"
        -- The "0" position will be maxdistance * playerscale * gap away
        -- The min_x and min_y will be -(maxdistance+1)/2 and the max_x and max_y will be (maxdistance+1)/2
        -- This would make the positions of the hulltraces more relative to the player, rather than the world
        -- But it would keep the rotations relative to the world, which might have a weird effect

    -- Get player's movement and size info
    local vel = ply:GetVelocity()
    local pos = ply:GetPos()
    local scale = ply:GetModelScale()

    -- Get movement vector parts
    local adj = vel.x
    local opp = vel.y

    -- Avoid dividing by 0
    if adj == 0 then
        adj = adj + 0.01
    end
    
    -- Get movement angle
    local yaw = math.atan(opp/adj) * 180 / math.pi
    if adj < 0 then
        if opp > 0 then
            yaw = yaw + 180
        else
            yaw = yaw - 180
        end
    end

    local maxincrements = wallwalking_max:GetInt()

    -- Set initial search bounds
    local min_x = 1
    local max_x = maxincrements
    local min_y = 1
    local max_y = maxincrements

    -- Translate based on yaw
    local yaw = yaw + 22.5
    if yaw % 90 < 45 then
        min_y = (1 - maxincrements) / 2
        max_y = (maxincrements - 1) / 2
    end

    -- Rotate based on yaw
    if yaw % 360 > 270 then
        local max_x_old = max_x
        max_x = max_y
        max_y = -min_x
        min_x = min_y
        min_y = -max_x_old
    elseif yaw % 360 > 180 then
        local max_x_old = max_x
        local max_y_old = max_y
        max_x = -min_x
        min_x = -max_x_old
        max_y = -min_y
        min_y = -max_y_old
    elseif yaw % 360 > 90 then
        local max_x_old = max_x
        max_x = -min_y
        min_y = min_x
        min_x = -max_y
        max_y = max_x_old
    end

    -- If we get here, something is certainly wrong
    if max_x < min_x or max_y < min_y then
        print("ERROR IN LOGIN")
        return
    end

    -- Find valid positions
    local targets = {}
    local size = 32 * scale * wallwalking_gap:GetFloat()
    for i = min_x, max_x do
        for j = min_y, max_y do
            local targetpos = pos + Vector(size * i, size * j, 0)
            local willfit = playerwillfit(ply, targetpos)
            if returnall or willfit then
                table.insert(targets, {
                    Pos = targetpos,
                    Dist = tracedown(targetpos, ply),
                    Fit = willfit,
                })
            end
        end
    end

    return targets
end

-- Finds and sets a new target for the player
local function setnewtarget(ply)
    local targets = findtargets(ply)

    -- No targets found
    if #targets < 1 then
        return false
    end

    -- Picks the target location with the closest z to the player
    table.sort(targets, function(a, b)
        return a.Dist < b.Dist
    end)
    local targetpos = targets[1].Pos

    -- Marks the player as wallwalking
    wallwalking[ply] = {
        pos = targetpos,
        max = math.pow(wallwalking_max:GetInt() * 32 * wallwalking_gap:GetFloat(), 2),
        mintime = CurTime() + 0.1
    }

    return true
end

-- Initiates, executes, and finishes wallwalking
local drawnpos = Vector(0, 0, 0) -- debug only
hook.Add("Tick", "wallwalking_tick", function()
    if not wallwalking_enabled:GetBool() then
        return
    end

    for k, ply in ipairs(player.GetAll()) do
        -- The player is currently wallwalking and should offset or reset their hull
        if wallwalking[ply] then
            -- Skip invalid players
            if not IsValid(ply) then
                wallwalking[ply] = nil
                continue
            end

            -- Remove dead and noclipped players
            if not ply:Alive() or ply:GetMoveType() == MOVETYPE_NOCLIP then
                ply:ResetHull()
                wallwalking[ply] = nil
                continue
            end

            -- If there is no obstruction they are clear and can be done wallwalking
            if CurTime() > wallwalking[ply].mintime and playerwillfit(ply) then
                ply:ResetHull()
                wallwalking[ply] = nil
                continue
            end

            -- Wallwalking info
            local targetpos = wallwalking[ply].pos
            local targetmax = wallwalking[ply].max

            -- If they're too far, try and assign them a new target
            local success = true
            if ply:GetPos():DistToSqr(targetpos) > targetmax then
                success = setnewtarget(ply)
            end

            -- Set their hull to the target position
            if success then
                drawnpos = wallwalking[ply].pos -- debug only
                local offset = wallwalking[ply].pos - ply:GetPos()
                offset = Vector(offset.x, offset.y, 0)
                ply:SetHull(offset + Vector(-1, -1, 0), offset + Vector(1, 1, 72))
                ply:SetHullDuck(offset + Vector(-1, -1, 0), offset + Vector(1, 1, 36))
            end
        -- The player is not wallwalking, but could potentially start
        elseif ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
            -- Gets the position ahead of the player
            local pos = ply:GetPos()
            local scale = ply:GetModelScale()
            local vel = ply:GetVelocity()
            vel = Vector(vel.x, vel.y, 0)
            vel:Normalize()
            pos = pos + vel * 32 * scale * wallwalking_min:GetFloat()

            -- If the player will fit here or a step above, they don't need to wallwalk
            if playerwillfit(ply, pos) or playerwillfit(ply, pos + Vector(0, 0, ply:GetStepSize())) then
                return
            end

            -- Initializes wallwalking
            setnewtarget(ply)
        end
    end
end)

-- Debug: Draws green wireframes for unobstructed hulls, red wireframes for obstructed hulls, and blue wireframes for the current target hull
if CLIENT then
    if false then -- Debug only
        local targets = {}
        hook.Add("PreDrawOpaqueRenderables", "test", function()
            local ply = LocalPlayer()
            local pos = ply:GetPos()
            local scale = ply:GetModelScale()
            local vel = ply:GetVelocity()
            vel = Vector(vel.x, vel.y, 0)
            vel:Normalize()
            pos = pos + vel * 32 * scale

            local ang = Angle(0,0,0)
            local min = Vector(-16,-16,0) * scale
            local max = Vector(16,16,ply:Crouching() and 36 or 72) * scale
            local red = Color(255,0,0)
            local grn = Color(0,255,0)
            local blu = Color(0,0,255)
            --render.DrawWireframeBox(pos, ang, min, max, playerwillfit(ply, pos) and grn or red, false)
            --render.DrawWireframeBox(pos + Vector(0, 0, ply:GetStepSize()), ang, min, max, playerwillfit(ply, pos + Vector(0, 0, ply:GetStepSize())) and grn or red, true)
            if wallwalking[ply] then
                render.DrawWireframeBox(drawnpos, ang, min, max, blu, false)
            end

            if vel ~= Vector(0, 0, 0) then
                targets = findtargets(ply, true)
            end
            
            for k, target in ipairs(targets) do
                render.DrawWireframeBox(target.Pos, ang, min, max, target.Fit and grn or red, false)
            end
        end)
    else
        hook.Remove("PreDrawOpaqueRenderables", "test")
    end
end