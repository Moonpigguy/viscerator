-- make heli functional and add AI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local heli = game:GetService("Workspace").Manhack
heli:SetNetworkOwner(nil)
local engine = heli
local heliForce = Instance.new("BodyForce")
heliForce.Parent = heli
local heliTorque = Instance.new("BodyGyro")
heliTorque.Parent = heli
heliTorque.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
heliTorque.P = 4000
local gravity = workspace.Gravity

local FIRING = false

local mainThrottle = 1
local throttleStrength = 1
local dragCoefficient = 1
local tiltMultiplier = 5
local maxPitch = -40 -- degrees
local maxRoll = -10 -- degrees
local velocityLimit = 10 -- m/s
local velocityDistance = 10000
local maxDistance = 100
local slowDownHeight = 20
local hoverDistance = 70

local paths = {}

local lastMagnitude = 0
local mass = 50.354

local grindSounds = {"rbxassetid://11235822168", "rbxassetid://11235822778", "rbxassetid://11235819921", "rbxassetid://11235820618", "rbxassetid://11235821550"}



local function doPhysics()
    local mainVelocity = engine.Velocity
    local weight = mass * gravity
    local engineCFrame = engine.CFrame
    if mainVelocity.Z == 0 then
		mainVelocity = Vector3.new(mainVelocity.X,mainVelocity.Y,0.0001)
	end
	if mainVelocity.Y == 0 then
		mainVelocity = Vector3.new(mainVelocity.X,0.0001,mainVelocity.Z)
	end
	if mainVelocity.X == 0 then
        mainVelocity = Vector3.new(0.0001,mainVelocity.Y,mainVelocity.Z)
	end
	local relativeGravity = engineCFrame:VectorToWorldSpace(Vector3.new(0, weight, 0))
	local gravityToWorld = relativeGravity:Dot(Vector3.new(0, 1, 0)) * Vector3.new(0, 1, 0)
	local totalForcePower = engineCFrame:VectorToWorldSpace(Vector3.new(0, mainThrottle * throttleStrength, 0))
	heliForce.Force = totalForcePower + (gravityToWorld + (relativeGravity - gravityToWorld) * tiltMultiplier) + -mainVelocity.Unit * mainVelocity.Magnitude * mainVelocity.Magnitude * 0.5 * dragCoefficient
end


local function flyToCFrame(cframe)
    -- use dot and cross to yaw towards cframe
    local engineCFrame = engine.CFrame
    local engineVector = engineCFrame.LookVector
    local targetVector = (cframe.Position - engineCFrame.Position)
    
    -- set desiredPitch to the angle needed to face the target
    
    local desiredPitch = -15



    



    -- make desiredPitch less the closer the helicopter is to the target
    local distance = (cframe.Position - engineCFrame.Position).Magnitude
    local velocity = engine.Velocity
    local velocityMagnitude = velocity.Magnitude
    if distance < maxDistance then
        desiredPitch = desiredPitch * (distance / maxDistance)
    end
    if velocityMagnitude > velocityLimit then
        desiredPitch = desiredPitch * (velocityLimit / velocityMagnitude)
    end

    

    -- roll towards the target
    local desiredRoll = 0
    local cross = engineVector:Cross(targetVector)
    if cross.Y > 0 then
        desiredRoll = -maxRoll
    elseif cross.Y < 0 then
        desiredRoll = maxRoll
    end
    -- roll less the closer the helicopter is to the target
    if distance < maxDistance then
        desiredRoll = desiredRoll * (distance / maxDistance)
    end
    -- roll less the faster the helicopter is going
    if velocityMagnitude > velocityLimit then
        desiredRoll = desiredRoll * (velocityLimit / velocityMagnitude)
    end
    -- set the BodyGyro
    
    heliTorque.CFrame = CFrame.new(engineCFrame.Position, Vector3.new(cframe.Position.X, engineCFrame.Position.Y, cframe.Position.Z)) * CFrame.Angles(math.rad(desiredPitch), 0, math.rad(desiredRoll))

    -- get distance between current position and cframe
    local distance = (engine.Position - cframe.p).magnitude
    -- get horizontal distance between current position and cframe
    local horizontalDistance = (Vector3.new(engine.Position.X, 0, engine.Position.Z) - Vector3.new(cframe.p.X, 0, cframe.p.Z)).magnitude
    local verticalDistance = engine.Position.Y - cframe.p.Y
    if horizontalDistance ~= horizontalDistance then
        horizontalDistance = 1
    end
    -- if helicopter is below cframe, fly up and compensate for gravity
    throttleStrength = -4000 * math.atan2((engine.Position.Y - cframe.p.Y), 50)
    -- if helicopter is approaching target above speed limit, slow down using vertical velocity
    -- decelerate object before it reaches target so it stops perfectly using force
    local decel = 0
    if verticalDistance < 10 then
        decel = (0 - engine.Velocity.Y) / (verticalDistance / engine.Velocity.Y)
    end
    local appliedForce = decel * mass
    if appliedForce > 0 then
        throttleStrength = throttleStrength - appliedForce
    end
    -- if helicopter is too close to the ground, fly up
    local ray = Ray.new(engine.Position, Vector3.new(0, -4, 0))
    local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {engine, workspace.TARGET})
    if engine.Position.Y < 4 then -- lerp velocity up to 0 if helicopter is too close to the ground
        engine.Velocity = engine.Velocity:Lerp(Vector3.new(engine.Velocity, 10, engine.Velocity), 0.05)
    end

    -- the closer the helicopter is vertically to the target, lower the throttle
    if throttleStrength ~= throttleStrength then
        throttleStrength = heliForce.Force.Y - mass * gravity
    end
