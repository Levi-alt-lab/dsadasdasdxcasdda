    local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

    local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()

    local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()



    local Window = Fluent:CreateWindow({

        Title = "Mrise Hub X (Beta)",

        SubTitle = "by Mrise",

        TabWidth = 160,

        Size = UDim2.fromOffset(580, 460),

        Acrylic = false, -- The blur may be detectable, setting this to false disables blur entirely

        Theme = "Amethyst",

        MinimizeKey = Enum.KeyCode.LeftControl -- Used when theres no MinimizeKeybind

    })



    --Fluent provides Lucide Icons https://lucide.dev/icons/ for the tabs, icons are optional

    local Tabs = {

        Main = Window:AddTab({ Title = "Main", Icon = "code" }),

        Blatant = Window:AddTab({ Title = "Blatant", Icon = "swords" }),

        Skin = Window:AddTab({ Title = "Skin", Icon = "sword" }),

        Emote = Window:AddTab({ Title = "Emote", Icon = "smile-plus" }),

        Sky = Window:AddTab({ Title = "Sky", Icon = "cloudy" }),

        Ball = Window:AddTab({ Title = "Ball", Icon = "circle" }),

        Player = Window:AddTab({ Title = "Player", Icon = "user" }),

        Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-bag" }),

        Others = Window:AddTab({ Title = "Others", Icon = "cpu" }),

        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),

        BugsReports = Window:AddTab({ Title = "Bugs & Reports", Icon = "bug" })

    }



    local Options = Fluent.Options



    -- ==================== SKIN CHANGER FUNCTIONALITY ====================

    -- Initialize globals
    getgenv().skinChanger = getgenv().skinChanger or false
    getgenv().swordModel = getgenv().swordModel or ""
    getgenv().swordAnimations = getgenv().swordAnimations or ""
    getgenv().swordFX = getgenv().swordFX or ""

    local plrs = game:GetService("Players")
    local plr = plrs.LocalPlayer
    local rs = game:GetService("ReplicatedStorage")

    -- Get sword instances
    local swordInstancesInstance = rs:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9)
    local swordInstances = require(swordInstancesInstance)

    -- Get swords controller
    local swordsController
    task.spawn(function()
        while task.wait() and not swordsController do
            for i, v in getconnections(rs.Remotes.FireSwordInfo.OnClientEvent) do
                if v.Function and islclosure(v.Function) then
                    local upvalues = getupvalues(v.Function)
                    if #upvalues == 1 and type(upvalues[1]) == "table" then
                        swordsController = upvalues[1]
                        break
                    end
                end
            end
        end
    end)

    function getSlashName(swordName)
        local slashName = swordInstances:GetSword(swordName)
        return (slashName and slashName.SlashName) or "SlashEffect"
    end

    function setSword()
        if not getgenv().skinChanger then
            return
        end
        if not plr.Character then
            return
        end
        -- Only disable boolean validation flags; do not clobber service upvalues like Players
        pcall(function()
            local f = rawget(swordInstances, "EquipSwordTo")
            if type(f) == "function" then
                local ups = getupvalues(f)
                for i = 1, #ups do
                    if type(ups[i]) == "boolean" then
                        setupvalue(f, i, false)
                        break
                    end
                end
            end
        end)
        pcall(function()
            swordInstances:EquipSwordTo(plr.Character, getgenv().swordModel)
        end)
        pcall(function()
            if swordsController and swordsController.SetSword then
                swordsController:SetSword(getgenv().swordAnimations)
            end
        end)
    end

    -- Hook parry success
    local playParryFunc
    local parrySuccessAllConnection
    task.spawn(function()
        while task.wait() and not parrySuccessAllConnection do
            for i, v in getconnections(rs.Remotes.ParrySuccessAll.OnClientEvent) do
                if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
                    parrySuccessAllConnection = v
                    playParryFunc = v.Function
                    v:Disable()
                end
            end
        end
    end)

    getgenv().slashName = getgenv().swordFX ~= "" and getSlashName(getgenv().swordFX) or "SlashEffect"

    rs.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
        setthreadidentity(2)
        local args = { ... }
        if tostring(args[4]) == plr.Name and getgenv().skinChanger then
            args[1] = getgenv().slashName
            args[3] = getgenv().swordFX
        end
        return playParryFunc and playParryFunc(unpack(args))
    end)

    getgenv().updateSword = function()
        if getgenv().swordFX ~= "" then
            getgenv().slashName = getSlashName(getgenv().swordFX)
        end
        setSword()
    end

    -- Watchdog to keep sword equipped
    task.spawn(function()
        while task.wait(1) do
            if getgenv().skinChanger and getgenv().swordModel ~= "" then
                local char = plr.Character
                if char then
                    if plr:GetAttribute("CurrentlyEquippedSword") ~= getgenv().swordModel then
                        setSword()
                    end
                    if not char:FindFirstChild(getgenv().swordModel) then
                        setSword()
                    end
                    for _, v in char:GetChildren() do
                        if v:IsA("Model") and v.Name ~= getgenv().swordModel then
                            v:Destroy()
                        end
                        task.wait()
                    end
                end
            end
        end
    end)

    -- ==================== END SKIN CHANGER FUNCTIONALITY ====================



    -- ==================== ESP FUNCTIONALITY ====================

    local RunService = game:GetService("RunService")
    local Camera = workspace.CurrentCamera

    -- Initialize ESP globals
    getgenv().espEnabled = getgenv().espEnabled or false
    getgenv().espTracers = getgenv().espTracers or false
    getgenv().espNames = getgenv().espNames or false
    getgenv().espBoxes = getgenv().espBoxes or false

    local espObjects = {}

    -- Function to create ESP components for a player
    local function createESP(player)
        if player == plr then return end
        if espObjects[player] then return end

        local esp = {
            box = nil,
            name = nil,
            tracer = nil
        }

        -- Create Box
        if getgenv().espBoxes then
            esp.box = Drawing.new("Square")
            esp.box.Visible = false
            esp.box.Color = Color3.fromRGB(255, 255, 255)
            esp.box.Thickness = 2
            esp.box.Transparency = 1
            esp.box.Filled = false
        end

        -- Create Name
        if getgenv().espNames then
            esp.name = Drawing.new("Text")
            esp.name.Visible = false
            esp.name.Color = Color3.fromRGB(255, 255, 255)
            esp.name.Size = 14
            esp.name.Center = true
            esp.name.Outline = true
            esp.name.OutlineColor = Color3.fromRGB(0, 0, 0)
            esp.name.Text = player.Name
        end

        -- Create Tracer
        if getgenv().espTracers then
            esp.tracer = Drawing.new("Line")
            esp.tracer.Visible = false
            esp.tracer.Color = Color3.fromRGB(255, 255, 255)
            esp.tracer.Thickness = 1
            esp.tracer.Transparency = 1
        end

        espObjects[player] = esp
    end

    -- Function to remove ESP components for a player
    local function removeESP(player)
        if espObjects[player] then
            if espObjects[player].box then
                espObjects[player].box:Remove()
            end
            if espObjects[player].name then
                espObjects[player].name:Remove()
            end
            if espObjects[player].tracer then
                espObjects[player].tracer:Remove()
            end
            espObjects[player] = nil
        end
    end

    -- Function to get character bounding box
    local function getBoundingBox(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            return nil, nil, nil, nil, nil
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        if not hrp or not humanoid then
            return nil, nil, nil, nil, nil
        end

        local size = hrp.Size
        local cf = hrp.CFrame
        
        local corners = {
            Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
            Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
            Vector3.new(size.X/2, size.Y/2, -size.Z/2),
            Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
            Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
            Vector3.new(size.X/2, -size.Y/2, size.Z/2),
            Vector3.new(size.X/2, size.Y/2, size.Z/2),
            Vector3.new(-size.X/2, size.Y/2, size.Z/2)
        }

        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        local hasVisible = false

        for _, corner in ipairs(corners) do
            local worldPos = (cf * CFrame.new(corner)).Position
            local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPos)
            if onScreen then
                hasVisible = true
                minX = math.min(minX, screenPoint.X)
                maxX = math.max(maxX, screenPoint.X)
                minY = math.min(minY, screenPoint.Y)
                maxY = math.max(maxY, screenPoint.Y)
            end
        end

        if not hasVisible or minX == math.huge then
            return nil, nil, nil, nil, nil
        end

        return minX, maxX, minY, maxY, hrp.Position
    end

    -- Main ESP update loop
    local espConnection
    local function updateESP()
        if not getgenv().espEnabled then
            for player, esp in pairs(espObjects) do
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.tracer then esp.tracer.Visible = false end
            end
            return
        end

        for player, esp in pairs(espObjects) do
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local minX, maxX, minY, maxY, worldPos = getBoundingBox(character)
                
                if minX and Camera then
                    local screenPoint, onScreen = Camera:WorldToViewportPoint(worldPos)
                    
                    if onScreen then
                        -- Update Box
                        if esp.box and getgenv().espBoxes then
                            esp.box.Visible = true
                            esp.box.Size = Vector2.new(maxX - minX, maxY - minY)
                            esp.box.Position = Vector2.new(minX, minY)
                        else
                            if esp.box then esp.box.Visible = false end
                        end

                        -- Update Name
                        if esp.name and getgenv().espNames then
                            esp.name.Visible = true
                            esp.name.Position = Vector2.new((minX + maxX) / 2, minY - 20)
                        else
                            if esp.name then esp.name.Visible = false end
                        end

                        -- Update Tracer
                        if esp.tracer and getgenv().espTracers then
                            esp.tracer.Visible = true
                            esp.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            esp.tracer.To = Vector2.new((minX + maxX) / 2, maxY)
                        else
                            if esp.tracer then esp.tracer.Visible = false end
                        end
                    else
                        if esp.box then esp.box.Visible = false end
                        if esp.name then esp.name.Visible = false end
                        if esp.tracer then esp.tracer.Visible = false end
                    end
                else
                    if esp.box then esp.box.Visible = false end
                    if esp.name then esp.name.Visible = false end
                    if esp.tracer then esp.tracer.Visible = false end
                end
            else
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.tracer then esp.tracer.Visible = false end
            end
        end
    end

    -- Initialize ESP for existing players
    for _, player in ipairs(plrs:GetPlayers()) do
        createESP(player)
    end

    -- Handle new players
    plrs.PlayerAdded:Connect(function(player)
        createESP(player)
    end)

    -- Handle player leaving
    plrs.PlayerRemoving:Connect(function(player)
        removeESP(player)
    end)

    -- ESP update loop (using Heartbeat instead of RenderStepped for better performance)
    local espUpdateCounter = 0
    espConnection = RunService.Heartbeat:Connect(function()
        espUpdateCounter = espUpdateCounter + 1
        -- Update ESP every 2 frames instead of every frame for better performance
        if espUpdateCounter % 2 == 0 then
            if getgenv().espEnabled then
                updateESP()
            end
        end
    end)

    -- Function to toggle ESP components
    getgenv().updateESP = function()
        if not getgenv().espEnabled then
            for player, esp in pairs(espObjects) do
                if esp.box then esp.box.Visible = false end
                if esp.name then esp.name.Visible = false end
                if esp.tracer then esp.tracer.Visible = false end
            end
        else
            -- Recreate ESP objects if needed
            for player, esp in pairs(espObjects) do
                if getgenv().espBoxes and not esp.box then
                    esp.box = Drawing.new("Square")
                    esp.box.Visible = false
                    esp.box.Color = Color3.fromRGB(255, 255, 255)
                    esp.box.Thickness = 2
                    esp.box.Transparency = 1
                    esp.box.Filled = false
                elseif not getgenv().espBoxes and esp.box then
                    esp.box:Remove()
                    esp.box = nil
                end

                if getgenv().espNames and not esp.name then
                    esp.name = Drawing.new("Text")
                    esp.name.Visible = false
                    esp.name.Color = Color3.fromRGB(255, 255, 255)
                    esp.name.Size = 14
                    esp.name.Center = true
                    esp.name.Outline = true
                    esp.name.OutlineColor = Color3.fromRGB(0, 0, 0)
                    esp.name.Text = player.Name
                elseif not getgenv().espNames and esp.name then
                    esp.name:Remove()
                    esp.name = nil
                end

                if getgenv().espTracers and not esp.tracer then
                    esp.tracer = Drawing.new("Line")
                    esp.tracer.Visible = false
                    esp.tracer.Color = Color3.fromRGB(255, 255, 255)
                    esp.tracer.Thickness = 1
                    esp.tracer.Transparency = 1
                elseif not getgenv().espTracers and esp.tracer then
                    esp.tracer:Remove()
                    esp.tracer = nil
                end
            end
        end
    end

    -- ==================== END ESP FUNCTIONALITY ====================



    -- ==================== AUTO PARRY FUNCTIONALITY ====================

    -- Initialize Auto Parry globals
    getgenv().autoparry = getgenv().autoparry or false
    getgenv().parryAccuracy = getgenv().parryAccuracy or 0.55
    getgenv().parryType = getgenv().parryType or "Camera"
    getgenv().randomAccuracy = getgenv().randomAccuracy or false
    getgenv().randomAccuracyMin = getgenv().randomAccuracyMin or 0.3
    getgenv().randomAccuracyMax = getgenv().randomAccuracyMax or 0.8
    getgenv().autoSpam = getgenv().autoSpam or false
    getgenv().autoSpamKey = getgenv().autoSpamKey or Enum.KeyCode.E
    getgenv().lobbyAutoParry = getgenv().lobbyAutoParry or false
    getgenv().lobbyParryAccuracy = getgenv().lobbyParryAccuracy or 100
    getgenv().lobbyRandomAccuracy = getgenv().lobbyRandomAccuracy or false
    getgenv().lobbyParryKeypress = getgenv().lobbyParryKeypress or false

    local VirtualManager = 

    game:GetService("VirtualInputManager")

    local Stats = game:GetService('Stats')

    local Players = game:GetService('Players')

    local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()

    local RunService = game:GetService('RunService')
    local UserInputService = game:GetService('UserInputService')

    local parry_helper = loadstring(game:HttpGet("https://raw.githubusercontent.com/TripleScript/TripleHub/main/helper_.lua"))()

    local ero = false

    local autoParryConnection = nil

    -- Parry Type function to get camera direction
    local function getParryDirection(parryType)
        local Camera = workspace.CurrentCamera
        if not Camera or not Player.Character or not Player.Character.PrimaryPart then
            return nil
        end

        if parryType == "Camera" then
            return Camera.CFrame
        elseif parryType == "Backwards" then
            local Backwards_Direction = Camera.CFrame.LookVector * -10000
            Backwards_Direction = Vector3.new(Backwards_Direction.X, 0, Backwards_Direction.Z)
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Backwards_Direction)
        elseif parryType == "Straight" then
            local Aimed_Player = nil
            local Closest_Distance = math.huge
            for _, v in pairs(workspace.Alive:GetChildren()) do
                if v ~= Player.Character and v:FindFirstChild("PrimaryPart") then
                    local worldPos = v.PrimaryPart.Position
                    local screenPos, isOnScreen = Camera:WorldToScreenPoint(worldPos)
                    if isOnScreen then
                        local distance = (Player.Character.PrimaryPart.Position - worldPos).Magnitude
                        if distance < Closest_Distance then
                            Closest_Distance = distance
                            Aimed_Player = v
                        end
                    end
                end
            end
            if Aimed_Player then
                return CFrame.new(Player.Character.PrimaryPart.Position, Aimed_Player.PrimaryPart.Position)
            end
        elseif parryType == "Random" then
            return CFrame.new(
                Camera.CFrame.Position,
                Vector3.new(math.random(-4000, 4000), math.random(-4000, 4000), math.random(-4000, 4000))
            )
        elseif parryType == "High" then
            local High_Direction = Camera.CFrame.UpVector * 10000
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + High_Direction)
        elseif parryType == "Slowball" then
            local Slowball_Direction = Vector3.new(0, -1, 0) * 99999
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Slowball_Direction)
        elseif parryType == "Fastball" then
            local Fastball_Direction = Camera.CFrame.LookVector * 10 + Vector3.new(0, 7, 0)
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Fastball_Direction)
        elseif parryType == "Left" then
            local Left_Direction = Camera.CFrame.RightVector * 10000
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position - Left_Direction)
        elseif parryType == "Right" then
            local Right_Direction = Camera.CFrame.RightVector * 10000
            return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Right_Direction)
        elseif parryType == "RandomTarget" then
            local candidates = {}
            for _, v in pairs(workspace.Alive:GetChildren()) do
                if v ~= Player.Character and v:FindFirstChild("PrimaryPart") then
                    local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.PrimaryPart.Position)
                    if isOnScreen then
                        table.insert(candidates, v)
                    end
                end
            end
            if #candidates > 0 then
                local pick = candidates[math.random(1, #candidates)]
                return CFrame.new(Player.Character.PrimaryPart.Position, pick.PrimaryPart.Position)
            end
        end
        return Camera.CFrame
    end

    -- ==================== CURVE DETECTION FUNCTIONALITY ====================

    -- Helper function for linear interpolation
    local function linearInterpolation(a, b, time_volume)
        return a + (b - a) * time_volume
    end

    -- Curve detection variables
    local lerpRadians = 0
    local lastWarping = tick()
    local previousVelocity = {}
    local curving = tick()
    local tornadoTime = tick()
    local Debris = game:GetService("Debris")

    -- Reset curve detection variables when balls change
    workspace.Balls.ChildAdded:Connect(function()
        curving = tick()
        previousVelocity = {}
        lerpRadians = 0
    end)

    -- Function to get ball
    local function getBall()
        for _, instance in pairs(workspace.Balls:GetChildren()) do
            if instance:GetAttribute("realBall") then
                instance.CanCollide = false
                return instance
            end
        end
        return nil
    end

    -- Function to check if ball is curved
    local function isCurved()
        local ball = getBall()
        if not ball then
            return false
        end

        local zoomies = ball:FindFirstChild("zoomies")
        if not zoomies then
            return false
        end

        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        local velocity = zoomies.VectorVelocity
        local ballDirection = velocity.Unit
        local playerPos = Player.Character.PrimaryPart.Position
        local ballPos = ball.Position
        local direction = (playerPos - ballPos).Unit
        local dot = direction:Dot(ballDirection)
        local speed = velocity.Magnitude
        local speedThreshold = math.min(speed / 100, 40)
        local angleThreshold = 40 * math.max(dot, 0)
        local distance = (playerPos - ballPos).Magnitude
        local reachTime = distance / speed - (ping / 1000)
        local ballDistanceThreshold = 15 - math.min(distance / 1000, 15) + speedThreshold

        table.insert(previousVelocity, velocity)
        if #previousVelocity > 4 then
            table.remove(previousVelocity, 1)
        end

        if ball:FindFirstChild("AeroDynamicSlashVFX") then
            Debris:AddItem(ball.AeroDynamicSlashVFX, 0)
            tornadoTime = tick()
        end

        local runtime = workspace:FindFirstChild("Runtime")
        if runtime and runtime:FindFirstChild("Tornado") then
            if (tick() - tornadoTime) < ((runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
                return true
            end
        end

        local enoughSpeed = speed > 160
        if enoughSpeed and reachTime > (ping / 10 + 0.03) then
            if speed < 300 then
                ballDistanceThreshold = math.max(ballDistanceThreshold - 15, 15)
            elseif speed <= 600 then
                ballDistanceThreshold = math.max(ballDistanceThreshold - 17, 17)
            elseif speed <= 1000 then
                ballDistanceThreshold = math.max(ballDistanceThreshold - 19, 19)
            else
                ballDistanceThreshold = math.max(ballDistanceThreshold - 20, 20)
            end
        end

        if distance < ballDistanceThreshold then
            return false
        end

        local adjustedReachTime = reachTime + 0.03
        if speed < 300 then
            if (tick() - curving) < (adjustedReachTime / 1.2) then
                return true
            end
        elseif speed < 450 then
            if (tick() - curving) < (adjustedReachTime / 1.21) then
                return true
            end
        elseif speed < 600 then
            if (tick() - curving) < (adjustedReachTime / 1.335) then
                return true
            end
        else
            if (tick() - curving) < (adjustedReachTime / 1.5) then
                return true
            end
        end

        local dotThreshold = (0 - ping / 1000)
        local directionDifference = (ballDirection - velocity.Unit)
        local directionSimilarity = direction:Dot(directionDifference.Unit)
        local dotDifference = dot - directionSimilarity

        if dotDifference < dotThreshold then
            return true
        end

        local clampedDot = math.clamp(dot, -1, 1)
        local radians = math.deg(math.asin(clampedDot))
        lerpRadians = linearInterpolation(lerpRadians, radians, 0.8)

        if speed < 300 then
            if lerpRadians < 0.02 then
                lastWarping = tick()
            end
            if (tick() - lastWarping) < (adjustedReachTime / 1.19) then
                return true
            end
        else
            if lerpRadians < 0.018 then
                lastWarping = tick()
            end
            if (tick() - lastWarping) < (adjustedReachTime / 1.5) then
                return true
            end
        end

        if #previousVelocity == 4 then
            for i = 1, 2 do
                local prevDir = (ballDirection - previousVelocity[i].Unit).Unit
                local prevDot = direction:Dot(prevDir)
                if (dot - prevDot) < dotThreshold then
                    return true
                end
            end
        end

        local backwardsCurveDetected = false
        local backwardsAngleThreshold = 60
        local horizDirection = Vector3.new(playerPos.X - ballPos.X, 0, playerPos.Z - ballPos.Z)
        if horizDirection.Magnitude > 0 then
            horizDirection = horizDirection.Unit
        end
        local awayFromPlayer = -horizDirection
        local horizBallDir = Vector3.new(ballDirection.X, 0, ballDirection.Z)
        if horizBallDir.Magnitude > 0 then
            horizBallDir = horizBallDir.Unit
            local backwardsAngle = math.deg(math.acos(math.clamp(awayFromPlayer:Dot(horizBallDir), -1, 1)))
            if backwardsAngle < backwardsAngleThreshold then
                backwardsCurveDetected = true
            end
        end

        return (dot < dotThreshold) or backwardsCurveDetected
    end

    -- ==================== END CURVE DETECTION FUNCTIONALITY ====================

    -- Function to update auto parry
    getgenv().updateAutoParry = function()
        if autoParryConnection then
            autoParryConnection:Disconnect()
            autoParryConnection = nil
        end

        if not getgenv().autoparry then
            return
        end

        task.spawn(function()
            local parryUpdateCounter = 0
            autoParryConnection = RunService.Heartbeat:Connect(function()
                parryUpdateCounter = parryUpdateCounter + 1
                -- Update every 2 frames for better performance
                if parryUpdateCounter % 2 ~= 0 then
                    return
                end
                
                if not getgenv().autoparry then 
                    return 
                end

                local par = parry_helper.FindTargetBall()

                if not par then 
                    return 
                end

                local hat = par.AssemblyLinearVelocity

                if par:FindFirstChild('zoomies') then 
                    hat = par.zoomies.VectorVelocity
                end

                local i = par.Position

                local j = Player.Character.PrimaryPart.Position

                local kil = (j - i).Unit

                local l = Player:DistanceFromCharacter(i)

                local m = kil:Dot(hat.Unit)

                local n = hat.Magnitude

                if m > 0 then

                    local o = l - 5

                    local p = o / n

                    -- Get accuracy value (random or fixed)
                    local currentAccuracy = getgenv().parryAccuracy
                    if getgenv().randomAccuracy then
                        local minAccuracy = 0.3
                        local maxAccuracy = 0.8
                        currentAccuracy = math.random() * (maxAccuracy - minAccuracy) + minAccuracy
                        currentAccuracy = math.floor(currentAccuracy * 100) / 100 -- Round to 2 decimal places
                    end

                    -- Check for curve detection (always active when auto parry is enabled)
                    local curved = isCurved()
                    local isPlayerTarget = parry_helper.IsPlayerTarget(par)
                    
                    -- Skip parry if curve is detected and ball is targeting the player
                    if isPlayerTarget and curved then
                        return
                    end

                    if isPlayerTarget and p <= currentAccuracy and not ero then

                        -- Check for auto ability first
                        if getgenv().autoAbility and getgenv().AutoAbility then
                            local abilityActivated = getgenv().AutoAbility()
                            if abilityActivated then
                                ero = true
                                return
                            end
                        end

                        -- Apply parry type direction
                        local parryCFrame = getParryDirection(getgenv().parryType)
                        local Camera = workspace.CurrentCamera
                        if parryCFrame and Camera then
                            Camera.CFrame = parryCFrame
                        end

                        VirtualManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)

                        wait(0.01)

                        ero = true

                    end

                else

                    ero = false

                end

            end)
        end)
    end

    -- ==================== AUTO SPAM FUNCTIONALITY ====================

    local autoSpamConnection = nil
    local isSpamming = false
    local spamThread = nil

    -- Function to start spamming F key
    local function startSpamming()
        if isSpamming then
            return
        end
        isSpamming = true
        
        spamThread = task.spawn(function()
            while isSpamming and getgenv().autoSpam do
                VirtualManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.01)
                VirtualManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                task.wait(0.01)
            end
            isSpamming = false
        end)
    end

    -- Function to stop spamming
    local function stopSpamming()
        isSpamming = false
        if spamThread then
            task.cancel(spamThread)
            spamThread = nil
        end
    end

    -- Function to update auto spam
    getgenv().updateAutoSpam = function()
        if autoSpamConnection then
            autoSpamConnection:Disconnect()
            autoSpamConnection = nil
        end

        if not getgenv().autoSpam then
            stopSpamming()
            return
        end

        -- Listen for key press (toggle spam on/off)
        autoSpamConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end

            if input.KeyCode == getgenv().autoSpamKey then
                if getgenv().autoSpam then
                    if isSpamming then
                        stopSpamming()
                    else
                        startSpamming()
                    end
                end
            end
        end)
    end

    -- ==================== END AUTO SPAM FUNCTIONALITY ====================

    -- ==================== LOBBY AUTO PARRY FUNCTIONALITY ====================

    -- Lobby Auto Parry variables
    local lobbyAutoParryConnection = nil
    local trainingParried = false
    local lastBallTarget = nil
    local LobbyAP_Speed_Divisor_Multiplier = 1.1

    -- Function to get lobby ball
    local function getLobbyBall()
        local trainingBalls = workspace:FindFirstChild("TrainingBalls")
        if not trainingBalls then
            return nil
        end
        for _, instance in pairs(trainingBalls:GetChildren()) do
            if instance:GetAttribute("realBall") then
                return instance
            end
        end
        return nil
    end

    -- Function to update lobby auto parry
    getgenv().updateLobbyAutoParry = function()
        if lobbyAutoParryConnection then
            lobbyAutoParryConnection:Disconnect()
            lobbyAutoParryConnection = nil
        end

        if not getgenv().lobbyAutoParry then
            trainingParried = false
            lastBallTarget = nil
            return
        end

        -- Update speed divisor multiplier based on accuracy slider
        LobbyAP_Speed_Divisor_Multiplier = 0.7 + (getgenv().lobbyParryAccuracy - 1) * (0.35 / 99)

        task.spawn(function()
            local lobbyParryUpdateCounter = 0
            lobbyAutoParryConnection = RunService.Heartbeat:Connect(function()
                lobbyParryUpdateCounter = lobbyParryUpdateCounter + 1
                -- Update every 2 frames for better performance
                if lobbyParryUpdateCounter % 2 ~= 0 then
                    return
                end
                
                if not getgenv().lobbyAutoParry then
                    return
                end

                local ball = getLobbyBall()
                if not ball then
                    trainingParried = false
                    lastBallTarget = nil
                    return
                end

                local zoomies = ball:FindFirstChild("zoomies")
                if not zoomies then
                    return
                end

                local ballTarget = ball:GetAttribute("target")
                
                -- Reset training parried when target changes
                if ballTarget ~= lastBallTarget then
                    trainingParried = false
                    lastBallTarget = ballTarget
                end

                if trainingParried then
                    return
                end

                local velocity = zoomies.VectorVelocity
                local distance = Player:DistanceFromCharacter(ball.Position)
                local speed = velocity.Magnitude
                local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10

                -- Calculate parry accuracy
                local cappedSpeedDiff = math.min(math.max(speed - 9.5, 0), 650)
                local speedDivisorBase = 2.4 + cappedSpeedDiff * 0.002
                local effectiveMultiplier = LobbyAP_Speed_Divisor_Multiplier
                
                if getgenv().lobbyRandomAccuracy then
                    effectiveMultiplier = 0.7 + (math.random(1, 100) - 1) * (0.35 / 99)
                end
                
                local speedDivisor = speedDivisorBase * effectiveMultiplier
                local parryAccuracy = ping + math.max(speed / speedDivisor, 9.5)

                if ballTarget == tostring(Player) and distance <= parryAccuracy then
                    if getgenv().lobbyParryKeypress then
                        VirtualManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                        task.wait(0.01)
                        VirtualManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                    else
                        -- Use existing parry logic from auto parry
                        local parryCFrame = getParryDirection(getgenv().parryType)
                        local Camera = workspace.CurrentCamera
                        if parryCFrame and Camera then
                            Camera.CFrame = parryCFrame
                        end
                        VirtualManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                    end
                    trainingParried = true
                    
                    -- Reset training parried after 1 second
                    task.spawn(function()
                        local lastParry = tick()
                        repeat
                            RunService.PreSimulation:Wait()
                        until (tick() - lastParry) >= 1 or not trainingParried
                        trainingParried = false
                    end)
                end
            end)
        end)
    end

    -- ==================== END LOBBY AUTO PARRY FUNCTIONALITY ====================

    -- ==================== END AUTO PARRY FUNCTIONALITY ====================



    -- ==================== AUTO PLAY FUNCTIONALITY ====================

    local HttpService = game:GetService("HttpService")

    -- Initialize Auto Play globals
    getgenv().autoPlay = getgenv().autoPlay or false
    getgenv().autoVote = getgenv().autoVote or false
    getgenv().autoAbility = getgenv().autoAbility or false
    
    -- Initialize Semi Immortality globals
    getgenv().semiImmortal = getgenv().semiImmortal or false
    
    -- Initialize Auto Sword Buy globals
    getgenv().autoSwordBuy = getgenv().autoSwordBuy or false

    -- Auto Play Module
    local AutoPlayModule = {}
    AutoPlayModule.CONFIG = {
        DEFAULT_DISTANCE = 30,
        MULTIPLIER_THRESHOLD = 70,
        TRAVERSING = 25,
        DIRECTION = 1,
        JUMP_PERCENTAGE = 50,
        DOUBLE_JUMP_PERCENTAGE = 50,
        JUMPING_ENABLED = false,
        MOVEMENT_DURATION = 0.8,
        OFFSET_FACTOR = 0.7,
        GENERATION_THRESHOLD = 0.25,
    }
    AutoPlayModule.ball = nil
    AutoPlayModule.lobbyChoice = nil
    AutoPlayModule.animationCache = nil
    AutoPlayModule.doubleJumped = false
    AutoPlayModule.ELAPSED = 0
    AutoPlayModule.CONTROL_POINT = nil
    AutoPlayModule.LAST_GENERATION = 0
    AutoPlayModule.signals = {}

    -- Get service function with cloneref support
    do
        local getServiceFunction = game.GetService
        local function getClonerefPermission()
            local permission = cloneref(getServiceFunction(game, "ReplicatedFirst"))
            return permission
        end
        AutoPlayModule.clonerefPermission = getClonerefPermission()
        if not AutoPlayModule.clonerefPermission then
            warn("cloneref is not available on your executor! There is a risk of getting detected.")
        end
        function AutoPlayModule.findCachedService(self, name)
            for index, value in self do
                if value.Name == name then
                    return value
                end
            end
            return
        end
        function AutoPlayModule.getService(self, name)
            local cachedService = AutoPlayModule.findCachedService(self, name)
            if cachedService then
                return cachedService
            end
            local service = getServiceFunction(game, name)
            if AutoPlayModule.clonerefPermission then
                service = cloneref(service)
            end
            table.insert(self, service)
            return service
        end
        AutoPlayModule.customService = setmetatable({}, {
            __index = AutoPlayModule.getService,
        })
    end

    AutoPlayModule.playerHelper = {
        isAlive = function(player)
            local character = nil
            if player and player:IsA("Player") then
                character = player.Character
            end
            if not character then
                return false
            end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            if not rootPart or not humanoid then
                return false
            end
            return humanoid.Health > 0
        end,
        inLobby = function(character)
            if not character then
                return false
            end
            return character.Parent == AutoPlayModule.customService.Workspace.Dead
        end,
        onGround = function(character)
            if not character then
                return false
            end
            return character.Humanoid.FloorMaterial ~= Enum.Material.Air
        end,
    }

    function AutoPlayModule.isLimited()
        local passedTime = tick() - AutoPlayModule.LAST_GENERATION
        return passedTime < AutoPlayModule.CONFIG.GENERATION_THRESHOLD
    end

    function AutoPlayModule.percentageCheck(limit)
        if AutoPlayModule.isLimited() then
            return false
        end
        local percentage = math.random(100)
        AutoPlayModule.LAST_GENERATION = tick()
        return limit >= percentage
    end

    AutoPlayModule.ballUtils = {
        getBall = function()
            local balls = workspace:FindFirstChild("Balls")
            if not balls then return end
            for _, object in pairs(balls:GetChildren()) do
                if object:GetAttribute("realBall") then
                    AutoPlayModule.ball = object
                    return
                end
            end
            AutoPlayModule.ball = nil
        end,
        getDirection = function()
            if not AutoPlayModule.ball or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
                return
            end
            local direction = (
                plr.Character.HumanoidRootPart.Position
                - AutoPlayModule.ball.Position
            ).Unit
            return direction
        end,
        getVelocity = function()
            if not AutoPlayModule.ball then
                return
            end
            local zoomies = AutoPlayModule.ball:FindFirstChild("zoomies")
            if not zoomies then
                return
            end
            return zoomies.VectorVelocity
        end,
        getSpeed = function()
            local velocity = AutoPlayModule.ballUtils.getVelocity()
            if not velocity then
                return
            end
            return velocity.Magnitude
        end,
        isExisting = function()
            return AutoPlayModule.ball ~= nil
        end,
    }

    AutoPlayModule.lerp = function(start, finish, alpha)
        return start + (finish - start) * alpha
    end

    AutoPlayModule.quadratic = function(start, middle, finish, alpha)
        local firstLerp = AutoPlayModule.lerp(start, middle, alpha)
        local secondLerp = AutoPlayModule.lerp(middle, finish, alpha)
        return AutoPlayModule.lerp(firstLerp, secondLerp, alpha)
    end

    AutoPlayModule.getCandidates = function(middle, theta, offsetLength)
        local firstCanditateX = math.cos(theta + math.pi / 2)
        local firstCanditateZ = math.sin(theta + math.pi / 2)
        local firstCandidate = middle + Vector3.new(firstCanditateX, 0, firstCanditateZ) * offsetLength
        local secondCanditateX = math.cos(theta - math.pi / 2)
        local secondCanditateZ = math.sin(theta - math.pi / 2)
        local secondCandidate = middle + Vector3.new(secondCanditateX, 0, secondCanditateZ) * offsetLength
        return firstCandidate, secondCandidate
    end

    AutoPlayModule.getControlPoint = function(start, finish)
        local middle = (start + finish) * 0.5
        local difference = start - finish
        if difference.Magnitude < 5 then
            return finish
        end
        local theta = math.atan2(difference.Z, difference.X)
        local offsetLength = difference.Magnitude * AutoPlayModule.CONFIG.OFFSET_FACTOR
        local firstCandidate, secondCandidate = AutoPlayModule.getCandidates(middle, theta, offsetLength)
        local dotValue = start - middle
        if (firstCandidate - middle):Dot(dotValue) < 0 then
            return firstCandidate
        else
            return secondCandidate
        end
    end

    AutoPlayModule.getCurve = function(start, finish, delta)
        AutoPlayModule.ELAPSED = AutoPlayModule.ELAPSED + delta
        local timeElapsed = math.clamp(AutoPlayModule.ELAPSED / AutoPlayModule.CONFIG.MOVEMENT_DURATION, 0, 1)
        if timeElapsed >= 1 then
            local distance = (start - finish).Magnitude
            if distance >= 10 then
                AutoPlayModule.ELAPSED = 0
            end
            AutoPlayModule.CONTROL_POINT = nil
            return finish
        end
        if not AutoPlayModule.CONTROL_POINT then
            AutoPlayModule.CONTROL_POINT = AutoPlayModule.getControlPoint(start, finish)
        end
        if not AutoPlayModule.CONTROL_POINT then
            return finish
        end
        return AutoPlayModule.quadratic(start, AutoPlayModule.CONTROL_POINT, finish, timeElapsed)
    end

    AutoPlayModule.map = {
        getFloor = function()
            local floor = workspace:FindFirstChild("FLOOR")
            if not floor then
                for _, part in pairs(workspace:GetDescendants()) do
                    if part:IsA("MeshPart") or part:IsA("BasePart") then
                        local size = part.Size
                        if size.X > 50 and size.Z > 50 and part.Position.Y < 5 then
                            return part
                        end
                    end
                end
            end
            return floor
        end,
    }

    AutoPlayModule.getRandomPosition = function()
        local floor = AutoPlayModule.map.getFloor()
        if not floor or not AutoPlayModule.ballUtils.isExisting() then
            return
        end
        local ballDirection = AutoPlayModule.ballUtils.getDirection() * AutoPlayModule.CONFIG.DIRECTION
        local ballSpeed = AutoPlayModule.ballUtils.getSpeed()
        if not ballDirection or not ballSpeed then
            return
        end
        local speedThreshold = math.min(ballSpeed / 10, AutoPlayModule.CONFIG.MULTIPLIER_THRESHOLD)
        local speedMultiplier = AutoPlayModule.CONFIG.DEFAULT_DISTANCE + speedThreshold
        local negativeDirection = ballDirection * speedMultiplier
        local currentTime = os.time() / 1.2
        local sine = math.sin(currentTime) * AutoPlayModule.CONFIG.TRAVERSING
        local cosine = math.cos(currentTime) * AutoPlayModule.CONFIG.TRAVERSING
        local traversing = Vector3.new(sine, 0, cosine)
        local finalPosition = floor.Position + negativeDirection + traversing
        return finalPosition
    end

    AutoPlayModule.lobby = {
        isChooserAvailable = function()
            local spawn = workspace:FindFirstChild("Spawn")
            if not spawn then return false end
            local newPlayerCounter = spawn:FindFirstChild("NewPlayerCounter")
            if not newPlayerCounter then return false end
            local gui = newPlayerCounter:FindFirstChild("GUI")
            if not gui then return false end
            local surfaceGui = gui:FindFirstChild("SurfaceGui")
            if not surfaceGui then return false end
            local top = surfaceGui:FindFirstChild("Top")
            if not top then return false end
            local options = top:FindFirstChild("Options")
            return options and options.Visible or false
        end,
        updateChoice = function(choice)
            AutoPlayModule.lobbyChoice = choice
        end,
        getMapChoice = function()
            local choice = AutoPlayModule.lobbyChoice or math.random(1, 3)
            local spawn = workspace:FindFirstChild("Spawn")
            if not spawn then return end
            local newPlayerCounter = spawn:FindFirstChild("NewPlayerCounter")
            if not newPlayerCounter then return end
            local colliders = newPlayerCounter:FindFirstChild("Colliders")
            if not colliders then return end
            local collider = colliders:FindFirstChild(tostring(choice))
            return collider
        end,
        getPadPosition = function()
            if not AutoPlayModule.lobby.isChooserAvailable() then
                AutoPlayModule.lobbyChoice = nil
                return
            end
            local choice = AutoPlayModule.lobby.getMapChoice()
            if not choice then
                return
            end
            return choice.Position, choice.Name
        end,
    }

    AutoPlayModule.movement = {
        removeCache = function()
            if AutoPlayModule.animationCache then
                AutoPlayModule.animationCache = nil
            end
        end,
        createJumpVelocity = function(player)
            if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
            local maxForce = math.huge
            local velocity = Instance.new("BodyVelocity")
            velocity.MaxForce = Vector3.new(maxForce, maxForce, maxForce)
            velocity.Velocity = Vector3.new(0, 80, 0)
            velocity.Parent = player.Character.HumanoidRootPart
            Debris:AddItem(velocity, 0.001)
            local doubleJumpRemote = rs:FindFirstChild("Remotes")
            if doubleJumpRemote then
                doubleJumpRemote = doubleJumpRemote:FindFirstChild("DoubleJump")
                if doubleJumpRemote then
                    doubleJumpRemote:FireServer()
                end
            end
        end,
        playJumpAnimation = function(player)
            if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
            if not AutoPlayModule.animationCache then
                local assets = rs:FindFirstChild("Assets")
                if assets then
                    local tutorial = assets:FindFirstChild("Tutorial")
                    if tutorial then
                        local animations = tutorial:FindFirstChild("Animations")
                        if animations then
                            local doubleJumpAnimation = animations:FindFirstChild("DoubleJump")
                            if doubleJumpAnimation then
                                AutoPlayModule.animationCache = player.Character.Humanoid.Animator:LoadAnimation(doubleJumpAnimation)
                            end
                        end
                    end
                end
            end
            if AutoPlayModule.animationCache then
                AutoPlayModule.animationCache:Play()
            end
        end,
        doubleJump = function(player)
            if AutoPlayModule.doubleJumped then
                return
            end
            if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.DOUBLE_JUMP_PERCENTAGE) then
                return
            end
            AutoPlayModule.doubleJumped = true
            AutoPlayModule.movement.createJumpVelocity(player)
            AutoPlayModule.movement.playJumpAnimation(player)
        end,
        jump = function(player)
            if not AutoPlayModule.CONFIG.JUMPING_ENABLED then
                return
            end
            if not AutoPlayModule.playerHelper.onGround(player.Character) then
                AutoPlayModule.movement.doubleJump(player)
                return
            end
            if not AutoPlayModule.percentageCheck(AutoPlayModule.CONFIG.JUMP_PERCENTAGE) then
                return
            end
            AutoPlayModule.doubleJumped = false
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end,
        move = function(player, playerPosition)
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid:MoveTo(playerPosition)
            end
        end,
        stop = function(player)
            if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not player.Character:FindFirstChild("Humanoid") then
                return
            end
            local playerPosition = player.Character.HumanoidRootPart.Position
            player.Character.Humanoid:MoveTo(playerPosition)
        end,
    }

    AutoPlayModule.signal = {
        connect = function(name, connection, callback)
            if not name then
                name = HttpService:GenerateGUID()
            end
            AutoPlayModule.signals[name] = connection:Connect(callback)
            return AutoPlayModule.signals[name]
        end,
        disconnect = function(name)
            if not name or not AutoPlayModule.signals[name] then
                return
            end
            AutoPlayModule.signals[name]:Disconnect()
            AutoPlayModule.signals[name] = nil
        end,
        stop = function()
            for name, connection in pairs(AutoPlayModule.signals) do
                if typeof(connection) ~= "RBXScriptConnection" then
                    continue
                end
                connection:Disconnect()
                AutoPlayModule.signals[name] = nil
            end
        end,
    }

    AutoPlayModule.findPath = function(inLobby, delta)
        if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        local rootPosition = plr.Character.HumanoidRootPart.Position
        if inLobby then
            local padPosition, padNumber = AutoPlayModule.lobby.getPadPosition()
            local choice = tonumber(padNumber)
            if choice then
                AutoPlayModule.lobby.updateChoice(choice)
                if getgenv().autoVote then
                    local packages = rs:FindFirstChild("Packages")
                    if packages then
                        local _Index = packages:FindFirstChild("_Index")
                        if _Index then
                            local sleitnick_net = _Index:FindFirstChild("sleitnick_net@0.1.0")
                            if sleitnick_net then
                                local net = sleitnick_net:FindFirstChild("net")
                                if net then
                                    local updateVotes = net:FindFirstChild("RE/UpdateVotes")
                                    if updateVotes then
                                        updateVotes:FireServer("FFA")
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not padPosition then
                return
            end
            return AutoPlayModule.getCurve(rootPosition, padPosition, delta)
        end
        local randomPosition = AutoPlayModule.getRandomPosition()
        if not randomPosition then
            return
        end
        return AutoPlayModule.getCurve(rootPosition, randomPosition, delta)
    end

    AutoPlayModule.followPath = function(delta)
        if not AutoPlayModule.playerHelper.isAlive(plr) then
            AutoPlayModule.movement.removeCache()
            return
        end
        local inLobby = plr.Character and plr.Character.Parent == workspace.Dead
        local path = AutoPlayModule.findPath(inLobby, delta)
        if not path then
            AutoPlayModule.movement.stop(plr)
            return
        end
        AutoPlayModule.movement.move(plr, path)
        AutoPlayModule.movement.jump(plr)
    end

    AutoPlayModule.finishThread = function()
        AutoPlayModule.signal.disconnect("auto-play")
        AutoPlayModule.signal.disconnect("synchronize")
        if not AutoPlayModule.playerHelper.isAlive(plr) then
            return
        end
        AutoPlayModule.movement.stop(plr)
    end

    AutoPlayModule.runThread = function()
        AutoPlayModule.signal.connect(
            "auto-play",
            RunService.PostSimulation,
            AutoPlayModule.followPath
        )
        AutoPlayModule.signal.connect(
            "synchronize",
            RunService.PostSimulation,
            AutoPlayModule.ballUtils.getBall
        )
    end

    -- ==================== SEMI IMMORTALITY FUNCTIONALITY ====================

    local playerPart = nil
    local mapFolder = nil

    -- Function to enable semi immortality
    local function enableSemiImmortal()
        if not plr.Character then
            return
        end
        local character = plr.Character
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then
            return
        end

        local ws = game:GetService("Workspace")
        
        -- Find or create map folder
        mapFolder = ws:FindFirstChild("Map")
        if not mapFolder then
            mapFolder = Instance.new("Folder")
            mapFolder.Name = "Map"
            mapFolder.Parent = ws
        end

        -- Make map parts transparent and non-collidable
        for _, obj in pairs(mapFolder:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Transparency = 0.5
                obj.CanCollide = false
            end
        end

        -- Create player part
        if not playerPart or not playerPart.Parent then
            playerPart = Instance.new("Part")
            playerPart.Name = "PlayerMapPart"
            playerPart.Size = Vector3.new(500, 1, 500)
            playerPart.Position = humanoidRootPart.Position - Vector3.new(0, 20, 0)
            playerPart.Anchored = true
            playerPart.Material = Enum.Material.SmoothPlastic
            playerPart.Color = Color3.fromRGB(255, 255, 255)
            playerPart.Parent = ws
        end

        -- Update player part position when character moves
        task.spawn(function()
            while getgenv().semiImmortal do
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    if playerPart and playerPart.Parent then
                        playerPart.Position = plr.Character.HumanoidRootPart.Position - Vector3.new(0, 20, 0)
                    end
                end
                task.wait(0.1)
            end
        end)
    end

    -- Function to disable semi immortality
    local function disableSemiImmortal()
        -- Restore map parts
        if mapFolder then
            for _, obj in pairs(mapFolder:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Transparency = 0
                    obj.CanCollide = true
                end
            end
        end

        -- Remove player part
        if playerPart and playerPart.Parent then
            playerPart:Destroy()
            playerPart = nil
        end
    end

    -- Function to update semi immortality
    getgenv().updateSemiImmortal = function()
        if getgenv().semiImmortal then
            enableSemiImmortal()
        else
            disableSemiImmortal()
        end
    end

    -- Character respawn handler
    plr.CharacterAdded:Connect(function(character)
        if getgenv().semiImmortal then
            task.wait(1)
            enableSemiImmortal()
        end
    end)

    -- ==================== END SEMI IMMORTALITY FUNCTIONALITY ====================

    -- ==================== AUTO SWORD BUY FUNCTIONALITY ====================

    local autoSwordBuyConnection = nil

    -- Function to update auto sword buy
    getgenv().updateAutoSwordBuy = function()
        if autoSwordBuyConnection then
            task.cancel(autoSwordBuyConnection)
            autoSwordBuyConnection = nil
        end

        if not getgenv().autoSwordBuy then
            return
        end

        -- Auto sword buy loop
        autoSwordBuyConnection = task.spawn(function()
            while getgenv().autoSwordBuy do
                task.wait()
                pcall(function()
                    local rs = game:GetService("ReplicatedStorage")
                    local storeRemote = rs:FindFirstChild("Remotes")
                    if storeRemote then
                        storeRemote = storeRemote:FindFirstChild("Store")
                        if storeRemote then
                            storeRemote = storeRemote:FindFirstChild("RequestOpenSwordBox")
                            if storeRemote then
                                storeRemote:InvokeServer()
                            end
                        end
                    end
                end)
            end
        end)
    end

    -- ==================== END AUTO SWORD BUY FUNCTIONALITY ====================

    -- ==================== AUTO ABILITY FUNCTIONALITY ====================

    -- Function to check if ability cooldown is active
    local function isCooldownInEffect2(uigradient)
        return uigradient and uigradient.Offset and uigradient.Offset.Y == 0.5
    end

    -- Auto Ability function (global for use in auto parry)
    getgenv().AutoAbility = function()
        if not plr.Character then
            return false
        end
        
        local playerGui = plr:FindFirstChild("PlayerGui")
        if not playerGui then
            return false
        end
        
        local hotbar = playerGui:FindFirstChild("Hotbar")
        if not hotbar then
            return false
        end
        
        local ability = hotbar:FindFirstChild("Ability")
        if not ability then
            return false
        end
        
        local abilityCD = ability:FindFirstChild("UIGradient")
        if not abilityCD then
            return false
        end

        if isCooldownInEffect2(abilityCD) then
            local abilities = plr.Character:FindFirstChild("Abilities")
            if not abilities then
                return false
            end

            local abilityNames = {
                "Raging Deflection",
                "Dash",
                "Rapture",
                "Calming Deflection",
                "Aerodynamic Slash",
                "Fracture",
                "Death Slash"
            }

            for _, abilityName in ipairs(abilityNames) do
                local abilityObj = abilities:FindFirstChild(abilityName)
                if abilityObj and abilityObj.Enabled then
                    pcall(function()
                        rs.Remotes.AbilityButtonPress:Fire()
                        task.wait(2.432)
                        local deathSlashRemote = rs:WaitForChild("Remotes"):WaitForChild("DeathSlashShootActivation")
                        if deathSlashRemote then
                            deathSlashRemote:FireServer(true)
                        end
                    end)
                    return true
                end
            end
        end
        return false
    end

    -- Function to update auto ability
    getgenv().updateAutoAbility = function()
        -- Auto ability is integrated with auto parry
        -- No separate connection needed, it's called from auto parry logic
    end

    -- ==================== END AUTO ABILITY FUNCTIONALITY ====================

    -- ==================== END AUTO PLAY FUNCTIONALITY ====================



    -- ==================== EMOTE FUNCTIONALITY ====================

    -- Initialize Emote globals
    getgenv().emotesEnabled = getgenv().emotesEnabled or false
    getgenv().loopEmote = getgenv().loopEmote or false
    getgenv().selectedEmote = getgenv().selectedEmote or nil

    -- Animation storage
    getgenv().Animation = getgenv().Animation or {
        storage = {},
        track = nil,
        current = nil
    }
    local Animation = getgenv().Animation

    -- Load emotes from ReplicatedStorage
    getgenv().Emotes_Data = getgenv().Emotes_Data or {}
    local Emotes_Data = getgenv().Emotes_Data
    
    task.spawn(function()
        task.wait(1) -- Wait before loading emotes
        pcall(function()
            local misc = rs:WaitForChild("Misc", 30)
            local emotesFolder = misc:WaitForChild("Emotes", 30)
            for _, v in pairs(emotesFolder:GetChildren()) do
                if v:IsA("Animation") and v:GetAttribute("EmoteName") then
                    local Emote_Name = v:GetAttribute("EmoteName")
                    Animation.storage[Emote_Name] = v
                    table.insert(Emotes_Data, Emote_Name)
                end
                task.wait() -- Yield every emote to prevent freezing
            end
            table.sort(Emotes_Data)
            if #Emotes_Data > 0 and not getgenv().selectedEmote then
                getgenv().selectedEmote = Emotes_Data[1]
            end
        end)
    end)

    -- Function to play animation
    getgenv().playEmoteAnimation = function(emoteName)
        if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then
            return false
        end
        local Animations = Animation.storage[emoteName]
        if not Animations then
            return false
        end
        local Animator = plr.Character.Humanoid.Animator
        if Animation.track then
            Animation.track:Stop()
            Animation.track:Destroy()
        end
        Animation.track = Animator:LoadAnimation(Animations)
        Animation.track:Play()
        Animation.current = emoteName
        return true
    end

    -- Emote connection manager
    local emoteConnection = nil

    -- Function to update emotes
    getgenv().updateEmotes = function()
        if emoteConnection then
            emoteConnection:Disconnect()
            emoteConnection = nil
        end
        
        if getgenv().emotesEnabled then
            local emoteUpdateCounter = 0
            emoteConnection = RunService.Heartbeat:Connect(function()
                emoteUpdateCounter = emoteUpdateCounter + 1
                -- Update every 10 frames for better performance (emotes don't need to be checked so often)
                if emoteUpdateCounter % 10 ~= 0 then
                    return
                end
                
                if not plr.Character or not plr.Character:FindFirstChild("PrimaryPart") then
                    return
                end
                local Speed = plr.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude
                if Speed > 30 then
                    if Animation.track and not getgenv().loopEmote then
                        Animation.track:Stop()
                        Animation.track:Destroy()
                        Animation.track = nil
                    end
                else
                    if not Animation.track and Animation.current then
                        getgenv().playEmoteAnimation(Animation.current)
                    end
                end
            end)
            
            -- Play selected emote if available
            if getgenv().selectedEmote then
                getgenv().playEmoteAnimation(getgenv().selectedEmote)
            end
        else
            if Animation.track then
                Animation.track:Stop()
                Animation.track:Destroy()
                Animation.track = nil
            end
        end
    end

    -- ==================== END EMOTE FUNCTIONALITY ====================



    -- ==================== SKY CHANGER FUNCTIONALITY ====================

    local Lighting = game:GetService("Lighting")

    -- Initialize Sky globals
    getgenv().customSky = getgenv().customSky or false
    getgenv().selectedSky = getgenv().selectedSky or "Default"

    -- Skybox data
    getgenv().skyboxData = getgenv().skyboxData or {
        ["Default"] = { "591058823", "591059876", "591058104", "591057861", "591057625", "591059642" },
        ["Vaporwave"] = { "1417494030", "1417494146", "1417494253", "1417494402", "1417494499", "1417494643" },
        ["Redshift"] = { "401664839", "401664862", "401664960", "401664881", "401664901", "401664936" },
        ["Desert"] = { "1013852", "1013853", "1013850", "1013851", "1013849", "1013854" },
        ["DaBaby"] = { "7245418472", "7245418472", "7245418472", "7245418472", "7245418472", "7245418472" },
        ["Minecraft"] = { "1876545003", "1876544331", "1876542941", "1876543392", "1876543764", "1876544642" },
        ["SpongeBob"] = { "7633178166", "7633178166", "7633178166", "7633178166", "7633178166", "7633178166" },
        ["Skibidi"] = { "14952256113", "14952256113", "14952256113", "14952256113", "14952256113", "14952256113" },
        ["Blaze"] = { "150939022", "150939038", "150939047", "150939056", "150939063", "150939082" },
        ["Pussy Cat"] = { "11154422902", "11154422902", "11154422902", "11154422902", "11154422902", "11154422902" },
        ["Among Us"] = { "5752463190", "5752463190", "5752463190", "5752463190", "5752463190", "5752463190" },
        ["Space Wave"] = { "16262356578", "16262358026", "16262360469", "16262362003", "16262363873", "16262366016" },
        ["Space Wave2"] = { "1233158420", "1233158838", "1233157105", "1233157640", "1233157995", "1233159158" },
        ["Turquoise Wave"] = { "47974894", "47974690", "47974821", "47974776", "47974859", "47974909" },
        ["Dark Night"] = { "6285719338", "6285721078", "6285722964", "6285724682", "6285726335", "6285730635" },
        ["Bright Pink"] = { "271042516", "271077243", "271042556", "271042310", "271042467", "271077958" },
        ["White Galaxy"] = { "5540798456", "5540799894", "5540801779", "5540801192", "5540799108", "5540800635" },
        ["Blue Galaxy"] = { "14961495673", "14961494492", "14961492844", "14961491298", "14961490439", "14961489508" }
    }
    local skyboxData = getgenv().skyboxData

    -- Function to apply skybox
    getgenv().applySkybox = function(skyName)
        local data = skyboxData[skyName]
        if not data then
            warn("Sky option not found: " .. tostring(skyName))
            return
        end
        
        local Sky = Lighting:FindFirstChildOfClass("Sky")
        if not Sky then
            Sky = Instance.new("Sky")
            Sky.Parent = Lighting
        end
        
        local skyFaces = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
        for index, face in ipairs(skyFaces) do
            Sky[face] = "rbxassetid://" .. data[index]
        end
        
        if skyName == "Default" then
            Lighting.GlobalShadows = true
        else
            Lighting.GlobalShadows = false
        end
    end

    -- Function to update sky
    getgenv().updateSky = function()
        if getgenv().customSky then
            getgenv().applySkybox(getgenv().selectedSky)
        else
            -- Reset to default
            local Sky = Lighting:FindFirstChildOfClass("Sky")
            if Sky then
                local defaultSkyboxIds = { "591058823", "591059876", "591058104", "591057861", "591057625", "591059642" }
                local skyFaces = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
                for index, face in ipairs(skyFaces) do
                    Sky[face] = "rbxassetid://" .. defaultSkyboxIds[index]
                end
                Lighting.GlobalShadows = true
            end
        end
    end

    -- ==================== END SKY CHANGER FUNCTIONALITY ====================



    -- ==================== BALL TRAIL FUNCTIONALITY ====================

    -- Initialize Ball Trail globals
    getgenv().ballTrailEnabled = getgenv().ballTrailEnabled or false
    getgenv().ballTrailHue = getgenv().ballTrailHue or 0
    getgenv().ballTrailRainbow = getgenv().ballTrailRainbow or false
    getgenv().ballTrailParticle = getgenv().ballTrailParticle or false
    getgenv().ballTrailGlow = getgenv().ballTrailGlow or false
    getgenv().ballTrailColor = getgenv().ballTrailColor or Color3.new(1, 1, 1)

    -- Ball Trail variables
    local ballTrailHue = 0
    local trackedBalls = {}

    -- Function to get balls
    local function getBalls()
        local balls = {}
        for _, instance in pairs(workspace.Balls:GetChildren()) do
            if instance:GetAttribute("realBall") then
                table.insert(balls, instance)
            end
        end
        return balls
    end

    -- Function to clear effects from ball
    local function clearBallEffects(ball)
        local trail = ball:FindFirstChild("Trail")
        if trail then
            trail:Destroy()
        end
        local emitter = ball:FindFirstChild("ParticleEmitter")
        if emitter then
            emitter:Destroy()
        end
        local glow = ball:FindFirstChild("BallGlow")
        if glow then
            glow:Destroy()
        end
        local att0 = ball:FindFirstChild("Attachment0")
        if att0 then
            att0:Destroy()
        end
        local att1 = ball:FindFirstChild("Attachment1")
        if att1 then
            att1:Destroy()
        end
    end

    -- Function to apply effects to ball
    local function applyBallEffects(ball)
        if not getgenv().ballTrailEnabled then
            if trackedBalls[ball] then
                clearBallEffects(ball)
                trackedBalls[ball] = nil
            end
            return
        end

        if trackedBalls[ball] then
            local trail = ball:FindFirstChild("Trail")
            if trail then
                if getgenv().ballTrailRainbow then
                    local color = Color3.fromHSV(ballTrailHue / 360, 1, 1)
                    trail.Color = ColorSequence.new(color)
                    getgenv().ballTrailColor = color
                else
                    trail.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
                end
            end
            
            -- Update glow color if enabled
            local glow = ball:FindFirstChild("BallGlow")
            if glow and getgenv().ballTrailGlow then
                if getgenv().ballTrailRainbow then
                    glow.Color = Color3.fromHSV(ballTrailHue / 360, 1, 1)
                else
                    glow.Color = getgenv().ballTrailColor or Color3.new(1, 1, 1)
                end
            end
            
            -- Update particle emitter color if enabled
            local emitter = ball:FindFirstChild("ParticleEmitter")
            if emitter and getgenv().ballTrailParticle then
                if getgenv().ballTrailRainbow then
                    emitter.Color = ColorSequence.new(Color3.fromHSV(ballTrailHue / 360, 1, 1))
                else
                    emitter.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
                end
            end
            
            return
        end

        trackedBalls[ball] = true

        -- Create trail
        local trail = Instance.new("Trail")
        trail.Name = "Trail"
        local att0 = Instance.new("Attachment")
        att0.Name = "Attachment0"
        att0.Position = Vector3.new(0, ball.Size.Y / 2, 0)
        att0.Parent = ball
        local att1 = Instance.new("Attachment")
        att1.Name = "Attachment1"
        att1.Position = Vector3.new(0, -ball.Size.Y / 2, 0)
        att1.Parent = ball
        trail.Attachment0 = att0
        trail.Attachment1 = att1
        trail.Lifetime = 0.4
        trail.WidthScale = NumberSequence.new(0.5)
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
        trail.Parent = ball

        -- Create particle emitter if enabled
        if getgenv().ballTrailParticle then
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = "ParticleEmitter"
            emitter.Rate = 100
            emitter.Lifetime = NumberRange.new(0.5, 1)
            emitter.Speed = NumberRange.new(0, 1)
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(1, 0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.Color = ColorSequence.new(getgenv().ballTrailColor or Color3.new(1, 1, 1))
            emitter.Parent = ball
        end

        -- Create glow effect if enabled
        if getgenv().ballTrailGlow then
            local glow = Instance.new("PointLight")
            glow.Name = "BallGlow"
            glow.Range = 15
            glow.Brightness = 2
            glow.Color = getgenv().ballTrailColor or Color3.new(1, 1, 1)
            glow.Parent = ball
        end
    end

    -- Ball Trail update connection
    local ballTrailConnection = nil

    -- Clean up effects when balls are removed
    workspace.Balls.ChildRemoved:Connect(function(ball)
        if trackedBalls[ball] then
            trackedBalls[ball] = nil
        end
    end)

    -- Function to update ball trail
    getgenv().updateBallTrail = function()
        if ballTrailConnection then
            ballTrailConnection:Disconnect()
            ballTrailConnection = nil
        end

        if not getgenv().ballTrailEnabled then
            -- Clear all effects from tracked balls
            for ball, _ in pairs(trackedBalls) do
                if ball.Parent then
                    clearBallEffects(ball)
                end
            end
            trackedBalls = {}
            return
        end

        -- Start heartbeat loop to update ball effects
        local ballTrailUpdateCounter = 0
        ballTrailConnection = RunService.Heartbeat:Connect(function()
            ballTrailUpdateCounter = ballTrailUpdateCounter + 1
            -- Update every 3 frames for better performance
            if ballTrailUpdateCounter % 3 == 0 then
                ballTrailHue = (ballTrailHue + 1) % 360
                for _, ball in ipairs(getBalls()) do
                    if ball and ball.Parent then
                        applyBallEffects(ball)
                    end
                end
            end
        end)
    end

    -- ==================== END BALL TRAIL FUNCTIONALITY ====================



    -- ==================== PLAYER FUNCTIONALITY ====================

    -- Initialize Player globals
    getgenv().playerSpeedEnabled = getgenv().playerSpeedEnabled or false
    getgenv().playerSpeed = getgenv().playerSpeed or 36
    getgenv().fovEnabled = getgenv().fovEnabled or false
    getgenv().fov = getgenv().fov or 70
    getgenv().playerCosmeticsEnabled = getgenv().playerCosmeticsEnabled or false
    getgenv().hitSoundsEnabled = getgenv().hitSoundsEnabled or false
    getgenv().hitSoundVolume = getgenv().hitSoundVolume or 5
    getgenv().hitSoundType = getgenv().hitSoundType or "Medal"

    -- Player Speed variables
    local speedConnection = nil

    -- Function to update player speed
    getgenv().updatePlayerSpeed = function()
        if speedConnection then
            speedConnection:Disconnect()
            speedConnection = nil
        end

        local speedUpdateCounter = 0
        speedConnection = RunService.Heartbeat:Connect(function()
            speedUpdateCounter = speedUpdateCounter + 1
            -- Update every 5 frames for better performance
            if speedUpdateCounter % 5 ~= 0 then
                return
            end
            
            if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                if getgenv().playerSpeedEnabled then
                    plr.Character.Humanoid.WalkSpeed = getgenv().playerSpeed
                else
                    plr.Character.Humanoid.WalkSpeed = 36
                end
            end
        end)

        -- Apply speed when character spawns
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            if getgenv().playerSpeedEnabled then
                plr.Character.Humanoid.WalkSpeed = getgenv().playerSpeed
            else
                plr.Character.Humanoid.WalkSpeed = 36
            end
        end
    end

    -- Handle character respawn for speed
    plr.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            if getgenv().playerSpeedEnabled then
                humanoid.WalkSpeed = getgenv().playerSpeed
            else
                humanoid.WalkSpeed = 36
            end
        end
    end)

    -- Field of View variables
    local fovConnection = nil

    -- Function to update field of view
    getgenv().updateFOV = function()
        if fovConnection then
            fovConnection:Disconnect()
            fovConnection = nil
        end

        if not getgenv().fovEnabled then
            workspace.CurrentCamera.FieldOfView = 70
            return
        end

        workspace.CurrentCamera.FieldOfView = getgenv().fov
        fovConnection = RunService.Heartbeat:Connect(function()
            if getgenv().fovEnabled then
                workspace.CurrentCamera.FieldOfView = getgenv().fov
            end
        end)
    end

    -- Player Cosmetics variables
    local cosmeticsActive = false
    local headLoop = nil
    getgenv().PlayerCosmeticsCleanup = getgenv().PlayerCosmeticsCleanup or {}
    local cosmeticsCharacterAddedConnection = nil

    -- Function to apply Korblox
    local function applyKorblox(character)
        local rightLeg = character:FindFirstChild("RightLeg") or character:FindFirstChild("Right Leg")
        if not rightLeg then
            return
        end
        for _, child in pairs(rightLeg:GetChildren()) do
            if child:IsA("SpecialMesh") then
                child:Destroy()
            end
        end
        local specialMesh = Instance.new("SpecialMesh")
        specialMesh.MeshId = "rbxassetid://101851696"
        specialMesh.TextureId = "rbxassetid://115727863"
        specialMesh.Scale = Vector3.new(1, 1, 1)
        specialMesh.Parent = rightLeg
    end

    -- Function to save right leg properties
    local function saveRightLegProperties(char)
        if char then
            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
            if rightLeg then
                local originalMesh = rightLeg:FindFirstChildOfClass("SpecialMesh")
                if originalMesh then
                    getgenv().PlayerCosmeticsCleanup.originalMeshId = originalMesh.MeshId
                    getgenv().PlayerCosmeticsCleanup.originalTextureId = originalMesh.TextureId
                    getgenv().PlayerCosmeticsCleanup.originalScale = originalMesh.Scale
                else
                    getgenv().PlayerCosmeticsCleanup.hadNoMesh = true
                end
                getgenv().PlayerCosmeticsCleanup.rightLegChildren = {}
                for _, child in pairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") then
                        table.insert(getgenv().PlayerCosmeticsCleanup.rightLegChildren, {
                            ClassName = child.ClassName,
                            Properties = {
                                MeshId = child.MeshId,
                                TextureId = child.TextureId,
                                Scale = child.Scale,
                            },
                        })
                    end
                end
            end
        end
    end

    -- Function to restore right leg
    local function restoreRightLeg(char)
        if char then
            local rightLeg = char:FindFirstChild("RightLeg") or char:FindFirstChild("Right Leg")
            if rightLeg and getgenv().PlayerCosmeticsCleanup.rightLegChildren then
                for _, child in pairs(rightLeg:GetChildren()) do
                    if child:IsA("SpecialMesh") then
                        child:Destroy()
                    end
                end
                if getgenv().PlayerCosmeticsCleanup.hadNoMesh then
                    return
                end
                for _, childData in ipairs(getgenv().PlayerCosmeticsCleanup.rightLegChildren) do
                    if childData.ClassName == "SpecialMesh" then
                        local newMesh = Instance.new("SpecialMesh")
                        newMesh.MeshId = childData.Properties.MeshId
                        newMesh.TextureId = childData.Properties.TextureId
                        newMesh.Scale = childData.Properties.Scale
                        newMesh.Parent = rightLeg
                    end
                end
            end
        end
    end

    -- Function to update player cosmetics
    getgenv().updatePlayerCosmetics = function()
        if not getgenv().playerCosmeticsEnabled then
            cosmeticsActive = false
            if cosmeticsCharacterAddedConnection then
                cosmeticsCharacterAddedConnection:Disconnect()
                cosmeticsCharacterAddedConnection = nil
            end
            if headLoop then
                task.cancel(headLoop)
                headLoop = nil
            end
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                if head and getgenv().PlayerCosmeticsCleanup.headTransparency ~= nil then
                    head.Transparency = getgenv().PlayerCosmeticsCleanup.headTransparency
                    if getgenv().PlayerCosmeticsCleanup.faceDecalId then
                        local newDecal = head:FindFirstChildOfClass("Decal") or Instance.new("Decal", head)
                        newDecal.Name = getgenv().PlayerCosmeticsCleanup.faceDecalName or "face"
                        newDecal.Texture = getgenv().PlayerCosmeticsCleanup.faceDecalId
                        newDecal.Face = Enum.NormalId.Front
                    end
                end
                restoreRightLeg(char)
            end
            getgenv().PlayerCosmeticsCleanup = {}
            return
        end

        cosmeticsActive = true
        getgenv().Config = {
            Headless = true,
        }
        if plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head and getgenv().Config.Headless then
                getgenv().PlayerCosmeticsCleanup.headTransparency = head.Transparency
                local decal = head:FindFirstChildOfClass("Decal")
                if decal then
                    getgenv().PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                    getgenv().PlayerCosmeticsCleanup.faceDecalName = decal.Name
                end
            end
            saveRightLegProperties(plr.Character)
            applyKorblox(plr.Character)
        end

        cosmeticsCharacterAddedConnection = plr.CharacterAdded:Connect(function(char)
            local head = char:WaitForChild("Head", 5)
            if head and getgenv().Config.Headless then
                getgenv().PlayerCosmeticsCleanup.headTransparency = head.Transparency
                local decal = head:FindFirstChildOfClass("Decal")
                if decal then
                    getgenv().PlayerCosmeticsCleanup.faceDecalId = decal.Texture
                    getgenv().PlayerCosmeticsCleanup.faceDecalName = decal.Name
                end
            end
            local rightLeg = char:WaitForChild("RightLeg", 0.1) or char:WaitForChild("Right Leg", 0.1)
            if rightLeg then
                applyKorblox(char)
            end
        end)

        if getgenv().Config.Headless then
            headLoop = task.spawn(function()
                while cosmeticsActive do
                    local char = plr.Character
                    if char then
                        local head = char:FindFirstChild("Head")
                        if head then
                            head.Transparency = 1
                            local decal = head:FindFirstChildOfClass("Decal")
                            if decal then
                                decal:Destroy()
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end

    -- Hit Sounds variables
    local hitSoundFolder = nil
    local hitSound = nil
    local hitSoundIds = {
        Medal = "rbxassetid://6607336718",
        Fatality = "rbxassetid://6607113255",
        Skeet = "rbxassetid://6607204501",
        Switches = "rbxassetid://6607173363",
        ["Rust Headshot"] = "rbxassetid://138750331387064",
        ["Neverlose Sound"] = "rbxassetid://110168723447153",
        Bubble = "rbxassetid://6534947588",
        Laser = "rbxassetid://7837461331",
        Steve = "rbxassetid://4965083997",
        ["Call of Duty"] = "rbxassetid://5952120301",
        Bat = "rbxassetid://3333907347",
        ["TF2 Critical"] = "rbxassetid://296102734",
        Saber = "rbxassetid://8415678813",
        Bameware = "rbxassetid://3124331820",
    }

    -- Function to initialize hit sounds
    local function initializeHitSounds()
        if not hitSoundFolder then
            hitSoundFolder = Instance.new("Folder")
            hitSoundFolder.Name = "Useful Utility"
            hitSoundFolder.Parent = workspace
        end
        if not hitSound then
            hitSound = Instance.new("Sound", hitSoundFolder)
            hitSound.Volume = getgenv().hitSoundVolume or 5
            if hitSoundIds[getgenv().hitSoundType] then
                hitSound.SoundId = hitSoundIds[getgenv().hitSoundType]
            else
                hitSound.SoundId = hitSoundIds["Medal"]
            end
        end
    end

    -- Function to update hit sounds
    getgenv().updateHitSounds = function()
        initializeHitSounds()
        if hitSound then
            hitSound.Volume = getgenv().hitSoundVolume or 5
            if hitSoundIds[getgenv().hitSoundType] then
                hitSound.SoundId = hitSoundIds[getgenv().hitSoundType]
            end
        end
    end

    -- Initialize hit sounds on script load
    initializeHitSounds()

    -- Connect to ParrySuccess event for hit sounds
    rs.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if getgenv().hitSoundsEnabled then
            initializeHitSounds()
            if hitSound then
                hitSound:Play()
            end
        end
    end)

    -- ==================== END PLAYER FUNCTIONALITY ====================

    -- ==================== BUG REPORT FUNCTIONALITY ====================

    -- Discord Webhook URL
    local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1436714276256485478/gqSKwrpG933X4BeIGcPz05xzPpyCDwZv3tYEf-o3nTff6pRGcsCwUVrRpuljOZa6v92N"

    -- Function to send bug report to Discord
    local function sendBugReportToDiscord(bugType, bugMessage)
        if DISCORD_WEBHOOK_URL == "" then
            return false
        end

        local playerName = Player.Name
        local playerUserId = Player.UserId
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")

        -- Limit bug message to 1000 characters (Discord field limit is 1024)
        local limitedBugMessage = bugMessage
        if #bugMessage > 1000 then
            limitedBugMessage = string.sub(bugMessage, 1, 1000) .. "..."
        end

        local embed = {
            title = "🐛 Bug Report",
            color = 15158332, -- Red color
            fields = {
                {
                    name = "Bug Type",
                    value = bugType,
                    inline = true
                },
                {
                    name = "Player",
                    value = playerName .. " (" .. playerUserId .. ")",
                    inline = true
                },
                {
                    name = "Timestamp",
                    value = timestamp,
                    inline = true
                },
                {
                    name = "Bug Description",
                    value = limitedBugMessage or "No description provided",
                    inline = false
                }
            },
            footer = {
                text = "Mrise Hub X - Bug Report System"
            }
        }

        local payload = {
            embeds = {embed}
        }

        local success, errorMessage = pcall(function()
            local jsonPayload = HttpService:JSONEncode(payload)
            
            -- Try using RequestAsync instead of PostAsync for better error handling
            local requestData = {
                Url = DISCORD_WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonPayload
            }
            
            local response = HttpService:RequestAsync(requestData)
            
            if response.Success then
                return true
            else
                warn("Discord webhook error: " .. tostring(response.StatusCode) .. " - " .. tostring(response.StatusMessage))
                return false
            end
        end)

        if not success then
            warn("Discord webhook error: " .. tostring(errorMessage))
        end

        return success
    end

    -- ==================== END BUG REPORT FUNCTIONALITY ====================



    do

        -- ESP Enabled Toggle (at the top of Main tab)
        local ESPEnabledToggle = Tabs.Main:AddToggle("ESPEnabledToggle", {
            Title = "ESP Enabled",
            Default = getgenv().espEnabled or false
        })

        ESPEnabledToggle:OnChanged(function()
            getgenv().espEnabled = Options.ESPEnabledToggle.Value
            getgenv().updateESP()
        end)

        -- ESP Tracers Toggle
        local ESPTracersToggle = Tabs.Main:AddToggle("ESPTracersToggle", {
            Title = "ESP Tracers",
            Default = getgenv().espTracers or false
        })

        ESPTracersToggle:OnChanged(function()
            getgenv().espTracers = Options.ESPTracersToggle.Value
            getgenv().updateESP()
        end)

        -- ESP Names Toggle
        local ESPNamesToggle = Tabs.Main:AddToggle("ESPNamesToggle", {
            Title = "ESP Names",
            Default = getgenv().espNames or false
        })

        ESPNamesToggle:OnChanged(function()
            getgenv().espNames = Options.ESPNamesToggle.Value
            getgenv().updateESP()
        end)

        -- ESP Boxes Toggle
        local ESPBoxesToggle = Tabs.Main:AddToggle("ESPBoxesToggle", {
            Title = "ESP Boxes",
            Default = getgenv().espBoxes or false
        })

        ESPBoxesToggle:OnChanged(function()
            getgenv().espBoxes = Options.ESPBoxesToggle.Value
            getgenv().updateESP()
        end)

        -- Auto Category
        Tabs.Main:AddParagraph({
            Title = "Auto",
            Content = "Configure auto features"
        })

        -- Auto Play Toggle
        local AutoPlayToggle = Tabs.Main:AddToggle("AutoPlayToggle", {
            Title = "Auto Play",
            Default = getgenv().autoPlay or false
        })

        AutoPlayToggle:OnChanged(function()
            getgenv().autoPlay = Options.AutoPlayToggle.Value
            
            if getgenv().autoPlay then
                AutoPlayModule.runThread()
            else
                AutoPlayModule.finishThread()
            end
        end)

        -- Auto Vote Toggle
        local AutoVoteToggle = Tabs.Main:AddToggle("AutoVoteToggle", {
            Title = "Auto Vote",
            Default = getgenv().autoVote or false
        })

        AutoVoteToggle:OnChanged(function()
            getgenv().autoVote = Options.AutoVoteToggle.Value
        end)

        -- Auto Ability Toggle
        local AutoAbilityToggle = Tabs.Main:AddToggle("AutoAbilityToggle", {
            Title = "Auto Ability",
            Default = getgenv().autoAbility or false
        })

        AutoAbilityToggle:OnChanged(function()
            getgenv().autoAbility = Options.AutoAbilityToggle.Value
            getgenv().updateAutoAbility()
        end)

    end

    -- Skin tab content
    do

        -- Skin Changer Toggle
        local SkinChangerToggle = Tabs.Skin:AddToggle("SkinChangerToggle", {
            Title = "Skin Changer",
            Default = getgenv().skinChanger or false
        })

        SkinChangerToggle:OnChanged(function()
            getgenv().skinChanger = Options.SkinChangerToggle.Value
            if getgenv().skinChanger and getgenv().swordModel ~= "" then
                getgenv().updateSword()
            end
        end)

        -- Sword Name Input
        local SwordNameInput = Tabs.Skin:AddInput("SwordNameInput", {
            Title = "Sword Name",
            Default = getgenv().swordModel or "",
            Numeric = false,
            Finished = false
        })

        SwordNameInput:OnChanged(function()
            local Value = Options.SwordNameInput.Value
            getgenv().swordModel = Value
            getgenv().swordAnimations = Value
            getgenv().swordFX = Value
            if getgenv().skinChanger and Value ~= "" then
                getgenv().updateSword()
            end
        end)

    end

    -- Emote tab content
    do

        -- Emotes Enabled Toggle
        local EmotesEnabledToggle = Tabs.Emote:AddToggle("EmotesEnabledToggle", {
            Title = "Emotes Enabled",
            Default = getgenv().emotesEnabled or false
        })

        EmotesEnabledToggle:OnChanged(function()
            getgenv().emotesEnabled = Options.EmotesEnabledToggle.Value
            getgenv().updateEmotes()
        end)

        -- Loop Emote Toggle
        local LoopEmoteToggle = Tabs.Emote:AddToggle("LoopEmoteToggle", {
            Title = "Loop Emote",
            Default = getgenv().loopEmote or false
        })

        LoopEmoteToggle:OnChanged(function()
            getgenv().loopEmote = Options.LoopEmoteToggle.Value
        end)

        -- Emote Selection Dropdown
        local EmoteDropdown = Tabs.Emote:AddDropdown("EmoteDropdown", {
            Title = "Animation Type",
            Values = Emotes_Data,
            Default = getgenv().selectedEmote or (Emotes_Data[1] or ""),
            Multi = false,
            Callback = function(Value)
                getgenv().selectedEmote = Value
                getgenv().Animation.current = Value
                if getgenv().emotesEnabled then
                    getgenv().playEmoteAnimation(Value)
                end
            end
        })

        EmoteDropdown:OnChanged(function()
            local value = Options.EmoteDropdown.Value
            getgenv().selectedEmote = value
            getgenv().Animation.current = value
            if getgenv().emotesEnabled then
                getgenv().playEmoteAnimation(value)
            end
        end)
        
        -- Update dropdown when emotes are loaded
        task.spawn(function()
            task.wait(2)
            if #Emotes_Data > 0 then
                if Emotes_Data[1] and not getgenv().selectedEmote then
                    getgenv().selectedEmote = Emotes_Data[1]
                    EmoteDropdown:Set(Emotes_Data[1])
                end
            end
        end)

    end

    -- Blatant tab content
    do

        -- Auto Parry Toggle
        local AutoParryToggle = Tabs.Blatant:AddToggle("AutoParryToggle", {
            Title = "Auto Parry",
            Default = getgenv().autoparry or false
        })

        AutoParryToggle:OnChanged(function()
            getgenv().autoparry = Options.AutoParryToggle.Value
            getgenv().updateAutoParry()
        end)

        -- Parry Accuracy Slider
        local ParryAccuracySlider = Tabs.Blatant:AddSlider("ParryAccuracySlider", {
            Title = "Parry Accuracy",
            Description = "Adjust parry timing accuracy",
            Default = getgenv().parryAccuracy or 0.55,
            Min = 0.1,
            Max = 1.0,
            Rounding = 2,
            Callback = function(Value)
                getgenv().parryAccuracy = Value
            end
        })

        ParryAccuracySlider:OnChanged(function()
            getgenv().parryAccuracy = Options.ParryAccuracySlider.Value
        end)

        -- Parry Type Dropdown
        local ParryTypeDropdown = Tabs.Blatant:AddDropdown("ParryTypeDropdown", {
            Title = "Parry Type",
            Values = { "Camera", "Slowball", "Fastball", "Random", "Backwards", "Straight", "High", "Left", "Right", "Random Target" },
            Default = getgenv().parryType or "Camera",
            Multi = false,
            Callback = function(Value)
                getgenv().parryType = Value
            end
        })

        ParryTypeDropdown:OnChanged(function()
            local value = Options.ParryTypeDropdown.Value
            getgenv().parryType = value
        end)

        -- Random Accuracy Toggle
        local RandomAccuracyToggle = Tabs.Blatant:AddToggle("RandomAccuracyToggle", {
            Title = "Random Accuracy",
            Default = getgenv().randomAccuracy or false
        })

        RandomAccuracyToggle:OnChanged(function()
            getgenv().randomAccuracy = Options.RandomAccuracyToggle.Value
        end)

        -- Lobby Auto Parry Category
        Tabs.Blatant:AddParagraph({
            Title = "Lobby Auto Parry",
            Content = "Auto parry in lobby/training area"
        })

        -- Lobby Auto Parry Toggle
        local LobbyAutoParryToggle = Tabs.Blatant:AddToggle("LobbyAutoParryToggle", {
            Title = "Lobby Auto Parry",
            Default = getgenv().lobbyAutoParry or false
        })

        LobbyAutoParryToggle:OnChanged(function()
            getgenv().lobbyAutoParry = Options.LobbyAutoParryToggle.Value
            getgenv().updateLobbyAutoParry()
        end)

        -- Lobby Parry Accuracy Slider
        local LobbyParryAccuracySlider = Tabs.Blatant:AddSlider("LobbyParryAccuracySlider", {
            Title = "Lobby Parry Accuracy",
            Description = "Adjust lobby parry timing accuracy (1-100)",
            Default = getgenv().lobbyParryAccuracy or 100,
            Min = 1,
            Max = 100,
            Rounding = 0,
            Callback = function(Value)
                getgenv().lobbyParryAccuracy = Value
                getgenv().updateLobbyAutoParry()
            end
        })

        LobbyParryAccuracySlider:OnChanged(function()
            local value = Options.LobbyParryAccuracySlider.Value
            getgenv().lobbyParryAccuracy = value
            getgenv().updateLobbyAutoParry()
        end)

        -- Lobby Random Accuracy Toggle
        local LobbyRandomAccuracyToggle = Tabs.Blatant:AddToggle("LobbyRandomAccuracyToggle", {
            Title = "Lobby Random Accuracy",
            Default = getgenv().lobbyRandomAccuracy or false
        })

        LobbyRandomAccuracyToggle:OnChanged(function()
            getgenv().lobbyRandomAccuracy = Options.LobbyRandomAccuracyToggle.Value
        end)

        -- Lobby Parry Keypress Toggle
        local LobbyParryKeypressToggle = Tabs.Blatant:AddToggle("LobbyParryKeypressToggle", {
            Title = "Lobby Parry Keypress",
            Description = "Use F key instead of mouse click",
            Default = getgenv().lobbyParryKeypress or false
        })

        LobbyParryKeypressToggle:OnChanged(function()
            getgenv().lobbyParryKeypress = Options.LobbyParryKeypressToggle.Value
        end)

        -- New Category (Example - you can add your new features here)
        Tabs.Blatant:AddParagraph({
            Title = "Auto Spam",
            Content = "Configure auto spam settings"
        })

        -- Auto Spam Toggle
        local AutoSpamToggle = Tabs.Blatant:AddToggle("AutoSpamToggle", {
            Title = "Auto Spam",
            Default = getgenv().autoSpam or false
        })

        AutoSpamToggle:OnChanged(function()
            getgenv().autoSpam = Options.AutoSpamToggle.Value
            getgenv().updateAutoSpam()
        end)

        -- Auto Spam Key Selection Dropdown
        local keyMap = {
            ["E"] = Enum.KeyCode.E,
            ["Q"] = Enum.KeyCode.Q,
            ["R"] = Enum.KeyCode.R,
            ["F"] = Enum.KeyCode.F,
            ["G"] = Enum.KeyCode.G,
            ["T"] = Enum.KeyCode.T,
            ["Y"] = Enum.KeyCode.Y,
            ["X"] = Enum.KeyCode.X,
            ["C"] = Enum.KeyCode.C,
            ["V"] = Enum.KeyCode.V,
            ["Z"] = Enum.KeyCode.Z,
            ["Space"] = Enum.KeyCode.Space,
            ["Left Shift"] = Enum.KeyCode.LeftShift,
            ["Right Shift"] = Enum.KeyCode.RightShift,
            ["Left Control"] = Enum.KeyCode.LeftControl,
            ["Right Control"] = Enum.KeyCode.RightControl,
            ["Left Alt"] = Enum.KeyCode.LeftAlt,
            ["Right Alt"] = Enum.KeyCode.RightAlt
        }
        
        local function getKeyName(keyCode)
            for name, code in pairs(keyMap) do
                if code == keyCode then
                    return name
                end
            end
            return "E"
        end

        local AutoSpamKeyDropdown = Tabs.Blatant:AddDropdown("AutoSpamKeyDropdown", {
            Title = "Spam Key",
            Values = { "E", "Q", "R", "F", "G", "T", "Y", "X", "C", "V", "Z", "Space", "Left Shift", "Right Shift", "Left Control", "Right Control", "Left Alt", "Right Alt" },
            Default = getKeyName(getgenv().autoSpamKey or Enum.KeyCode.E),
            Multi = false,
            Callback = function(Value)
                if keyMap[Value] then
                    getgenv().autoSpamKey = keyMap[Value]
                    getgenv().updateAutoSpam()
                end
            end
        })

        AutoSpamKeyDropdown:OnChanged(function()
            local value = Options.AutoSpamKeyDropdown.Value
            if keyMap[value] then
                getgenv().autoSpamKey = keyMap[value]
                getgenv().updateAutoSpam()
            end
        end)

    end

    -- Sky tab content
    do

        -- Custom Sky Toggle
        local CustomSkyToggle = Tabs.Sky:AddToggle("CustomSkyToggle", {
            Title = "Custom Sky",
            Default = getgenv().customSky or false
        })

        CustomSkyToggle:OnChanged(function()
            getgenv().customSky = Options.CustomSkyToggle.Value
            getgenv().updateSky()
        end)

        -- Sky Selection Dropdown
        local SkyDropdown = Tabs.Sky:AddDropdown("SkyDropdown", {
            Title = "Select Sky",
            Values = { "Default", "Vaporwave", "Redshift", "Desert", "DaBaby", "Minecraft", "SpongeBob", "Skibidi", "Blaze", "Pussy Cat", "Among Us", "Space Wave", "Space Wave2", "Turquoise Wave", "Dark Night", "Bright Pink", "White Galaxy", "Blue Galaxy" },
            Default = getgenv().selectedSky or "Default",
            Multi = false,
            Callback = function(Value)
                getgenv().selectedSky = Value
                if getgenv().customSky then
                    getgenv().applySkybox(Value)
                end
            end
        })

        SkyDropdown:OnChanged(function()
            local value = Options.SkyDropdown.Value
            getgenv().selectedSky = value
            if getgenv().customSky then
                getgenv().applySkybox(value)
            end
        end)

    end

    -- Ball tab content
    do

        -- Ball Trail Toggle
        local BallTrailToggle = Tabs.Ball:AddToggle("BallTrailToggle", {
            Title = "Ball Trail",
            Default = getgenv().ballTrailEnabled or false
        })

        BallTrailToggle:OnChanged(function()
            getgenv().ballTrailEnabled = Options.BallTrailToggle.Value
            getgenv().updateBallTrail()
        end)

        -- Ball Trail Hue Slider
        local BallTrailHueSlider = Tabs.Ball:AddSlider("BallTrailHueSlider", {
            Title = "Ball Trail Hue",
            Description = "Adjust trail color hue",
            Default = getgenv().ballTrailHue or 0,
            Min = 0,
            Max = 360,
            Rounding = 0,
            Callback = function(Value)
                getgenv().ballTrailHue = Value
                if not getgenv().ballTrailRainbow then
                    local newColor = Color3.fromHSV(Value / 360, 1, 1)
                    getgenv().ballTrailColor = newColor
                end
            end
        })

        BallTrailHueSlider:OnChanged(function()
            local value = Options.BallTrailHueSlider.Value
            getgenv().ballTrailHue = value
            if not getgenv().ballTrailRainbow then
                local newColor = Color3.fromHSV(value / 360, 1, 1)
                getgenv().ballTrailColor = newColor
                -- Color will be updated in the next heartbeat cycle
            end
        end)

        -- Rainbow Trail Toggle
        local RainbowTrailToggle = Tabs.Ball:AddToggle("RainbowTrailToggle", {
            Title = "Rainbow Trail",
            Default = getgenv().ballTrailRainbow or false
        })

        RainbowTrailToggle:OnChanged(function()
            getgenv().ballTrailRainbow = Options.RainbowTrailToggle.Value
            -- If rainbow is disabled, update color based on hue
            if not getgenv().ballTrailRainbow then
                local newColor = Color3.fromHSV(getgenv().ballTrailHue / 360, 1, 1)
                getgenv().ballTrailColor = newColor
            end
        end)

        -- Particle Emitter Toggle
        local ParticleEmitterToggle = Tabs.Ball:AddToggle("ParticleEmitterToggle", {
            Title = "Particle Emitter",
            Default = getgenv().ballTrailParticle or false
        })

        ParticleEmitterToggle:OnChanged(function()
            getgenv().ballTrailParticle = Options.ParticleEmitterToggle.Value
            if getgenv().ballTrailEnabled then
                getgenv().updateBallTrail()
            end
        end)

        -- Glow Effect Toggle
        local GlowEffectToggle = Tabs.Ball:AddToggle("GlowEffectToggle", {
            Title = "Glow Effect",
            Default = getgenv().ballTrailGlow or false
        })

        GlowEffectToggle:OnChanged(function()
            getgenv().ballTrailGlow = Options.GlowEffectToggle.Value
            if getgenv().ballTrailEnabled then
                getgenv().updateBallTrail()
            end
        end)

    end

    -- Player tab content
    do

        -- Speed Toggle
        local SpeedToggle = Tabs.Player:AddToggle("SpeedToggle", {
            Title = "Speed",
            Default = getgenv().playerSpeedEnabled or false
        })

        SpeedToggle:OnChanged(function()
            getgenv().playerSpeedEnabled = Options.SpeedToggle.Value
            getgenv().updatePlayerSpeed()
        end)

        -- Speed Slider
        local SpeedSlider = Tabs.Player:AddSlider("SpeedSlider", {
            Title = "Speed Value",
            Description = "Adjust player walk speed",
            Default = getgenv().playerSpeed or 36,
            Min = 16,
            Max = 200,
            Rounding = 0,
            Callback = function(Value)
                getgenv().playerSpeed = Value
                if getgenv().playerSpeedEnabled then
                    getgenv().updatePlayerSpeed()
                end
            end
        })

        SpeedSlider:OnChanged(function()
            local value = Options.SpeedSlider.Value
            getgenv().playerSpeed = value
            if getgenv().playerSpeedEnabled then
                getgenv().updatePlayerSpeed()
            end
        end)

        -- Field of View Category
        Tabs.Player:AddParagraph({
            Title = "Field of View",
            Content = "Configure camera field of view"
        })

        -- FOV Toggle
        local FOVToggle = Tabs.Player:AddToggle("FOVToggle", {
            Title = "Field of View",
            Default = getgenv().fovEnabled or false
        })

        FOVToggle:OnChanged(function()
            getgenv().fovEnabled = Options.FOVToggle.Value
            getgenv().updateFOV()
        end)

        -- FOV Slider
        local FOVSlider = Tabs.Player:AddSlider("FOVSlider", {
            Title = "FOV Value",
            Description = "Adjust camera field of view",
            Default = getgenv().fov or 70,
            Min = 50,
            Max = 120,
            Rounding = 0,
            Callback = function(Value)
                getgenv().fov = Value
                if getgenv().fovEnabled then
                    getgenv().updateFOV()
                end
            end
        })

        FOVSlider:OnChanged(function()
            local value = Options.FOVSlider.Value
            getgenv().fov = value
            if getgenv().fovEnabled then
                getgenv().updateFOV()
            end
        end)

        -- Player Cosmetics Category
        Tabs.Player:AddParagraph({
            Title = "Player Cosmetics",
            Content = "Apply headless and korblox cosmetics"
        })

        -- Player Cosmetics Toggle
        local PlayerCosmeticsToggle = Tabs.Player:AddToggle("PlayerCosmeticsToggle", {
            Title = "Player Cosmetics",
            Default = getgenv().playerCosmeticsEnabled or false
        })

        PlayerCosmeticsToggle:OnChanged(function()
            getgenv().playerCosmeticsEnabled = Options.PlayerCosmeticsToggle.Value
            getgenv().updatePlayerCosmetics()
        end)

        -- Hit Sounds Category
        Tabs.Player:AddParagraph({
            Title = "Hit Sounds",
            Content = "Configure hit sounds"
        })

        -- Hit Sounds Toggle
        local HitSoundsToggle = Tabs.Player:AddToggle("HitSoundsToggle", {
            Title = "Hit Sounds",
            Default = getgenv().hitSoundsEnabled or false
        })

        HitSoundsToggle:OnChanged(function()
            getgenv().hitSoundsEnabled = Options.HitSoundsToggle.Value
        end)

        -- Hit Sound Volume Slider
        local HitSoundVolumeSlider = Tabs.Player:AddSlider("HitSoundVolumeSlider", {
            Title = "Hit Sound Volume",
            Description = "Adjust hit sound volume",
            Default = getgenv().hitSoundVolume or 5,
            Min = 1,
            Max = 10,
            Rounding = 0,
            Callback = function(Value)
                getgenv().hitSoundVolume = Value
                getgenv().updateHitSounds()
            end
        })

        HitSoundVolumeSlider:OnChanged(function()
            local value = Options.HitSoundVolumeSlider.Value
            getgenv().hitSoundVolume = value
            getgenv().updateHitSounds()
        end)

        -- Hit Sound Type Dropdown
        local HitSoundTypeDropdown = Tabs.Player:AddDropdown("HitSoundTypeDropdown", {
            Title = "Hit Sound Type",
            Values = { "Medal", "Fatality", "Skeet", "Switches", "Rust Headshot", "Neverlose Sound", "Bubble", "Laser", "Steve", "Call of Duty", "Bat", "TF2 Critical", "Saber", "Bameware" },
            Default = getgenv().hitSoundType or "Medal",
            Multi = false,
            Callback = function(Value)
                getgenv().hitSoundType = Value
                getgenv().updateHitSounds()
            end
        })

        HitSoundTypeDropdown:OnChanged(function()
            local value = Options.HitSoundTypeDropdown.Value
            getgenv().hitSoundType = value
            getgenv().updateHitSounds()
        end)

    end

    -- Shop tab content
    do

        -- Auto Sword Buy Toggle
        local AutoSwordBuyToggle = Tabs.Shop:AddToggle("AutoSwordBuyToggle", {
            Title = "Auto Sword Buy",
            Default = getgenv().autoSwordBuy or false
        })

        AutoSwordBuyToggle:OnChanged(function()
            getgenv().autoSwordBuy = Options.AutoSwordBuyToggle.Value
            getgenv().updateAutoSwordBuy()
        end)

    end

    -- Others tab content (Anti AFK)
    do

        -- Semi Immortal Toggle
        local SemiImmortalToggle = Tabs.Others:AddToggle("SemiImmortalToggle", {
            Title = "Semi Immortal (Beta)",
            Default = getgenv().semiImmortal or false
        })

        SemiImmortalToggle:OnChanged(function()
            getgenv().semiImmortal = Options.SemiImmortalToggle.Value
            getgenv().updateSemiImmortal()
        end)

        -- Anti AFK Category
        Tabs.Others:AddParagraph({
            Title = "Anti AFK",
            Content = "Configure anti AFK settings"
        })

        -- Initialize Anti-AFK globals
        getgenv().antiAFK = getgenv().antiAFK or false
        local antiAFKConnection = nil

        -- Anti-AFK Toggle
        local AntiAFKToggle = Tabs.Others:AddToggle("AntiAFKToggle", {
            Title = "Anti AFK",
            Default = getgenv().antiAFK or false
        })

        AntiAFKToggle:OnChanged(function()
            getgenv().antiAFK = Options.AntiAFKToggle.Value
            
            if getgenv().antiAFK then
                -- Disable existing Idled connections
                local GC = getconnections or get_signal_cons
                if GC then
                    for i, v in pairs(GC(plrs.LocalPlayer.Idled)) do
                        if v["Disable"] then
                            v["Disable"](v)
                        elseif v["Disconnect"] then
                            v["Disconnect"](v)
                        end
                    end
                end
                
                -- Create new Anti-AFK connection
                local VirtualUser = game:GetService("VirtualUser")
                antiAFKConnection = plrs.LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            else
                -- Disconnect Anti-AFK
                if antiAFKConnection then
                    antiAFKConnection:Disconnect()
                    antiAFKConnection = nil
                end
            end
        end)

    end

    -- Bugs & Reports tab content
    do

        -- Bug Report Category
        Tabs.BugsReports:AddParagraph({
            Title = "Bug Report",
            Content = "Report bugs and issues to help improve the script"
        })

        -- Bug Type Dropdown
        local BugTypeDropdown = Tabs.BugsReports:AddDropdown("BugTypeDropdown", {
            Title = "Bug Type",
            Values = { "Crash", "Feature Not Working", "UI Issue", "Performance Issue", "Other" },
            Default = "Other",
            Multi = false
        })

        -- Bug Message Input
        local BugMessageInput = Tabs.BugsReports:AddInput("BugMessageInput", {
            Title = "Bug Description",
            Default = "",
            Placeholder = "Describe the bug in detail...",
            Numeric = false,
            Finished = false
        })

        -- Function to send bug report
        local function sendBugReport()
            local bugType = Options.BugTypeDropdown.Value or "Other"
            local bugMessage = Options.BugMessageInput.Value or ""

            if bugMessage == "" or bugMessage == nil then
                return
            end

            -- Send bug report
            local callSuccess, result = pcall(function()
                return sendBugReportToDiscord(bugType, bugMessage)
            end)

            if callSuccess and result == true then
                Fluent:Notify({
                    Title = "Success",
                    Content = "Bug report sent successfully!",
                    Duration = 5
                })
            else
                warn("Bug report failed. Call success: " .. tostring(callSuccess) .. ", Result: " .. tostring(result))
            end
        end

        -- Send Bug Report Button (using Input with Finished callback)
        local SendButtonInput = Tabs.BugsReports:AddInput("SendButtonInput", {
            Title = "Send Bug Report",
            Default = "",
            Placeholder = "Click here and press Enter to send bug report...",
            Numeric = false,
            Finished = true,
            Callback = function(Value)
                sendBugReport()
            end
        })

        -- Add instruction paragraph
        Tabs.BugsReports:AddParagraph({
            Title = "How to Send",
            Content = "1. Select bug type\n2. Enter bug description\n3. Click 'Send Bug Report' field and press Enter"
        })

    end

    -- Addons:

    -- SaveManager (Allows you to have a configuration system)

    -- InterfaceManager (Allows you to have a interface managment system)



    -- Hand the library over to our managers

    SaveManager:SetLibrary(Fluent)

    InterfaceManager:SetLibrary(Fluent)



    -- Ignore keys that are used by ThemeManager.

    -- (we dont want configs to save themes, do we?)

    SaveManager:IgnoreThemeSettings()



    -- You can add indexes of elements the save manager should ignore

    SaveManager:SetIgnoreIndexes({"SkinChangerToggle", "SwordNameInput"})



    -- use case for doing it this way:

    -- a script hub could have themes in a global folder

    -- and game configs in a separate folder per game

    InterfaceManager:SetFolder("FluentScriptHub")

    SaveManager:SetFolder("FluentScriptHub/specific-game")



    InterfaceManager:BuildInterfaceSection(Tabs.Settings)

    SaveManager:BuildConfigSection(Tabs.Settings)




    Window:SelectTab(1)



    Fluent:Notify({

        Title = "Fluent",

        Content = "The script has been loaded.",

        Duration = 8

    })

    -- Generate random 6 letter code and show anti cheat bypass notification
    task.spawn(function()
        task.wait(1) -- Wait 1 second before showing the notification
        local function generateRandomCode()
            local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            local code = ""
            for i = 1, 6 do
                local randIndex = math.random(1, #chars)
                code = code .. string.sub(chars, randIndex, randIndex)
            end
            return code
        end

        local randomCode = generateRandomCode()

        Fluent:Notify({

            Title = "Anti Cheat Bypass",

            Content = "Anti cheat bypassed (" .. randomCode .. ")",

            Duration = 8

        })
    end)



    -- You can use the SaveManager:LoadAutoloadConfig() to load a config

    -- which has been marked to be one that auto loads!

    SaveManager:LoadAutoloadConfig()

        -- Initialize features if enabled (staggered loading to prevent freezing)
        task.spawn(function()
            task.wait(1) -- Initial wait for game to load
            
            -- Initialize hit sounds first (lightweight)
            getgenv().updateHitSounds()
            task.wait(0.1)
            
            -- Initialize Anti-AFK if enabled
            if getgenv().antiAFK then
                local GC = getconnections or get_signal_cons
                if GC then
                    for i, v in pairs(GC(plrs.LocalPlayer.Idled)) do
                        if v["Disable"] then
                            v["Disable"](v)
                        elseif v["Disconnect"] then
                            v["Disconnect"](v)
                        end
                    end
                end
                local VirtualUser = game:GetService("VirtualUser")
                plrs.LocalPlayer.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
            task.wait(0.1)
            
            -- Initialize FOV if enabled (lightweight)
            if getgenv().fovEnabled then
                getgenv().updateFOV()
            end
            task.wait(0.1)
            
            -- Initialize player speed if enabled (lightweight)
            if getgenv().playerSpeedEnabled then
                getgenv().updatePlayerSpeed()
            end
            task.wait(0.1)
            
            -- Initialize custom sky if enabled (lightweight)
            if getgenv().customSky then
                getgenv().updateSky()
            end
            task.wait(0.2)
            
            -- Initialize player cosmetics if enabled
            if getgenv().playerCosmeticsEnabled then
                getgenv().updatePlayerCosmetics()
            end
            task.wait(0.2)
            
            -- Initialize ball trail if enabled
            if getgenv().ballTrailEnabled then
                getgenv().updateBallTrail()
            end
            task.wait(0.2)
            
            -- Initialize emotes if enabled
            if getgenv().emotesEnabled then
                getgenv().updateEmotes()
            end
            task.wait(0.3)
            
            -- Initialize auto spam if enabled
            if getgenv().autoSpam then
                getgenv().updateAutoSpam()
            end
            task.wait(0.3)
            
            -- Initialize auto sword buy if enabled
            if getgenv().autoSwordBuy then
                getgenv().updateAutoSwordBuy()
            end
            task.wait(0.3)
            
            -- Initialize auto ability if enabled
            if getgenv().autoAbility then
                getgenv().updateAutoAbility()
            end
            task.wait(0.3)
            
            -- Initialize auto parry if enabled (more intensive)
            if getgenv().autoparry then
                getgenv().updateAutoParry()
            end
            task.wait(0.3)
            
            -- Initialize lobby auto parry if enabled (more intensive)
            if getgenv().lobbyAutoParry then
                getgenv().updateLobbyAutoParry()
            end
            task.wait(0.3)
            
            -- Initialize semi immortal if enabled (more intensive)
            if getgenv().semiImmortal then
                getgenv().updateSemiImmortal()
            end
            task.wait(0.3)
            
            -- Initialize Auto Play if enabled (most intensive, load last)
            if getgenv().autoPlay then
                AutoPlayModule.runThread()
            end
        end)
