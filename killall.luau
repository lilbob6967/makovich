local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Event = game:GetService("ReplicatedStorage").DataRemoteEvent

local Running = true
local Enabled = false

-- Settings
local IgnoredTeams = {
    ["Pending"] = true,
    ["Patient"] = true
}

-- Connections
local Connections = {}

-- Toggle Listener
local inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    -- Z to Toggle active state
    if input.KeyCode == Enum.KeyCode.Z then
        Enabled = not Enabled
        print("[KillAll] " .. (Enabled and "ENABLED" or "DISABLED"))
    
    -- X to Disable/Unload script entirely
    elseif input.KeyCode == Enum.KeyCode.X then
        Running = false
        Enabled = false
        print("[KillAll] Script DISABLED and UNLOADED.")
        
        -- Cleanup connections
        for _, conn in pairs(Connections) do
            conn:Disconnect()
        end
        table.clear(Connections)
    end
end)
table.insert(Connections, inputConn)

-- Main Loop
task.spawn(function()
    while Running do
        task.wait(0.1)
        
        if Enabled and Running then
            for _, player in ipairs(Players:GetPlayers()) do
                if not Running then break end -- Exit check
                
                local character = player.Character
                local humanoid = character and character:FindFirstChild("Humanoid")
                local team = player.Team
                
                if player ~= Players.LocalPlayer 
                   and humanoid 
                   and not (team and IgnoredTeams[team.Name]) then
                    
                    Event:FireServer(
                        {
                            {
                                "\x03",
                                "Players.floatrevolution.PlayerScripts.ClientGunHandler:6574"
                            },
                            {
                                humanoid,
                                "Melee2"
                            },
                            {
                                "\x03",
                                "Players.floatrevolution.PlayerScripts.ClientGunHandler:6575"
                            },
                            {
                                humanoid,
                                "Attack",
                                [6] = Vector3.new(645.88989257812, -66.000923156738, -368.04232788086)
                            }
                        }
                    )
                end
            end
        end
    end
end)

print("[KillAll] Loaded.")
print("  [Z] Toggle Active State")
print("  [X] Disable/Unload Script")
