-- KillAura | Press M to toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

--// Load Kill Remote Utility (Embedded version for portability)
local KillRemote = (function()
    local DataRemoteEvent = ReplicatedStorage:WaitForChild("DataRemoteEvent")
    local Module = {
        SignatureId = 6574,
        SignaturePrefix = "Players." .. LocalPlayer.Name .. ".PlayerScripts.ClientGunHandler:"
    }
    
    function Module.GetNextSignature()
        local sig = Module.SignaturePrefix .. tostring(Module.SignatureId)
        Module.SignatureId += 1
        return sig
    end

    function Module.Attack(humanoid, position)
        if not humanoid or not humanoid.Parent then return end
        DataRemoteEvent:FireServer({
            { "\x03", Module.GetNextSignature() },
            { humanoid, "Melee2" },
            { "\x03", Module.GetNextSignature() },
            { humanoid, "Attack", [6] = position or humanoid.Parent:GetPivot().Position }
        })
    end
    
    return Module
end)()

--// Settings
local Settings = {
    ToggleKey = Enum.KeyCode.M,
    LoopInterval = 0.1, -- Faster loop
    AttackCooldown = 0.25, -- Slightly faster attack
    MaxDistance = 50, -- Aura range
    IgnoreNames = {
        andrusca1003 = true,
    },
}

--// State
local Enabled = false
local LastAttackAt = {}

--// Helper Functions
local function getTargetState(player)
    if player == LocalPlayer or Settings.IgnoreNames[player.Name] then return nil end

    local character = player.Character
    if not character or character:GetAttribute("MutantType") then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or humanoid.Health <= 0 or not rootPart then return nil end
    
    -- Range Check
    local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
        and (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
    
    if distance and distance > Settings.MaxDistance then return nil end

    return character, humanoid, rootPart
end

local function canAttackTarget(player, now)
    local lastAttack = LastAttackAt[player]
    return not lastAttack or (now - lastAttack) >= Settings.AttackCooldown
end

--// Toggle Listener
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Settings.ToggleKey then
        Enabled = not Enabled
        print("[KillAura] " .. (Enabled and "ENABLED" or "DISABLED"))
    end
end)

--// Cleanup
Players.PlayerRemoving:Connect(function(player)
    LastAttackAt[player] = nil
end)

--// Main Loop
task.spawn(function()
    while true do
        task.wait(Settings.LoopInterval)
        if not Enabled then continue end

        local now = tick()
        for _, player in ipairs(Players:GetPlayers()) do
            local _, humanoid, rootPart = getTargetState(player)

            if humanoid and canAttackTarget(player, now) then
                LastAttackAt[player] = now
                KillRemote.Attack(humanoid, rootPart.Position)
            end
        end
    end
end)

print("[KillAura] Loaded. Press M to toggle.")