end

local function getClosestCharacter(maxDistance)
    local closestCharacter = nil
    local closestDistance = maxDistance
    for _,v in pairs(game.Players:GetPlayers()) do
        if v.Character and v.Character:FindFirstChild("Humanoid") and v.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (v.Character.HumanoidRootPart.Position - engine.Position).Magnitude
            if distance < closestDistance then
                closestCharacter = v.Character
                closestDistance = distance
            end
        end
    end
    return closestCharacter
end

local function playGrindSound()
    local sound = Instance.new("Sound")
    sound.SoundId = grindSounds[math.random(1, #grindSounds)]
    sound.Volume = 1
    sound.Pitch = 1
    sound.Parent = engine
    sound:Play()
    sound.Ended:Connect(function()
        task.wait(5)
        sound:Destroy()
    end)
end

local function getClosestPath()
    local closestPath = nil
    local closestDistance = math.huge

    for _,v in pairs(paths) do
        local distance = (v - engine.Position).Magnitude
        if distance < closestDistance then
            closestPath = v
            closestDistance = distance
        end
    end
    return closestPath
end

-- check around the path to see if the helicopter will fit


local currentCFrame = nil
local heliSize = 1
local nodeDistance = 1
local currentPaths = {}
local function updatePaths()
    for _,v in pairs(currentPaths) do
        v:Destroy()
    end
    currentPaths = {}
    for i = 1, #paths do
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 0
        part.CFrame = CFrame.new(paths[i])
        part.Parent = workspace
        table.insert(currentPaths, part)
    end
end

local function raycastAround(position) -- raycast multiple times in a sphere shape to see if there is anything near the position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {engine, workspace.TARGET}
    local hitTargets = {}
    for i = 1, 360, 10 do
        local ray = Ray.new(position, Vector3.new(math.cos(math.rad(i)) * nodeDistance, 0, math.sin(math.rad(i)) * nodeDistance))
        local part, pos = workspace:FindPartOnRayWithIgnoreList(ray, {workspace.TARGET})
        if part then
            table.insert(hitTargets, pos)
        end
    end
    -- do same vertically
    --[[for i = 1, 360, 10 do
        local ray = Ray.new(position, Vector3.new(0, math.cos(math.rad(i)) * nodeDistance, math.sin(math.rad(i)) * nodeDistance))
        local part, pos = workspace:FindPartOnRayWithIgnoreList(ray, {workspace.TARGET})
        if part then
            table.insert(hitTargets, pos)
        end
    end]]
    return hitTargets
end
    

game:GetService("RunService").Heartbeat:Connect(function()
    -- follow path
    updatePaths()
    
    -- if player is in sight of helicopter using raycasting, fly to them
    local ray = Ray.new(engine.Position, (workspace.TARGET.Position - engine.Position).Unit * 1000)
    local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {engine})
    local closestPath = getClosestPath()
    if closestPath and (closestPath - engine.Position).Magnitude < 30 then
        currentCFrame = CFrame.new(closestPath+Vector3.new(0,2,0))
    end
    for i, path in pairs(paths) do
        -- if path is too close to a wall, space it out
        
        -- if path is too close to a wall, space it out

        -- check if velocity is towards the path
        local velocity = engine.Velocity
        local velocityUnit = velocity.Unit
        local pathUnit = (path - engine.Position).Unit
        local dot = velocityUnit:Dot(pathUnit)
        if (engine.Position - path).Magnitude < 4.5 then --and not (dot < 0) then
            table.remove(paths, i)
            print("removed path")
        end
    end
    if part and part == workspace.TARGET then
        --currentCFrame = CFrame.new(workspace.TARGET.Position)
        --print("target in sight")
    end
    if currentCFrame then
        flyToCFrame(currentCFrame)
    end
    doPhysics()
    local closestCharacter2 = getClosestCharacter(math.huge)
    if closestCharacter2 then
        workspace.TARGET.CFrame = CFrame.new(closestCharacter2.HumanoidRootPart.Position, closestCharacter2.HumanoidRootPart.Position + Vector3.new(0, 1, 0))
    end
    -- if helicopter is near a wall then bounce off it
    local ray = Ray.new(engine.Position, engine.Velocity.Unit * 2)
    local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {engine, heliTorque, heliForce})
    --[[if part then
        playGrindSound()
        local velocity = engine.Velocity
        local newVelocity = -velocity * 0.7
        engine.Velocity = newVelocity
        if part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then
            part.Parent.Humanoid:TakeDamage(10)
        end
    end]]
end)

