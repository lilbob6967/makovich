local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPEnabled = false
local AimbotEnabled = true
local Storage = {}

-- Team Categories
local Corporation = {
    ["Specialized Response Squad"] = true, ["Facility Security"] = true,
    ["Facility Intelligence"] = true, ["Facility Administration"] = true,
    ["Facility Director"] = true
}
local Hostiles = { ["Hostile Forces"] = true }
local Neutral = {
    ["Medical Staff"] = true, ["Technical Staff"] = true, ["Zeta Labs"] = true, 
    ["ZMTech"] = true
}

-- Perks
local PerkNames = {"Frost", "Tactician", "Brute", "Rogue", "Ghost", "Desperado"}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    -- Toggling ESP now effectively toggles Aimbot readiness as well
    if input.KeyCode == Enum.KeyCode.P then 
        ESPEnabled = not ESPEnabled 
    end
end)

local function IsVisible(targetPart)
    local character = LocalPlayer.Character
    if not character then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character, Camera}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position), rayParams)
    return not result or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function GetPlayerPerk(player)
    local data = player:FindFirstChild("Data")
    if data then
        for _, perkName in pairs(PerkNames) do
            local perk = data:FindFirstChild(perkName)
            if perk and perk:IsA("BoolValue") and perk.Value == true then
                return perkName
            end
        end
    end
    return "None"
end

local function GetEvolution(player)
    local char = player.Character
    local data = player:FindFirstChild("Data")
    local evoFolder = data and data:FindFirstChild("Evolution")
    
    local evoType = (char and char:GetAttribute("EvolutionType")) or (evoFolder and evoFolder:GetAttribute("EvolutionType"))
    if evoType and evoType ~= "" and evoType ~= "None" then
        return tostring(evoType)
    end

    local potential = (char and char:GetAttribute("PotentialEvolution")) or (evoFolder and evoFolder:FindFirstChild("PotentialEvolution"))
    if potential then
        local pVal = (typeof(potential) == "Instance") and potential.Value or potential
        if pVal and pVal ~= "" and pVal ~= "None" then
            return tostring(pVal)
        end
    end

    local advanced = (char and char:GetAttribute("HasReachedAdvancedMutation")) or (evoFolder and evoFolder:FindFirstChild("HasReachedAdvancedMutation"))
    if advanced and (advanced == true or (typeof(advanced) == "Instance" and advanced.Value == true)) then
        return "Advanced"
    end

    return "N/A"
end

local function GetZetaIcons(player)
    local char = player.Character
    if not char then return false, false, false end
    local head = char:FindFirstChild("Head")
    if head then
        local tag = head:FindFirstChild(player.Name)
        if tag and tag:IsA("BillboardGui") then
            local frame = tag:FindFirstChild("Frame")
            local icons = frame and frame:FindFirstChild("Icons")
            if icons then
                local traitor = icons:FindFirstChild("Traitor")
                local terminate = icons:FindFirstChild("Terminate")
                local isT = traitor and traitor.Visible
                local isTerm = terminate and terminate.Visible
                local isGT = false
                if isT and traitor.ImageColor3 == Color3.fromRGB(205, 84, 75) then
                    isGT = true
                    isT = false
                end
                return isT, isTerm, isGT
            end
        end
    end
    return false, false, false
end

local function UpdatePlayerStatus(player)
    local char = player.Character
    if not char then return end
    local isTraitor, isTerminate, isGT = GetZetaIcons(player)
    local hasPRM = char:FindFirstChild("PRM-MK1R") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("PRM-MK1R"))
    local activePerk = GetPlayerPerk(player)
    local activeEvo = GetEvolution(player)
    
    if Storage[player] then 
        Storage[player].IsTraitor = isTraitor
        Storage[player].IsTerminate = isTerminate
        Storage[player].IsGT = isGT
        Storage[player].HasPRM = hasPRM
        Storage[player].Perk = activePerk
        Storage[player].Evo = activeEvo
        Storage[player].IsProtected = char:FindFirstChildOfClass("ForceField") ~= nil
        
        local mutantType = char:GetAttribute("MutantType") or ""
        Storage[player].MutantType = mutantType
        Storage[player].IsApex = (mutantType == "Raptor" or mutantType == "Tank")
        Storage[player].IsZca = char:GetAttribute("IsZCA") == true
        
        local currentVest = char:GetAttribute("Armor") or 0
        local maxVest = char:GetAttribute("MaxArmor") or 0
        local currentHead = char:GetAttribute("HeadArmor") or 0
        local maxHead = char:GetAttribute("MaxHeadArmor") or 0

        Storage[player].TotalArmor = currentVest + currentHead
        Storage[player].MaxTotalArmor = maxVest + maxHead
    end
end

