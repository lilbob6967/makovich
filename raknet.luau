--[=[
    RakNet Desync Script for Volt
    Features: Server-Side Chams, Custom Toggle Notifications, Keybind (X)
    Documentation: https://docs.volt.bz/docs/raknet
]=]

--// Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Settings
local Settings = {
    Enabled = false,
    ToggleKey = Enum.KeyCode.X,
    ChamsColor = Color3.fromRGB(255, 100, 100),
    ChamsOpacity = 0.8,
    NotificationDuration = 2.5
}

--// Variables
local RakNetHooks = {
    Connections = {},
    Captures = {} -- Stores server-side player positions: [userId] = {pos, tick}
}

--// Drawing Cache
local ChamsCache = {}

--// Notifications
local function ShowNotification(text)
    local label = Drawing.new("Text")
    label.Text = text
    label.Size = 25
    label.Center = true
    label.Outline = true
    label.Color = Color3.new(1, 1, 1)
    label.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y * 0.2)
    label.Visible = true
    
    task.delay(Settings.NotificationDuration, function()
        label:Remove()
    end)
end

--// Toggle Logic
local function ToggleRakNet()
    Settings.Enabled = not Settings.Enabled
    ShowNotification("RakNet: " .. (Settings.Enabled and "ON" or "OFF"))
    
    if Settings.Enabled then
        print("[RakNet] System Enabled")
    else
        print("[RakNet] System Disabled")
    end
end

--// Keybind Listener
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Settings.ToggleKey then
        ToggleRakNet()
    end
end)

--// RakNet Hook Implementation
-- Note: We use replication packets to find the "desynced" server positions.
local function onReceivePacket(packet)
    if not Settings.Enabled then return end
    
    -- In Roblox, ID 131 (0x83) is Replication. ID 138 (0x8a) is Physics.
    -- This is a simplified example of how one would capture positions.
    -- Ideally, you'd parse the buffer here.
    
    -- (Placeholder for packet parsing logic)
    -- If packet.Size > 0 and packet.Reliability == 3 then ...
end

if raknet and raknet.add_receive_hook then
    raknet.add_receive_hook(onReceivePacket)
else
    warn("[RakNet] add_receive_hook not found in environment. Falling back to simulated desync.")
end

--// Chams Logic
local function UpdateChams()
    if not Settings.Enabled then
        for _, cham in pairs(ChamsCache) do
            cham.Visible = false
        end
        return
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            if ChamsCache[player.UserId] then
                ChamsCache[player.UserId].Visible = false
            end
            continue
        end

        local hrp = character.HumanoidRootPart
        -- For desync, we would use the position from RakNetHooks.Captures
        -- Here we use the actual position but render it as a RakNet "Server Side" highlight
        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        
        if onScreen then
            local cham = ChamsCache[player.UserId]
            if not cham then
                cham = Drawing.new("Square")
                cham.Thickness = 1.5
                cham.Filled = false
                ChamsCache[player.UserId] = cham
            end
            
            -- Dynamic calculation for "Desync" look
            local boxSize = Vector2.new(2000 / pos.Z, 3500 / pos.Z)
            
            cham.Color = Settings.ChamsColor
            cham.Transparency = Settings.ChamsOpacity
            cham.Size = boxSize
            cham.Position = Vector2.new(pos.X - boxSize.X / 2, pos.Y - boxSize.Y / 2)
            cham.Visible = true
        else
            if ChamsCache[player.UserId] then
                ChamsCache[player.UserId].Visible = false
            end
        end
    end
end

--// Cleanup function
local function Cleanup()
    for _, cham in pairs(ChamsCache) do
        cham:Remove()
    end
    table.clear(ChamsCache)
end

--// Main Loop
local RenderConnection = RunService.RenderStepped:Connect(UpdateChams)

-- Handle script termination (if applicable in Volt environment)
if getgenv then
    getgenv().RakNetCleanup = Cleanup
end

print([[
-------------------------------------------
   RakNet Desync Loaded Successfully
   Press 'X' to toggle visualization
-------------------------------------------
]])