local pathfindingSize = 4
local YSize = 4
local YOffset = 0
local function pathfind()
    local path = {}
    local start = Vector3.new(math.floor(engine.Position.X / pathfindingSize) * pathfindingSize, math.floor((engine.Position.Y + YOffset) / YSize) * YSize, math.floor(engine.Position.Z / pathfindingSize) * pathfindingSize)
    local goal = Vector3.new(math.floor(workspace.TARGET.Position.X / pathfindingSize) * pathfindingSize, math.floor(workspace.TARGET.Position.Y / YSize) * YSize, math.floor(workspace.TARGET.Position.Z / pathfindingSize) * pathfindingSize)
    local openList = {}
    local closedList = {}
    local startNode = {
        position = start,
        g = 0,
        h = (goal - start).Magnitude,
        f = (goal - start).Magnitude,
        parent = nil
    }
    table.insert(openList, startNode)
    local iterations = 0
    while #openList > 0 and iterations < 1000 do
        iterations = iterations + 1
        local currentNode = openList[1]
        local currentIndex = 1
        for i,v in pairs(openList) do
            if v.f < currentNode.f then
                currentNode = v
                currentIndex = i
            end
        end
        table.remove(openList, currentIndex)
        table.insert(closedList, currentNode)
        if currentNode.position == goal then
            local currentPathNode = currentNode
            while currentPathNode do
                table.insert(path, 1, currentPathNode.position)
                currentPathNode = currentPathNode.parent
            end
            break
        end
        local adjacentNodes = {}
        for i = -1, 1 do
            for j = -1, 1 do
                for k = -1, 1 do
                    local position = currentNode.position + Vector3.new(i * pathfindingSize, j * YSize, k * pathfindingSize)
                    local ray = Ray.new(currentNode.position, position - currentNode.position)
                    local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {engine, heliTorque, heliForce})
                    -- make sure 
                    if not part then
                        local node = {
                            position = position,
                            g = currentNode.g + (position - currentNode.position).Magnitude,
                            h = (goal - position).Magnitude,
                            f = currentNode.g + (position - currentNode.position).Magnitude + (goal - position).Magnitude,
                            parent = currentNode
                        }
                        table.insert(adjacentNodes, node)
                    end
                end
            end
        end
        for i,v in pairs(adjacentNodes) do
            local inClosedList = false
            for j,w in pairs(closedList) do
                if v.position == w.position then
                    inClosedList = true
                    break
                end
            end
            if not inClosedList then
                local inOpenList = false
                for j,w in pairs(openList) do
                    if v.position == w.position then
                        inOpenList = true
                        if v.g < w.g then
                            w.g = v.g
                            w.f = v.f
                            w.parent = v.parent
                        end
                        break
                    end
                end
                if not inOpenList then
                    table.insert(openList, v)
                end
            end
        end
    end
    return path
end

local function updatePaths()
    local path = pathfind()
    
    if #path > 0 then
        for i, p in pairs(path) do
            local hitTargets = raycastAround(p)
            if #hitTargets > 0 then
                local average = Vector3.new(0, 0, 0)
                for _,v in pairs(hitTargets) do
                    average = average + v
                end
                average = average / #hitTargets
                path[i] = average * 1.5
            end
        end
        paths = path
        print("found path")
    end
end

ReplicatedStorage:WaitForChild("Pathfind").OnServerEvent:Connect(function()
    updatePaths()
end)

ReplicatedStorage:WaitForChild("Move").OnServerEvent:Connect(function(player, position)
    engine.Position = position
end)