local function GetHostilityState(player)
    if not Storage[player] or not player.Team then return "None" end
    local s = Storage[player]
    if s.IsProtected then return "None" end
    
    if s.IsGT or s.IsZca or player.Team.Name == "Mutant" or (s.Evo and s.Evo ~= "N/A") or s.IsApex then return "GT" end
    
    local team = player.Team.Name
    if team == "Patient" then return s.IsTerminate and "HostilePatient" or "None"
    elseif Neutral[team] then return s.IsTraitor and "TraitorStaff" or "None"
    elseif Hostiles[team] then return "HostileForce"
    elseif Corporation[team] then return "Law" end
    return "None"
end

local function IsTargetHostile(otherPlayer)
    local me, them = GetHostilityState(LocalPlayer), GetHostilityState(otherPlayer)
    local hum = otherPlayer.Character and otherPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    if me == "None" then return false end
    if me == "GT" or them == "GT" then return true end
    if me == "Law" then return (them == "HostilePatient" or them == "TraitorStaff" or them == "HostileForce") end
    if (me == "HostilePatient" or me == "TraitorStaff") and them == "Law" then return true end
    if me == "HostileForce" and them == "Law" then return true end
    return false
end

local function RemoveESP(player)
    if Storage[player] and Storage[player].Drawings then
        for _, obj in pairs(Storage[player].Drawings) do obj.Visible = false; obj:Remove() end
        if Storage[player].Connection then Storage[player].Connection:Disconnect() end
        Storage[player] = nil
    end
end

local function CreateESP(player)
    if player.Team and player.Team.Name == "Pending" then return end
    
    RemoveESP(player)
    local drawings = {
        BarOutline = Drawing.new("Square"),
        Bar = Drawing.new("Square"),
        ArmorOutline = Drawing.new("Square"),
        ArmorBar = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Status = Drawing.new("Text"),
        EvoTag = Drawing.new("Text"),
        TypeTag = Drawing.new("Text"),
        PerkTag = Drawing.new("Text"),
        PRMTag = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }
    
    for _, tag in pairs({drawings.Name, drawings.EvoTag, drawings.TypeTag, drawings.PerkTag, drawings.Status, drawings.PRMTag, drawings.Distance}) do
        tag.Center = true; tag.Outline = true
    end
    
    drawings.Status.Color = Color3.fromRGB(255, 0, 0)
    drawings.EvoTag.Color = Color3.new(1, 1, 1)
    drawings.TypeTag.Color = Color3.new(1, 1, 1)
    drawings.PerkTag.Color = Color3.new(1, 1, 1)
    drawings.PRMTag.Color = Color3.fromRGB(160, 160, 160)
    drawings.BarOutline.Color = Color3.new(0,0,0)
    drawings.Bar.Filled = true; drawings.Bar.Color = Color3.new(0, 1, 0)
    drawings.ArmorOutline.Color = Color3.new(0,0,0)
    drawings.ArmorBar.Filled = true; drawings.ArmorBar.Color = Color3.fromRGB(150, 150, 150)

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if player.Team and player.Team.Name == "Pending" then
            RemoveESP(player)
            return
        end

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if ESPEnabled and hrp and hum and hum.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                local s = Storage[player]
                if not s then return end
                
                local teamColor = player.TeamColor.Color
                local scale = math.clamp(1 - (dist / 400), 0.7, 1) 
                local fontSize = 15 * scale
                local barWidth = 65 * scale 

                local currentY = pos.Y - 35
                local isMutant = s.IsZca or (player.Team and player.Team.Name == "Mutant")

                if s.IsApex then
                    drawings.Status.Visible = true; drawings.Status.Text = "APEX"
                    drawings.Status.Color = Color3.fromRGB(255, 0, 0)
                elseif isMutant then
                    drawings.Status.Visible = true; drawings.Status.Text = "MUTANT"
                    drawings.Status.Color = Color3.fromRGB(255, 0, 0)
                elseif s.IsGT then
                    drawings.Status.Visible = true; drawings.Status.Text = "GLOBAL TRAITOR"
                    drawings.Status.Color = Color3.fromRGB(205, 84, 75)
                elseif s.IsTraitor or s.IsTerminate then
                    drawings.Status.Visible = true; drawings.Status.Text = s.IsTraitor and "TRAITOR" or "HOSTILE"
                    drawings.Status.Color = Color3.fromRGB(255, 0, 0)
                else 
                    drawings.Status.Visible = false 
                end

                if drawings.Status.Visible then
                    drawings.Status.Size = fontSize
                    drawings.Status.Position = Vector2.new(pos.X, currentY)
                    currentY = currentY + fontSize
                end

                drawings.Name.Visible = true; drawings.Name.Text = player.Name; drawings.Name.Size = fontSize; drawings.Name.Color = teamColor; drawings.Name.Position = Vector2.new(pos.X, currentY)
                currentY = currentY + fontSize + 2

                local healthPerc = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                drawings.BarOutline.Visible = true; drawings.BarOutline.Size = Vector2.new(barWidth, 5); drawings.BarOutline.Position = Vector2.new(pos.X - barWidth/2, currentY)
                drawings.Bar.Visible = true; drawings.Bar.Size = Vector2.new((barWidth-2) * healthPerc, 3); drawings.Bar.Position = Vector2.new(pos.X - barWidth/2 + 1, currentY + 1)
                currentY = currentY + 6 

                if s.MaxTotalArmor and s.MaxTotalArmor > 0 then
                    local armorPerc = math.clamp(s.TotalArmor / s.MaxTotalArmor, 0, 1)
                    drawings.ArmorOutline.Visible = true; drawings.ArmorOutline.Size = Vector2.new(barWidth, 5); drawings.ArmorOutline.Position = Vector2.new(pos.X - barWidth/2, currentY)
                    drawings.ArmorBar.Visible = true; drawings.ArmorBar.Size = Vector2.new((barWidth-2) * armorPerc, 3); drawings.ArmorBar.Position = Vector2.new(pos.X - barWidth/2 + 1, currentY + 1)
                    currentY = currentY + 10
                else
                    drawings.ArmorOutline.Visible = false; drawings.ArmorBar.Visible = false
                end

                if s.IsApex then
                    drawings.EvoTag.Visible = false
                    drawings.TypeTag.Visible = true; drawings.TypeTag.Text = "Type: " .. s.MutantType
                    drawings.TypeTag.Size = fontSize; drawings.TypeTag.Position = Vector2.new(pos.X, currentY); currentY = currentY + fontSize
                else
                    drawings.TypeTag.Visible = false
                    if s.Evo and s.Evo ~= "N/A" then
                        drawings.EvoTag.Visible = true; drawings.EvoTag.Text = "Evo: " .. s.Evo
                        drawings.EvoTag.Size = fontSize; drawings.EvoTag.Position = Vector2.new(pos.X, currentY); currentY = currentY + fontSize
                    else drawings.EvoTag.Visible = false end
                end

                if not isMutant then
                    drawings.PerkTag.Visible = true; drawings.PerkTag.Text = "Perks: " .. (s.Perk or "None")
                    drawings.PerkTag.Size = fontSize; drawings.PerkTag.Position = Vector2.new(pos.X, currentY); currentY = currentY + fontSize
                else drawings.PerkTag.Visible = false end

                if s.HasPRM then
                    drawings.PRMTag.Visible = true; drawings.PRMTag.Text = "PRM"; drawings.PRMTag.Size = fontSize; drawings.PRMTag.Position = Vector2.new(pos.X, currentY); currentY = currentY + fontSize
                else drawings.PRMTag.Visible = false end

                drawings.Distance.Visible = true; drawings.Distance.Text = math.floor(dist) .. "m"; drawings.Distance.Size = fontSize + 2; drawings.Distance.Color = teamColor; drawings.Distance.Position = Vector2.new(pos.X, currentY + 2)
                return
            end
        end
        for _, obj in pairs(drawings) do obj.Visible = false end
    end)
    Storage[player] = {Drawings = drawings, Connection = connection}
