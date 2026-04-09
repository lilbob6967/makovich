local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Event = ReplicatedStorage:WaitForChild("DataRemoteEvent")

-- Helper function to create border decorations (Lines and Dots)
local function createBorder(parent)
	local Border = Instance.new("Frame")
	Border.Name = "Border"
	Border.Size = UDim2.new(1, 0, 1, 0)
	Border.Position = UDim2.new(0, 0, 0, 0)
	Border.BackgroundTransparency = 1
	Border.BorderSizePixel = 1
	Border.BorderColor3 = Color3.fromRGB(27, 42, 53)
	Border.Parent = parent

	-- Create 4 Lines (edges)
	local linePositions = {
		UDim2.new(0, 0, 0, 0),           -- Top
		UDim2.new(0, 0, 1, -1),          -- Bottom
		UDim2.new(0, 0, 0, 0),           -- Left
		UDim2.new(1, -1, 0, 0)          -- Right
	}
	local lineSizes = {
		UDim2.new(1, 0, 0, 1),          -- Top
		UDim2.new(1, 0, 0, 1),          -- Bottom
		UDim2.new(0, 1, 1, 0),          -- Left
		UDim2.new(0, 1, 1, 0)           -- Right
	}

	for i = 1, 4 do
		local Line = Instance.new("Frame")
		Line.Name = "Line"
		Line.Size = lineSizes[i]
		Line.Position = linePositions[i]
		Line.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		Line.BorderSizePixel = 0
		Line.Parent = Border
	end

	-- Create 4 Dots (corners)
	local dotPositions = {
		UDim2.new(0, 0, 0, 0),           -- Top-left
		UDim2.new(1, -2, 0, 0),         -- Top-right
		UDim2.new(0, 0, 1, -2),          -- Bottom-left
		UDim2.new(1, -2, 1, -2)          -- Bottom-right
	}

	for _, pos in ipairs(dotPositions) do
		local Dot = Instance.new("Frame")
		Dot.Name = "Dot"
		Dot.Size = UDim2.new(0, 2, 0, 2)
		Dot.Position = pos
		Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Dot.BorderSizePixel = 0
		Dot.Parent = Border
	end

	return Border
end

-- Create the UI Structure 1:1 from StarterGui.Screengui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Screengui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
ScreenGui.ClipToDeviceSafeArea = true
ScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Container Frame
local Container = Instance.new("Frame")
Container.Name = "Container"
Container.Size = UDim2.new(0, 400, 0, 155)
Container.Position = UDim2.new(0.5, 0, 0.785369754, 0)
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Container.BackgroundTransparency = 0.7
Container.BorderSizePixel = 0
Container.BorderColor3 = Color3.fromRGB(27, 42, 53)
Container.ZIndex = 2
Container.Parent = ScreenGui

-- Container Border
createBorder(Container)

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0.163114607, 0)
Title.Position = UDim2.new(0, 0, 0, 2)
Title.BackgroundTransparency = 1
Title.Text = "Kill Player (Melee needed)"
Title.TextColor3 = Color3.fromRGB(255, 142, 12)
Title.TextSize = 34
Title.Font = Enum.Font.SourceSansSemibold
Title.TextWrapped = true
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.TextYAlignment = Enum.TextYAlignment.Center
Title.ZIndex = 3
Title.Parent = Container

-- Description
local Description = Instance.new("TextLabel")
Description.Name = "Description"
Description.Size = UDim2.new(0.95, 0, 0.125, 0)
Description.Position = UDim2.new(0.025, 0, 0.215, 0)
Description.BackgroundTransparency = 1
Description.Text = "Kill player from far away"
Description.TextColor3 = Color3.fromRGB(255, 255, 255)
Description.TextSize = 20
Description.Font = Enum.Font.SourceSansSemibold
Description.TextWrapped = true
Description.RichText = true
Description.TextXAlignment = Enum.TextXAlignment.Center
Description.TextYAlignment = Enum.TextYAlignment.Top
Description.ZIndex = 3
Description.Parent = Container

-- Username TextBox
local UsernameInput = Instance.new("TextBox")
UsernameInput.Name = "Username"
UsernameInput.Size = UDim2.new(0.7, -480, 0, 40)
UsernameInput.Position = UDim2.new(0, 300, 0, 57)
UsernameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
UsernameInput.BackgroundTransparency = 0.6
UsernameInput.BorderSizePixel = 0
UsernameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
UsernameInput.PlaceholderText = "Username"
UsernameInput.PlaceholderColor3 = Color3.fromRGB(178, 178, 178)
UsernameInput.Text = ""
UsernameInput.TextSize = 14
UsernameInput.Font = Enum.Font.SourceSans
UsernameInput.TextXAlignment = Enum.TextXAlignment.Center
UsernameInput.TextYAlignment = Enum.TextYAlignment.Center
UsernameInput.ClearTextOnFocus = false
UsernameInput.Active = true
UsernameInput.Selectable = true
UsernameInput.ZIndex = 1
UsernameInput.Parent = Container

-- Username Border
createBorder(UsernameInput)

-- Kill Button
local KillButton = Instance.new("TextButton")
KillButton.Name = "Kill"
KillButton.Size = UDim2.new(0.501400173, 0, 0.166451588, 0)
KillButton.Position = UDim2.new(0.49970001, 0, 0.750644803, 0)
KillButton.AnchorPoint = Vector2.new(0.5, 0.5)
KillButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
KillButton.BackgroundTransparency = 0.7
KillButton.BorderSizePixel = 0
KillButton.Text = ""
KillButton.AutoButtonColor = false
KillButton.ZIndex = 2
KillButton.Parent = Container

-- Kill Button Border
createBorder(KillButton)

-- Kill Button Label
local KillLabel = Instance.new("TextLabel")
KillLabel.Name = "Label"
KillLabel.Size = UDim2.new(1, 0, 0.8, 0)
KillLabel.Position = UDim2.new(0.0088888891, 0, 0.162500367, 0)
KillLabel.BackgroundTransparency = 1
KillLabel.Text = "Kill"
KillLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
KillLabel.TextScaled = true
KillLabel.Font = Enum.Font.SourceSansSemibold
KillLabel.TextXAlignment = Enum.TextXAlignment.Center
KillLabel.TextYAlignment = Enum.TextYAlignment.Center
KillLabel.ZIndex = 3
KillLabel.Parent = KillButton

-- Kill Button Gradient
local KillGradient = Instance.new("UIGradient")
KillGradient.Name = "UIGradient"
KillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
})
KillGradient.Rotation = -90
KillGradient.Parent = KillButton

--- Draggable Logic ---
local dragging, dragInput, dragStart, startPos
Container.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPos = true, input.Position, Container.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		Container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

--- Kill Logic with Partial Name ---
KillButton.MouseButton1Click:Connect(function()
	local name = UsernameInput.Text:lower()
	local target
	for _, p in pairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			target = p break
		end
	end

	if target and target.Character and target.Character:FindFirstChild("Humanoid") then
		local hum = target.Character.Humanoid
		local pos = target.Character.PrimaryPart.Position
		Event:FireServer({
			{"\x03", "Players.floatrevolution.PlayerScripts.ClientGunHandler:6574"},
			{hum, "Melee2"},
			{"\x03", "Players.floatrevolution.PlayerScripts.ClientGunHandler:6575"},
			{hum, "Attack", [6] = pos}
		})
	end
end)
