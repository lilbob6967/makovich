--[[
    Studio ESP LocalScript

    Drop this into StarterPlayer > StarterPlayerScripts.
    It uses built-in Roblox instances only, so it works in Studio without executor APIs.

    Quick usage:
    1. Tweak CONFIG below.
    2. Leave `controller:TrackPlayers()` enabled for player ESP.
    3. Call `controller:Attach(workspace.SomeModel, { Label = "Boss" })` for NPCs or objects.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Enabled = true,
    IncludeLocalPlayer = false,
    TeamCheck = false,

    UseHighlight = true,
    UseBillboard = true,
    ShowNames = true,
    ShowDistance = true,
    ShowHealth = true,

    MaxDistance = 1500,
    UpdateRate = 0.08,

    HighlightFillColor = Color3.fromRGB(255, 85, 85),
    HighlightOutlineColor = Color3.fromRGB(255, 255, 255),
    HighlightFillTransparency = 0.75,
    HighlightOutlineTransparency = 0.05,
    HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,

    TagTextColor = Color3.fromRGB(255, 255, 255),
    TagStrokeColor = Color3.fromRGB(15, 15, 15),
    TagBackgroundColor = Color3.fromRGB(12, 12, 12),
    TagBackgroundTransparency = 0.35,
}

local DEFAULT_BILLBOARD_SIZE = UDim2.fromOffset(190, 44)
local DEFAULT_BILLBOARD_OFFSET = Vector3.new(0, 3.6, 0)

local ESP = {}
ESP.__index = ESP

local function cloneConfig(overrides)
    local resolved = {}

    for key, value in pairs(CONFIG) do
        resolved[key] = value
    end

    if overrides then
        for key, value in pairs(overrides) do
            resolved[key] = value
        end
    end

    return resolved
end

local function disconnectAll(connectionList)
    if not connectionList then
        return
    end

    for _, connection in ipairs(connectionList) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
end

function ESP.new(overrides)
    local self = setmetatable({}, ESP)

    self.Config = cloneConfig(overrides)
    self.Enabled = self.Config.Enabled
    self.Entries = {}
    self.PlayerConnections = {}
    self.Connections = {}
    self.Accumulator = 0

    table.insert(self.Connections, RunService.RenderStepped:Connect(function(deltaTime)
        self.Accumulator += deltaTime

        if self.Accumulator < self.Config.UpdateRate then
            return
        end

        self.Accumulator = 0
        self:Refresh()
    end))

    return self
end

function ESP:GetLocalOrigin()
    local character = LocalPlayer.Character
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
        if rootPart and rootPart:IsA("BasePart") then
            return rootPart.Position
        end
    end

    local camera = workspace.CurrentCamera
    if camera then
        return camera.CFrame.Position
    end

    return Vector3.zero
end

function ESP:ResolveRoot(target)
    if not target then
        return nil
    end

    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        if rootPart and rootPart:IsA("BasePart") then
            return rootPart
        end

        return target:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

function ESP:ResolveHumanoid(target)
    if target and target:IsA("Model") then
        return target:FindFirstChildOfClass("Humanoid")
    end

    return nil
end

function ESP:GetDisplayColor(player, customColor)
    if customColor then
        return customColor
    end

    if player and player.Team ~= nil then
        return player.TeamColor.Color
    end

    return self.Config.HighlightFillColor
end

function ESP:CreateHighlight(target, color)
    local highlight = Instance.new("Highlight")
    highlight.Name = "StudioESPHighlight"
    highlight.Adornee = target
    highlight.DepthMode = self.Config.HighlightDepthMode
    highlight.FillColor = color
    highlight.FillTransparency = self.Config.HighlightFillTransparency
    highlight.OutlineColor = self.Config.HighlightOutlineColor
    highlight.OutlineTransparency = self.Config.HighlightOutlineTransparency
    highlight.Enabled = true
    highlight.Parent = target

    return highlight
end

function ESP:CreateBillboard(parentInstance, rootPart, color)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "StudioESPBillboard"
    billboard.Adornee = rootPart
    billboard.AlwaysOnTop = true
    billboard.Size = DEFAULT_BILLBOARD_SIZE
    billboard.StudsOffsetWorldSpace = DEFAULT_BILLBOARD_OFFSET
    billboard.MaxDistance = self.Config.MaxDistance
    billboard.Parent = parentInstance

    local frame = Instance.new("Frame")
    frame.Name = "Container"
    frame.BackgroundColor3 = self.Config.TagBackgroundColor
    frame.BackgroundTransparency = self.Config.TagBackgroundTransparency
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromScale(1, 1)
    frame.Parent = billboard

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamSemibold
    label.TextColor3 = self.Config.TagTextColor
    label.TextSize = 13
    label.TextStrokeColor3 = self.Config.TagStrokeColor
    label.TextStrokeTransparency = 0.15
    label.TextWrapped = true
    label.Parent = frame

    return billboard, label, stroke
end

function ESP:DestroyVisuals(entry)
    if not entry then
        return
    end

    if entry.Highlight then
        entry.Highlight:Destroy()
        entry.Highlight = nil
    end

    if entry.Billboard then
        entry.Billboard:Destroy()
        entry.Billboard = nil
        entry.Label = nil
        entry.Stroke = nil
    end
end

function ESP:Detach(subject)
    local entry = self.Entries[subject]
    if not entry then
        return
    end

    self:DestroyVisuals(entry)
    self.Entries[subject] = nil
end

function ESP:BuildLabel(entry, distance)
    local lines = {}
    local stats = {}

    if self.Config.ShowNames then
        local baseName = entry.CustomLabel or entry.Target.Name

        if entry.Player then
            baseName = entry.CustomLabel or entry.Player.DisplayName
            if entry.Player.DisplayName ~= entry.Player.Name then
                baseName = entry.CustomLabel or string.format("%s (@%s)", entry.Player.DisplayName, entry.Player.Name)
            end
        end

        table.insert(lines, baseName)
    end

    if self.Config.ShowDistance and distance then
        table.insert(stats, string.format("%dm", math.floor(distance + 0.5)))
    end

    if self.Config.ShowHealth and entry.Humanoid then
        table.insert(stats, string.format("%d HP", math.max(0, math.floor(entry.Humanoid.Health + 0.5))))
    end

    if #stats > 0 then
        table.insert(lines, table.concat(stats, " | "))
    end

    return table.concat(lines, "\n")
end

function ESP:SetEntryVisible(entry, isVisible)
    if entry.Highlight then
        entry.Highlight.Enabled = isVisible
    end

    if entry.Billboard then
        entry.Billboard.Enabled = isVisible
    end
end

function ESP:ShouldHide(entry, distance)
    if not self.Enabled then
        return true
    end

    if entry.Player then
        if entry.Player == LocalPlayer and not self.Config.IncludeLocalPlayer then
            return true
        end

        if self.Config.TeamCheck and entry.Player ~= LocalPlayer and LocalPlayer.Team ~= nil and entry.Player.Team == LocalPlayer.Team then
            return true
        end
    end

    if not entry.Target.Parent then
        return true
    end

    if not entry.RootPart or not entry.RootPart.Parent then
        return true
    end

    if distance and distance > self.Config.MaxDistance then
        return true
    end

    return false
end

function ESP:EnsureEntry(subject, target, options)
    local existing = self.Entries[subject]
    if existing and existing.Target ~= target then
        self:Detach(subject)
        existing = nil
    end

    local resolvedOptions = options or {}
    local rootPart = self:ResolveRoot(target)
    if not rootPart then
        return nil
    end

    local entry = existing or {}
    local displayColor = self:GetDisplayColor(resolvedOptions.Player, resolvedOptions.Color)

    entry.Subject = subject
    entry.Target = target
    entry.RootPart = rootPart
    entry.Humanoid = self:ResolveHumanoid(target)
    entry.Player = resolvedOptions.Player
    entry.CustomLabel = resolvedOptions.Label
    entry.DisplayColor = displayColor

    if self.Config.UseHighlight then
        if not entry.Highlight then
            entry.Highlight = self:CreateHighlight(target, displayColor)
        else
            entry.Highlight.Adornee = target
            entry.Highlight.FillColor = displayColor
            entry.Highlight.OutlineColor = self.Config.HighlightOutlineColor
        end
    elseif entry.Highlight then
        entry.Highlight:Destroy()
        entry.Highlight = nil
    end

    if self.Config.UseBillboard then
        if not entry.Billboard then
            entry.Billboard, entry.Label, entry.Stroke = self:CreateBillboard(target, rootPart, displayColor)
        else
            entry.Billboard.Adornee = rootPart
            entry.Billboard.MaxDistance = self.Config.MaxDistance
            if entry.Stroke then
                entry.Stroke.Color = displayColor
            end
        end
    elseif entry.Billboard then
        entry.Billboard:Destroy()
        entry.Billboard = nil
        entry.Label = nil
        entry.Stroke = nil
    end

    self.Entries[subject] = entry
    return entry
end

function ESP:Attach(target, options)
    if not target or (not target:IsA("Model") and not target:IsA("BasePart")) then
        warn("ESP:Attach expects a Model or BasePart")
        return
    end

    return self:EnsureEntry(target, target, options)
end

function ESP:TrackPlayer(player)
    if self.PlayerConnections[player] then
        return
    end

    local connections = {}

    local function attachCharacter(character)
        local label = player.DisplayName
        local color = self:GetDisplayColor(player)

        self:EnsureEntry(player, character, {
            Player = player,
            Label = label,
            Color = color,
        })
    end

    table.insert(connections, player.CharacterAdded:Connect(attachCharacter))
    table.insert(connections, player.CharacterRemoving:Connect(function()
        self:Detach(player)
    end))
    table.insert(connections, player.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            self:UntrackPlayer(player)
        end
    end))

    self.PlayerConnections[player] = connections

    if player.Character then
        attachCharacter(player.Character)
    end
