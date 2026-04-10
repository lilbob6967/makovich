--[=[
    Advanced Killing Remote Utility
    Based on captured DataRemoteEvent payload.
    Automates signature spoofing and multi-table attack sequence.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Search for the DataRemoteEvent if it's not in the standard path
local DataRemoteEvent = ReplicatedStorage:FindFirstChild("DataRemoteEvent") 
    or ReplicatedStorage:WaitForChild("DataRemoteEvent", 5)

if not DataRemoteEvent then
    warn("[KillRemote] DataRemoteEvent not found in ReplicatedStorage.")
    -- Fallback search (sometimes games hide remotes)
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == "DataRemoteEvent" then
            DataRemoteEvent = v
            break
        end
    end
end

local KillRemote = {}
KillRemote.SignatureId = 6574
KillRemote.SignaturePrefix = "Players." .. LocalPlayer.Name .. ".PlayerScripts.ClientGunHandler:"

--// Generates the spoofed stack trace signature
function KillRemote.GetNextSignature()
    local sig = KillRemote.SignaturePrefix .. tostring(KillRemote.SignatureId)
    KillRemote.SignatureId = KillRemote.SignatureId + 1
    return sig
end

--// Encapsulates the specific attack payload sequence
--// @param humanoid: The target Humanoid instance
--// @param position: Optional Vector3 hit position (defaults to target pivot)
function KillRemote.Attack(humanoid, position)
    if not humanoid or not humanoid.Parent or not DataRemoteEvent then 
        return false 
    end
    
    local targetPosition = position or (humanoid.Parent:IsA("Model") and humanoid.Parent:GetPivot().Position)
    
    local payload = {
        {
            "\x03", -- Magic byte / Separator
            KillRemote.GetNextSignature()
        },
        {
            humanoid,
            "Melee2"
        },
        {
            "\x03",
            KillRemote.GetNextSignature()
        },
        {
            humanoid,
            "Attack",
            [6] = targetPosition -- Hit position at index 6
        }
    }
    
    DataRemoteEvent:FireServer(payload)
    return true
end

--// Fast Attack / Kill All Helper
function KillRemote.KillTarget(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and humanoid.Health > 0 and rootPart then
        return KillRemote.Attack(humanoid, rootPart.Position)
    end
    return false
end

return KillRemote
