--// Services
local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--// Variables
local Player = PlayerService.LocalPlayer

-- Wait for necessary game assets
local Databases = ReplicatedStorage:WaitForChild("Databases")
local RandomKillSettings = require(Databases:WaitForChild("RandomKillSettings"))
local DataRemoteEvent = ReplicatedStorage:WaitForChild("DataRemoteEvent")

--// State
local cyclingActivated = false
local FORCE_STOP = false
local currentSignatureId = math.random(6200, 6600) -- Randomized start to avoid same-signature flags across sessions

--// Settings
local SETTINGS = {
    AttackCooldown = 0.12, -- Base delay between attacks
    CooldownJitter = 0.04, -- Random variance in timing (+/-)
    MaxDistance = math.huge, -- User requested INF (WARNING: High detection risk)
    PositionJitter = 0.4,  -- Studs of randomness added to target position
    SignaturePrefix = "Players." .. Player.Name .. ".PlayerScripts.ClientGunHandler:"
}

--// Utility Functions

-- Generates an incrementing signature to spoof legitimate script calls
local function getNextSignature()
    local sig = SETTINGS.SignaturePrefix .. tostring(currentSignatureId)
    currentSignatureId = currentSignatureId + 1
    return sig
end

-- Adds small position jitter to target position to avoid "exact coordinate" detection
local function getJitteredPosition(rootPart)
    local pos = rootPart.Position
    local j = SETTINGS.PositionJitter
    return pos + Vector3.new(
        math.random(-j * 100, j * 100) / 100,
        math.random(-j * 100, j * 100) / 100,
        math.random(-j * 100, j * 100) / 100
    )
end

-- Validates if a target is actually attackable
local function isValidTarget(target: Player)
    if target == Player or not target.Team then return false end
    
    -- Original team check provided by user
    if not RandomKillSettings.TeamKillCheck(Player, target.Team.Name, target) then
        return false
    end
    
    local character = target.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or humanoid.Health <= 0 or not rootPart then
        return false
    end
    
    -- Optional Distance Check (set to inf by user, but implemented for flexibility)
    if SETTINGS.MaxDistance ~= math.huge then
        local myRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot or (myRoot.Position - rootPart.Position).Magnitude > SETTINGS.MaxDistance then
            return false
        end
    end
    
    return true, humanoid, rootPart
end

-- Main Attack Logic
local function fireTwinAttack(humanoid, rootPart)
    local targetPos = getJitteredPosition(rootPart)
    
    -- Structured payload to match the game's expected multi-signature format
    local payload = {
        {
            "\x03", -- Separator
            getNextSignature(),
        },
        {
            humanoid,
            "Melee2",
        },
        {
            "\x03",
            getNextSignature(),
        },
        {
            humanoid,
            "Attack",
            [6] = targetPos, -- Target position at index 6
        },
    }
    
    DataRemoteEvent:FireServer(payload)
end

-- Cycling Loop
local function activatePlayerCycle()
    if FORCE_STOP then return end

    while cyclingActivated == true do
        if FORCE_STOP then break end

        local players = PlayerService:GetPlayers()
        for _, client in pairs(players) do
            if not cyclingActivated or FORCE_STOP then break end
            
            local valid, humanoid, rootPart = isValidTarget(client)
            if not valid then continue end

            -- Fire the spoofed attack
            fireTwinAttack(humanoid, rootPart)
            
            -- Randomized cooldown to avoid perfectly timed loop detection
            local waitTime = SETTINGS.AttackCooldown + (math.random(-SETTINGS.CooldownJitter * 1000, SETTINGS.CooldownJitter * 1000) / 1000)
            task.wait(math.max(0.05, waitTime))
        end

        task.wait(0.5) -- Breath before next cycle
    end
end

--// Inputs
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed or FORCE_STOP then return end
    
    -- M to Toggle
    if input.KeyCode == Enum.KeyCode.M then
        cyclingActivated = not cyclingActivated
        print(string.format("[TwinBypass]: Cycle %s!", cyclingActivated == true and "STARTED" or "STOPPED"))
        
        if cyclingActivated then
            task.spawn(activatePlayerCycle)
        end
        
    -- X to Kill Script
    elseif input.KeyCode == Enum.KeyCode.X then
        FORCE_STOP = true
        cyclingActivated = false
        print("[TwinBypass]: SCRIPT UNLOADED.")
    end
end)

print("[TwinBypass]: Loaded.")
print("  [M] Toggle Cycle")
print("  [X] Force Stop & Unload")