end

-- AIMBOT SYSTEM (SYNCED WITH ESP)
RunService.RenderStepped:Connect(function()
    -- Check if BOTH Aimbot and ESP are enabled, and right-click is held
    if ESPEnabled and AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local closestDist = math.huge
        local finalTargetPos = nil
        local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name ~= "Pending" and IsTargetHostile(player) then
                local char = player.Character
                local head = char and char:FindFirstChild("Head")

                if head and IsVisible(head) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distFromCenter < closestDist then
                            closestDist = distFromCenter
                            finalTargetPos = head.Position + Vector3.new(0, 0.4, 0)
                        end
                    end
                end
            end
        end

        if finalTargetPos then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, finalTargetPos)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        UpdatePlayerStatus(LocalPlayer)
        for _, p in pairs(Players:GetPlayers()) do 
            if p ~= LocalPlayer then 
                UpdatePlayerStatus(p) 
            end 
        end
    end
end)

local function SetupPlayer(p)
    if p == LocalPlayer then Storage[p] = {} return end
    
    p:GetPropertyChangedSignal("Team"):Connect(function()
        if p.Team and p.Team.Name ~= "Pending" then
            task.wait(0.5)
            CreateESP(p)
        else
            RemoveESP(p)
        end
    end)

    p.CharacterAdded:Connect(function() 
        task.wait(0.5) 
        CreateESP(p) 
    end)
    
    if p.Character then CreateESP(p) end
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(RemoveESP)
for _, p in pairs(Players:GetPlayers()) do SetupPlayer(p) end