end

function ESP:UntrackPlayer(player)
    disconnectAll(self.PlayerConnections[player])
    self.PlayerConnections[player] = nil
    self:Detach(player)
end

function ESP:TrackPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        self:TrackPlayer(player)
    end

    if self.PlayersAddedConnection and self.PlayersRemovingConnection then
        return
    end

    self.PlayersAddedConnection = Players.PlayerAdded:Connect(function(player)
        self:TrackPlayer(player)
    end)

    self.PlayersRemovingConnection = Players.PlayerRemoving:Connect(function(player)
        self:UntrackPlayer(player)
    end)
end

function ESP:SetEnabled(isEnabled)
    self.Enabled = isEnabled

    if not isEnabled then
        for _, entry in pairs(self.Entries) do
            self:SetEntryVisible(entry, false)
        end
    else
        self:Refresh()
    end
end

function ESP:Refresh()
    local origin = self:GetLocalOrigin()

    for subject, entry in pairs(self.Entries) do
        if not entry.Player and not entry.Target.Parent then
            self:Detach(subject)
            continue
        end

        if entry.Player and entry.Player.Character and entry.Target ~= entry.Player.Character then
            self:EnsureEntry(subject, entry.Player.Character, {
                Player = entry.Player,
                Label = entry.CustomLabel,
                Color = entry.DisplayColor,
            })
            entry = self.Entries[subject]
        end

        if not entry then
            continue
        end

        entry.RootPart = self:ResolveRoot(entry.Target)
        entry.Humanoid = self:ResolveHumanoid(entry.Target)

        if entry.Player then
            entry.DisplayColor = self:GetDisplayColor(entry.Player)
        end

        local distance
        if entry.RootPart then
            distance = (entry.RootPart.Position - origin).Magnitude
        end

        local shouldHide = self:ShouldHide(entry, distance)
        self:SetEntryVisible(entry, not shouldHide)

        if shouldHide then
            continue
        end

        if entry.Highlight then
            entry.Highlight.FillColor = entry.DisplayColor
            entry.Highlight.OutlineColor = self.Config.HighlightOutlineColor
        end

        if entry.Billboard and entry.Label then
            entry.Billboard.Adornee = entry.RootPart
            entry.Billboard.MaxDistance = self.Config.MaxDistance
            entry.Label.Text = self:BuildLabel(entry, distance)

            if entry.Stroke then
                entry.Stroke.Color = entry.DisplayColor
            end
        end
    end
end

function ESP:Destroy()
    if self.PlayersAddedConnection and self.PlayersAddedConnection.Connected then
        self.PlayersAddedConnection:Disconnect()
    end

    if self.PlayersRemovingConnection and self.PlayersRemovingConnection.Connected then
        self.PlayersRemovingConnection:Disconnect()
    end

    for player, connections in pairs(self.PlayerConnections) do
        disconnectAll(connections)
        self.PlayerConnections[player] = nil
    end

    for subject in pairs(self.Entries) do
        self:Detach(subject)
    end

    disconnectAll(self.Connections)
end

local controller = ESP.new()
controller:TrackPlayers()

-- Optional examples:
-- controller:Attach(workspace:WaitForChild("Boss"), { Label = "Boss", Color = Color3.fromRGB(255, 170, 0) })
-- controller:SetEnabled(false)
