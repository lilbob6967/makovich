--[=[
    Auto-Farm Script for PowerBoxes & GasPipes
    Captures: Cobalt (DataRemoteEvent)
    Features: Dynamic Username, TP Under Object, x20 Loop with 0.05s Delay, "Broken" Check
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local DataRemoteEvent = ReplicatedStorage:WaitForChild("DataRemoteEvent")

--// Settings
local Settings = {
    AttackInterval = 0.05,
    AttackCount = 20,
    TeleportOffset = Vector3.new(0, -5, 0) -- 5 studs below
}

--// Utility Functions
local function GetTargets()
    local targets = {}
    local sectors = Workspace:FindFirstChild("Facility") and Workspace.Facility:FindFirstChild("Sectors")
    
    if sectors then
        for _, sector in pairs(sectors:GetChildren()) do
            -- Look for PowerBoxes
            local powerFolder = sector:FindFirstChild("Interactions") and sector.Interactions:FindFirstChild("Power")
            local powerBoxes = powerFolder and powerFolder:FindFirstChild("PowerBoxes")
            if powerBoxes then
                for _, box in pairs(powerBoxes:GetChildren()) do
                    if (box.Name == "PowerBoxTurret" or box.Name == "PowerBoxGate") and not box:GetAttribute("Broken") then
                        table.insert(targets, box)
                    end
                end
            end
            
            -- Look for GasPipes
            local gasPipes = sector:FindFirstChild("Interactions") and sector.Interactions:FindFirstChild("GasPipes")
            if gasPipes then
                for _, pipe in pairs(gasPipes:GetChildren()) do
                    if not pipe:GetAttribute("Broken") then
                        table.insert(targets, pipe)
                    end
                end
            end
        end
    end
    
    return targets
end

--// Remote Payload Generator
local function FireAttack(target, actionType)
    local timestamp = tick()
    local sig1 = "Players." .. LocalPlayer.Name .. ".PlayerScripts.ClientGunHandler:" .. math.random(6000, 6650)
    local sig2 = "Players." .. LocalPlayer.Name .. ".PlayerScripts.ClientGunHandler:" .. math.random(6651, 7000)
    
    local payload = {
        {
            "\x03",
            sig1
        },
        {
            target,
            actionType,
            [8] = timestamp
        },
        {
            "\x03",
            sig2
        },
        {
            target,
            "Melee2"
        }
    }
    
    DataRemoteEvent:FireServer(payload)
end

--// Main Farm Loop
local function RunFarm()
    print("[AutoFarm] Starting...")
    local targets = GetTargets()
    print("[AutoFarm] Found " .. #targets .. " targets.")

    for _, target in pairs(targets) do
        if target:GetAttribute("Broken") then continue end

        -- Teleport
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            print("[AutoFarm] Attacking: " .. target.Name)
            character.HumanoidRootPart.CFrame = target:GetPivot() * CFrame.new(Settings.TeleportOffset)
            task.wait(0.2) -- Brief wait for TP stability
            
            -- Attack Loop
            local action = target.Name:find("GasPipe") and "DamageGasPipe" or "DamagePowerBox"
            
            for i = 1, Settings.AttackCount do
                if target:GetAttribute("Broken") then
                    print("[AutoFarm] " .. target.Name .. " broken early.")
                    break 
                end
                
                FireAttack(target, action)
                task.wait(Settings.AttackInterval)
            end
        end
    end
    
    print("[AutoFarm] Finished!")
end

-- Run it
RunFarm()
