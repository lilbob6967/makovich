--[[
    Futuristic control-panel UI mockup.
    Drop this LocalScript into StarterPlayerScripts or StarterGui.
    This script only creates the interface and decorative interactions.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
if not localPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    localPlayer = Players.LocalPlayer
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

local existingGui = playerGui:FindFirstChild("VapeDesktopMockup")
if existingGui then
    existingGui:Destroy()
end

local THEME = {
    Background = Color3.fromRGB(20, 17, 20),
    Window = Color3.fromRGB(25, 22, 26),
    Surface = Color3.fromRGB(24, 16, 24),
    Panel = Color3.fromRGB(32, 32, 40),
    Shadow = Color3.fromRGB(16, 16, 16),
    Accent = Color3.fromRGB(20, 110, 245),
    AccentStrong = Color3.fromRGB(34, 119, 246),
    AccentBright = Color3.fromRGB(16, 104, 240),
    AccentSoft = Color3.fromRGB(112, 168, 248),
    AccentText = Color3.fromRGB(90, 153, 248),
    Text = Color3.fromRGB(248, 248, 248),
    TextSecondary = Color3.fromRGB(209, 209, 209),
    TextMuted = Color3.fromRGB(120, 112, 128),
    TextMuted2 = Color3.fromRGB(104, 104, 112),
    ToggleOff = Color3.fromRGB(64, 56, 64),
    ButtonStroke = Color3.fromRGB(59, 55, 64),
    ButtonFill = Color3.fromRGB(28, 24, 30),
    CardDark = Color3.fromRGB(27, 23, 28),
    CardDarker = Color3.fromRGB(23, 19, 24),
    BlueDepth = Color3.fromRGB(24, 95, 214),
}

local ROOT_SIZE = Vector2.new(1064, 708)
local WINDOW_SIZE = Vector2.new(1024, 668)
local WINDOW_OFFSET = Vector2.new(20, 20)
local TITLE_BAR_HEIGHT = 48

local MODULES = {
    {
        name = "Fullbright",
        icon = "sun-medium",
        enabled = true,
        active = false,
        bars = { 38, 110 },
        auxPill = true,
    },
    {
        name = "Reach",
        icon = "hand",
        enabled = true,
        active = true,
        detailLeft = "3-3.2",
        detailRight = "Combo mode",
        auxPill = true,
    },
    {
        name = "Throwpot",
        icon = "bomb",
        enabled = false,
        active = false,
        bars = { 38, 58, 86 },
        auxPill = false,
    },
    {
        name = "Velocity",
        icon = "gauge",
        enabled = false,
        active = false,
        bars = { 38, 66 },
        auxPill = false,
    },
    {
        name = "Blink",
        icon = "workflow",
        enabled = true,
        active = false,
        bars = { 38, 118 },
        auxPill = true,
    },
}

local function create(className, props)
    local instance = Instance.new(className)

    for key, value in pairs(props) do
        if key ~= "Parent" then
            instance[key] = value
        end
    end

    instance.Parent = props.Parent

    return instance
end

local function addCorner(parent, radius)
    return create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, radius),
    })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Parent = parent,
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function addGradient(parent, rotation, colors, transparencies)
    return create("UIGradient", {
        Parent = parent,
        Rotation = rotation,
        Color = ColorSequence.new(colors),
        Transparency = NumberSequence.new(transparencies),
    })
end

local function addPadding(parent, left, top, right, bottom)
    return create("UIPadding", {
        Parent = parent,
        PaddingLeft = UDim.new(0, left),
        PaddingTop = UDim.new(0, top),
        PaddingRight = UDim.new(0, right),
        PaddingBottom = UDim.new(0, bottom),
    })
end

local function tween(instance, properties, duration)
    return TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    )
end

local function lerpColor(a, b, alpha)
    return Color3.new(
        a.R + ((b.R - a.R) * alpha),
        a.G + ((b.G - a.G) * alpha),
        a.B + ((b.B - a.B) * alpha)
    )
end

local function pixelFrame(parent, x, y, width, height, color, zIndex, transparency, rotation)
    local frame = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = color,
        BackgroundTransparency = transparency or 0,
        BorderSizePixel = 0,
        Rotation = rotation or 0,
        ZIndex = zIndex or 1,
    })

    addCorner(frame, math.max(1, math.floor(math.min(width, height) * 0.5)))

    return frame
end

local function solidRect(parent, x, y, width, height, color, zIndex, rotation, radius)
    local frame = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = color,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Rotation = rotation or 0,
        ZIndex = zIndex or 1,
    })

    addCorner(frame, radius or math.max(1, math.floor(math.min(width, height) * 0.25)))

    return frame
end

local function ring(parent, x, y, diameter, color, thickness, zIndex, transparency)
    local frame = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(diameter, diameter),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = zIndex or 1,
    })

    addCorner(frame, math.floor(diameter * 0.5))
    addStroke(frame, color, thickness, transparency or 0)

    return frame
end

local function outlineRect(parent, x, y, width, height, color, thickness, radius, zIndex, rotation)
    local frame = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = rotation or 0,
        ZIndex = zIndex or 1,
    })

    addCorner(frame, radius or 4)
    addStroke(frame, color, thickness, 0)

    return frame
end

local function line(parent, x, y, length, thickness, rotation, color, zIndex, transparency)
    return pixelFrame(parent, x, y, length, thickness, color, zIndex, transparency, rotation)
end

local function dot(parent, x, y, diameter, color, zIndex, transparency)
    return pixelFrame(parent, x, y, diameter, diameter, color, zIndex, transparency, 0)
end

local function arc(parent, centerX, centerY, radius, startAngle, endAngle, count, segmentLength, thickness, color, zIndex, transparency)
    for index = 0, count - 1 do
        local alpha = if count == 1 then 0 else index / (count - 1)
        local angle = math.rad(startAngle + ((endAngle - startAngle) * alpha))
        local x = centerX + (math.cos(angle) * radius)
        local y = centerY + (math.sin(angle) * radius)
        line(parent, x, y, segmentLength, thickness, math.deg(angle) + 90, color, zIndex, transparency)
    end
end

local function drawGear(parent, size, color, zIndex)
    local unit = size / 24
    local center = 12 * unit
    local radius = 7.7 * unit
    local toothLength = 2.8 * unit
    local thickness = math.max(1.25, size * 0.0625)

    ring(parent, center, center, 9.2 * unit, color, thickness, zIndex)
    ring(parent, center, center, 3.8 * unit, color, thickness, zIndex)

    for index = 0, 5 do
        local angle = math.rad(index * 60)
        line(
            parent,
            center + (math.cos(angle) * radius),
            center + (math.sin(angle) * radius),
            toothLength,
            thickness,
            math.deg(angle),
            color,
            zIndex
        )
    end
end

local function drawHouse(parent, size, color, zIndex)
    local unit = size / 24
    local roofThickness = math.max(3.5, size * 0.18)

    solidRect(parent, 12 * unit, 15.2 * unit, 10 * unit, 8.2 * unit, color, zIndex, 0, math.max(2, 2.2 * unit))
    line(parent, 9.1 * unit, 9.8 * unit, 7.6 * unit, roofThickness, -45, color, zIndex)
    line(parent, 14.9 * unit, 9.8 * unit, 7.6 * unit, roofThickness, 45, color, zIndex)
end

local function drawCopyPlus(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)

    outlineRect(parent, 8.8 * unit, 10 * unit, 8.2 * unit, 8.8 * unit, color, thickness, 3 * unit, zIndex)
    outlineRect(parent, 12.8 * unit, 12.8 * unit, 8.6 * unit, 9.2 * unit, color, thickness, 3 * unit, zIndex)
    ring(parent, 18.2 * unit, 17.8 * unit, 5.8 * unit, color, thickness, zIndex)
    line(parent, 18.2 * unit, 17.8 * unit, 3.2 * unit, thickness, 0, color, zIndex)
    line(parent, 18.2 * unit, 17.8 * unit, 3.2 * unit, thickness, 90, color, zIndex)
end

local function drawSearch(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)

    ring(parent, 10 * unit, 10 * unit, 9 * unit, color, thickness, zIndex)
    line(parent, 15.8 * unit, 15.8 * unit, 5.8 * unit, thickness, 45, color, zIndex)
end

local function drawFileCode(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)

    outlineRect(parent, 11.4 * unit, 12 * unit, 10.2 * unit, 13 * unit, color, thickness, 3 * unit, zIndex)
    line(parent, 14.4 * unit, 7.6 * unit, 3.8 * unit, thickness, 45, color, zIndex)
    line(parent, 16.3 * unit, 9.5 * unit, 2.4 * unit, thickness, 0, color, zIndex)
    line(parent, 8.7 * unit, 13.2 * unit, 3 * unit, thickness, -35, color, zIndex)
    line(parent, 8.7 * unit, 16.3 * unit, 3 * unit, thickness, 35, color, zIndex)
    line(parent, 13.6 * unit, 13.2 * unit, 3 * unit, thickness, 35, color, zIndex)
    line(parent, 13.6 * unit, 16.3 * unit, 3 * unit, thickness, -35, color, zIndex)
end

local function drawRefresh(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)
    local center = 12 * unit
    local radius = 6.8 * unit

    arc(parent, center, center, radius, -150, 60, 7, 3.6 * unit, thickness, color, zIndex)
    line(parent, 18.4 * unit, 8.1 * unit, 3.4 * unit, thickness, -25, color, zIndex)
    line(parent, 17 * unit, 6.4 * unit, 3.4 * unit, thickness, 55, color, zIndex)
end

local function drawSun(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)
    local center = 12 * unit

    ring(parent, center, center, 7.6 * unit, color, thickness, zIndex)

    for index = 0, 7 do
        local angle = math.rad(index * 45)
        line(
            parent,
            center + (math.cos(angle) * (7.3 * unit)),
            center + (math.sin(angle) * (7.3 * unit)),
            3 * unit,
            thickness,
            math.deg(angle),
            color,
            zIndex
        )
    end
end

local function drawHand(parent, size, color, zIndex)
    local unit = size / 24
    solidRect(parent, 8.2 * unit, 9.2 * unit, 2.2 * unit, 5.6 * unit, color, zIndex, 0, 1.2 * unit)
    solidRect(parent, 10.7 * unit, 8.8 * unit, 2.2 * unit, 6.6 * unit, color, zIndex, 0, 1.2 * unit)
    solidRect(parent, 13.2 * unit, 8.8 * unit, 2.2 * unit, 6.6 * unit, color, zIndex, 0, 1.2 * unit)
    solidRect(parent, 15.5 * unit, 9.7 * unit, 2.2 * unit, 5.1 * unit, color, zIndex, 0, 1.2 * unit)
    solidRect(parent, 11.9 * unit, 15.2 * unit, 8.2 * unit, 6.2 * unit, color, zIndex, 0, 1.6 * unit)
    solidRect(parent, 6.8 * unit, 14.1 * unit, 4.6 * unit, 2.8 * unit, color, zIndex, -32, 1.2 * unit)
end

local function drawBomb(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)

    ring(parent, 11.1 * unit, 14.1 * unit, 10.4 * unit, color, thickness, zIndex)
    line(parent, 15.2 * unit, 9 * unit, 4 * unit, thickness, -38, color, zIndex)
    line(parent, 18 * unit, 6.1 * unit, 2.6 * unit, thickness, 0, color, zIndex)
    line(parent, 18 * unit, 6.1 * unit, 2.6 * unit, thickness, 90, color, zIndex)
    dot(parent, 18 * unit, 6.1 * unit, 1.8 * unit, color, zIndex)
end

local function drawGauge(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)
    local centerX = 12 * unit
    local centerY = 15.5 * unit

    arc(parent, centerX, centerY, 7.4 * unit, 205, 335, 6, 3.6 * unit, thickness, color, zIndex)
    line(parent, centerX, centerY, 6 * unit, thickness, -35, color, zIndex)
    dot(parent, centerX, centerY, 2.4 * unit, color, zIndex)
end

local function drawWorkflow(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(1.25, size * 0.0625)

    line(parent, 8 * unit, 14.5 * unit, 6 * unit, thickness, -45, color, zIndex)
    line(parent, 16 * unit, 14.5 * unit, 6 * unit, thickness, 45, color, zIndex)
    line(parent, 12 * unit, 17.2 * unit, 7 * unit, thickness, 0, color, zIndex)
    ring(parent, 6 * unit, 18 * unit, 4.4 * unit, color, thickness, zIndex)
    ring(parent, 12 * unit, 8.2 * unit, 4.4 * unit, color, thickness, zIndex)
    ring(parent, 18 * unit, 18 * unit, 4.4 * unit, color, thickness, zIndex)
end

local function drawMoreHorizontal(parent, size, color, zIndex)
    local unit = size / 24
    local diameter = 3.2 * unit

    dot(parent, 7 * unit, 12 * unit, diameter, color, zIndex)
    dot(parent, 12 * unit, 12 * unit, diameter, color, zIndex)
    dot(parent, 17 * unit, 12 * unit, diameter, color, zIndex)
end

local function drawMoreVertical(parent, size, color, zIndex)
    local unit = size / 24
    local diameter = 3.2 * unit

    dot(parent, 12 * unit, 7 * unit, diameter, color, zIndex)
    dot(parent, 12 * unit, 12 * unit, diameter, color, zIndex)
    dot(parent, 12 * unit, 17 * unit, diameter, color, zIndex)
end

local function drawMinus(parent, size, color, zIndex)
    local unit = size / 24
    line(parent, 12 * unit, 12 * unit, 10 * unit, math.max(2, math.floor(size * 0.08)), 0, color, zIndex)
end

local function drawX(parent, size, color, zIndex)
    local unit = size / 24
    local thickness = math.max(2, math.floor(size * 0.08))

    line(parent, 12 * unit, 12 * unit, 10 * unit, thickness, 45, color, zIndex)
    line(parent, 12 * unit, 12 * unit, 10 * unit, thickness, -45, color, zIndex)
end

local function drawIcon(parent, iconName, size, color, zIndex)
    local canvas = create("Frame", {
        Parent = parent,
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = zIndex or 1,
    })

    if iconName == "house" then
        drawHouse(canvas, size, color, zIndex)
    elseif iconName == "copy-plus" then
        drawCopyPlus(canvas, size, color, zIndex)
    elseif iconName == "search" then
        drawSearch(canvas, size, color, zIndex)
    elseif iconName == "file-code" then
        drawFileCode(canvas, size, color, zIndex)
    elseif iconName == "settings" then
        drawGear(canvas, size, color, zIndex)
    elseif iconName == "refresh-cw" then
        drawRefresh(canvas, size, color, zIndex)
    elseif iconName == "sun-medium" then
        drawSun(canvas, size, color, zIndex)
    elseif iconName == "hand" then
        drawHand(canvas, size, color, zIndex)
    elseif iconName == "bomb" then
        drawBomb(canvas, size, color, zIndex)
    elseif iconName == "gauge" then
        drawGauge(canvas, size, color, zIndex)
    elseif iconName == "workflow" then
        drawWorkflow(canvas, size, color, zIndex)
    elseif iconName == "more-horizontal" then
        drawMoreHorizontal(canvas, size, color, zIndex)
    elseif iconName == "more-vertical" then
        drawMoreVertical(canvas, size, color, zIndex)
    elseif iconName == "minus" then
        drawMinus(canvas, size, color, zIndex)
    elseif iconName == "x" then
        drawX(canvas, size, color, zIndex)
    end

    return canvas
end

local function bindHover(button, idleColor, hoverColor, stroke)
    button.MouseEnter:Connect(function()
        tween(button, { BackgroundColor3 = hoverColor }, 0.14):Play()
        if stroke then
            tween(stroke, { Transparency = math.max(0, stroke.Transparency - 0.14) }, 0.14):Play()
        end
    end)

    button.MouseLeave:Connect(function()
        tween(button, { BackgroundColor3 = idleColor }, 0.14):Play()
        if stroke then
            tween(stroke, { Transparency = 0.45 }, 0.14):Play()
        end
    end)
end

local function createToggle(parent, initialState, accentTrack)
    local state = initialState
    local onColor = accentTrack or THEME.AccentBright
    local offColor = THEME.ToggleOff

    local button = create("TextButton", {
        Parent = parent,
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = state and onColor or offColor,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 7,
    })

    addCorner(button, 999)

    local stroke = addStroke(button, state and lerpColor(onColor, THEME.Text, 0.45) or Color3.fromRGB(74, 68, 76), 1, state and 0.56 or 0.72)

    local knob = create("Frame", {
        Parent = button,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = state and Color3.fromRGB(243, 247, 255) or Color3.fromRGB(86, 82, 90),
        BorderSizePixel = 0,
        ZIndex = 8,
    })

    addCorner(knob, 999)

    local function apply(nextState)
        state = nextState
        tween(button, { BackgroundColor3 = state and onColor or offColor }, 0.14):Play()
        tween(knob, {
            Position = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
            BackgroundColor3 = state and Color3.fromRGB(243, 247, 255) or Color3.fromRGB(86, 82, 90),
        }, 0.14):Play()
        tween(stroke, {
            Transparency = state and 0.56 or 0.72,
            Color = state and lerpColor(onColor, THEME.Text, 0.45) or Color3.fromRGB(74, 68, 76),
        }, 0.14):Play()
    end

    button.MouseButton1Click:Connect(function()
        apply(not state)
    end)

    return button
end

local function createPill(parent, size, color, transparency, zIndex)
    local pill = create("Frame", {
        Parent = parent,
        Size = size,
        BackgroundColor3 = color,
        BackgroundTransparency = transparency,
        BorderSizePixel = 0,
        ZIndex = zIndex or 5,
    })

    addCorner(pill, 999)

    return pill
end

local screenGui = create("ScreenGui", {
    Parent = playerGui,
    Name = "VapeDesktopMockup",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local backdrop = create("Frame", {
    Parent = screenGui,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = THEME.Background,
    BorderSizePixel = 0,
})

addGradient(
    backdrop,
    125,
    {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 20, 26)),
        ColorSequenceKeypoint.new(0.45, THEME.Background),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 16, 20)),
    },
    {
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0),
    }
)

local root = create("Frame", {
    Parent = backdrop,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(ROOT_SIZE.X, ROOT_SIZE.Y),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
})

local rootScale = create("UIScale", {
    Parent = root,
    Scale = 1,
})

local shadow = create("Frame", {
    Parent = root,
    Position = UDim2.fromOffset(WINDOW_OFFSET.X, WINDOW_OFFSET.Y + 14),
    Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
    BackgroundColor3 = THEME.Shadow,
    BackgroundTransparency = 0.22,
    BorderSizePixel = 0,
    ZIndex = 1,
})

addCorner(shadow, 26)

local glow = create("Frame", {
    Parent = root,
    Position = UDim2.fromOffset(WINDOW_OFFSET.X - 2, WINDOW_OFFSET.Y - 2),
    Size = UDim2.fromOffset(WINDOW_SIZE.X + 4, WINDOW_SIZE.Y + 4),
    BackgroundColor3 = THEME.AccentBright,
    BackgroundTransparency = 0.975,
    BorderSizePixel = 0,
    ZIndex = 1,
})

addCorner(glow, 28)
addStroke(glow, THEME.AccentSoft, 1, 0.92)

local window = create("Frame", {
    Parent = root,
    Position = UDim2.fromOffset(WINDOW_OFFSET.X, WINDOW_OFFSET.Y),
    Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
    BackgroundColor3 = THEME.Window,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
})

addCorner(window, 24)
addStroke(window, Color3.fromRGB(56, 52, 60), 1, 0.38)

local windowIntroScale = create("UIScale", {
    Parent = window,
    Scale = 0.985,
})

local topTint = create("Frame", {
    Parent = window,
    Size = UDim2.new(1, 0, 0, 118),
    BackgroundColor3 = THEME.Window,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ZIndex = 2,
})

addGradient(
    topTint,
    90,
    {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 32, 38)),
        ColorSequenceKeypoint.new(0.48, Color3.fromRGB(29, 25, 30)),
        ColorSequenceKeypoint.new(1, THEME.Window),
    },
    {
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.7, 0.985),
        NumberSequenceKeypoint.new(1, 1),
    }
)

local titleBar = create("Frame", {
    Parent = window,
    Active = true,
    ClipsDescendants = true,
    Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT),
    BackgroundColor3 = THEME.Window,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    ZIndex = 3,
})

local titleDivider = create("Frame", {
    Parent = titleBar,
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Color3.fromRGB(48, 44, 52),
    BackgroundTransparency = 0.28,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local logoLabel = create("TextLabel", {
    Parent = titleBar,
    Position = UDim2.fromOffset(18, 0),
    Size = UDim2.fromOffset(54, TITLE_BAR_HEIGHT),
    BackgroundTransparency = 1,
    Text = "VAPE",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = THEME.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
})

local logoLeaf = create("Frame", {
    Parent = titleBar,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(77, 19),
    Size = UDim2.fromOffset(5, 14),
    BackgroundColor3 = THEME.Text,
    BorderSizePixel = 0,
    Rotation = 28,
    ZIndex = 5,
})

addCorner(logoLeaf, 6)

local logoStem = create("Frame", {
    Parent = titleBar,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(72, 24),
    Size = UDim2.fromOffset(2, 10),
    BackgroundColor3 = THEME.Text,
    BorderSizePixel = 0,
    Rotation = 20,
    ZIndex = 5,
})

addCorner(logoStem, 2)

local titleControls = create("Frame", {
    Parent = titleBar,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(84, 32),
    BackgroundTransparency = 1,
    ZIndex = 5,
})

local titleControlsLayout = create("UIListLayout", {
    Parent = titleControls,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 10),
})

local function createControlButton(parent, iconName)
    local button = create("TextButton", {
        Parent = parent,
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 5,
    })

    local iconWrap = create("Frame", {
        Parent = button,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })

    drawIcon(iconWrap, iconName, 18, THEME.TextMuted, 6)

    button.MouseEnter:Connect(function()
        for _, child in ipairs(iconWrap:GetDescendants()) do
            if child:IsA("Frame") and child.BackgroundTransparency < 1 then
                tween(child, { BackgroundColor3 = THEME.TextSecondary }, 0.12):Play()
            elseif child:IsA("UIStroke") then
                tween(child, { Color = THEME.TextSecondary }, 0.12):Play()
            end
        end
    end)

    button.MouseLeave:Connect(function()
        for _, child in ipairs(iconWrap:GetDescendants()) do
            if child:IsA("Frame") and child.BackgroundTransparency < 1 then
                tween(child, { BackgroundColor3 = THEME.TextMuted }, 0.12):Play()
            elseif child:IsA("UIStroke") then
                tween(child, { Color = THEME.TextMuted }, 0.12):Play()
            end
        end
    end)

    return button
end

local minimizeButton = createControlButton(titleControls, "minus")
local closeButton = createControlButton(titleControls, "x")

local body = create("Frame", {
    Parent = window,
    Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT),
    Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 3,
})

local navRow = create("Frame", {
    Parent = body,
    Position = UDim2.fromOffset(34, 18),
    Size = UDim2.fromOffset(956, 56),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local navLeft = create("Frame", {
    Parent = navRow,
    Size = UDim2.fromOffset(320, 56),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local navLeftLayout = create("UIListLayout", {
    Parent = navLeft,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 10),
})

local function createNavButton(parent, iconName, labelText)
    local width = if labelText then 112 else 48
    local button = create("TextButton", {
        Parent = parent,
        Size = UDim2.fromOffset(width, 48),
        BackgroundColor3 = THEME.ButtonFill,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 5,
    })

    addCorner(button, 14)
    local stroke = addStroke(button, THEME.ButtonStroke, 1, 0.45)

    local iconHost = create("Frame", {
        Parent = button,
        Position = labelText and UDim2.fromOffset(14, 12) or UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 6,
    })

    drawIcon(iconHost, iconName, 24, THEME.Text, 7)

    if labelText then
        create("TextLabel", {
            Parent = button,
            Position = UDim2.fromOffset(44, 0),
            Size = UDim2.new(1, -54, 1, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            Font = Enum.Font.GothamMedium,
            TextSize = 15,
            TextColor3 = THEME.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
        })
    end

    bindHover(button, THEME.ButtonFill, Color3.fromRGB(34, 30, 36), stroke)

    return button
end

createNavButton(navLeft, "house", "Home")
createNavButton(navLeft, "copy-plus")
createNavButton(navLeft, "search")
createNavButton(navLeft, "file-code")

local navRight = create("Frame", {
    Parent = navRow,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.fromOffset(108, 56),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local navRightLayout = create("UIListLayout", {
    Parent = navRight,
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 10),
})

createNavButton(navRight, "settings")
createNavButton(navRight, "refresh-cw")

local sidebar = create("Frame", {
    Parent = body,
    Position = UDim2.fromOffset(35, 126),
    Size = UDim2.fromOffset(126, 370),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local categories = {
    { name = "Favorites", active = true },
    { name = "Combat", active = false },
    { name = "Visual", active = false },
    { name = "Utility", active = false },
}

local categoryList = create("Frame", {
    Parent = sidebar,
    Size = UDim2.new(1, 0, 0, 218),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local categoryLayout = create("UIListLayout", {
    Parent = categoryList,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 18),
})

for _, category in ipairs(categories) do
    local button = create("TextButton", {
        Parent = categoryList,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = category.name,
        Font = Enum.Font.GothamMedium,
        TextSize = 18,
        TextColor3 = category.active and THEME.Text or THEME.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    })

    if category.active then
        local underline = create("Frame", {
            Parent = button,
            Position = UDim2.fromOffset(0, 34),
            Size = UDim2.fromOffset(18, 4),
            BackgroundColor3 = THEME.AccentBright,
            BorderSizePixel = 0,
            ZIndex = 6,
        })

        addCorner(underline, 999)
    end
end

local quickGrid = create("Frame", {
    Parent = sidebar,
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.fromOffset(92, 62),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local quickLayout = create("UIGridLayout", {
    Parent = quickGrid,
    CellSize = UDim2.fromOffset(26, 26),
    CellPadding = UDim2.fromOffset(6, 6),
    FillDirection = Enum.FillDirection.Horizontal,
    FillDirectionMaxCells = 3,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
})

local function createQuickButton(parent, iconName)
    local button = create("TextButton", {
        Parent = parent,
        BackgroundColor3 = THEME.ButtonFill,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 5,
    })

    addCorner(button, 7)
    addStroke(button, THEME.ButtonStroke, 1, 0.52)

    local iconHost = create("Frame", {
        Parent = button,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(15, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 6,
    })

    drawIcon(iconHost, iconName, 15, THEME.TextMuted2, 7)

    return button
end

createQuickButton(quickGrid, "sun-medium")
createQuickButton(quickGrid, "bomb")
createQuickButton(quickGrid, "gauge")
createQuickButton(quickGrid, "hand")
createQuickButton(quickGrid, "more-horizontal")

local content = create("Frame", {
    Parent = body,
    Position = UDim2.fromOffset(208, 108),
    Size = UDim2.fromOffset(708, 470),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local moduleScroller = create("ScrollingFrame", {
    Parent = content,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Color3.fromRGB(78, 72, 82),
    ScrollBarImageTransparency = 0.26,
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    ZIndex = 4,
})

addPadding(moduleScroller, 0, 0, 12, 22)

local moduleLayout = create("UIListLayout", {
    Parent = moduleScroller,
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 12),
})

local function createGhostPill(parent, position, width, color, transparency, zIndex)
    local pill = createPill(parent, UDim2.fromOffset(width, 12), color, transparency, zIndex)
    pill.Position = position
    return pill
end

local function createModuleCard(parent, moduleData)
    local holder = create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, -12, 0, 74),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
    })

    local shadowFrame = create("Frame", {
        Parent = holder,
        Position = UDim2.fromOffset(0, 6),
        Size = UDim2.new(1, 0, 1, -6),
        BackgroundColor3 = moduleData.active and THEME.AccentBright or THEME.Shadow,
        BackgroundTransparency = moduleData.active and 0.86 or 0.8,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 4,
    })

    addCorner(shadowFrame, 16)

    local button = create("TextButton", {
        Parent = holder,
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = moduleData.active and THEME.BlueDepth or THEME.CardDarker,
        BackgroundTransparency = 0.01,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        ZIndex = 5,
    })

    addCorner(button, 12)
    addStroke(
        button,
        moduleData.active and Color3.fromRGB(132, 191, 255) or Color3.fromRGB(46, 42, 50),
        1,
        moduleData.active and 0.52 or 0.5
    )

    local contentPanel = create("Frame", {
        Parent = button,
        Position = UDim2.fromOffset(56, 0),
        Size = UDim2.new(1, -56, 1, 0),
        BackgroundColor3 = moduleData.active and THEME.AccentStrong or THEME.CardDark,
        BackgroundTransparency = 0.01,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })

    if moduleData.active then
        addGradient(
            contentPanel,
            0,
            {
                ColorSequenceKeypoint.new(0, Color3.fromRGB(47, 129, 250)),
                ColorSequenceKeypoint.new(0.58, THEME.AccentStrong),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 114, 236)),
            },
            {
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0),
            }
        )
    else
        addGradient(
            contentPanel,
            90,
            {
                ColorSequenceKeypoint.new(0, THEME.CardDark),
                ColorSequenceKeypoint.new(1, THEME.CardDarker),
            },
            {
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 0),
            }
        )
    end

    local iconPanel = create("Frame", {
        Parent = button,
        Size = UDim2.fromOffset(56, 72),
        BackgroundColor3 = moduleData.active and THEME.BlueDepth or THEME.CardDarker,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 6,
    })

    addCorner(iconPanel, 12)

    local iconFade = create("Frame", {
        Parent = iconPanel,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(12, 72),
        BackgroundColor3 = moduleData.active and THEME.AccentStrong or THEME.CardDarker,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    addGradient(
        iconFade,
        0,
        {
            ColorSequenceKeypoint.new(0, iconPanel.BackgroundColor3),
            ColorSequenceKeypoint.new(1, iconPanel.BackgroundColor3),
        },
        {
            NumberSequenceKeypoint.new(0, 0.16),
            NumberSequenceKeypoint.new(1, 1),
        }
    )

    local iconHost = create("Frame", {
        Parent = iconPanel,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 7,
    })

    drawIcon(iconHost, moduleData.icon, 20, moduleData.active and THEME.Text or THEME.TextMuted, 8)

    create("TextLabel", {
        Parent = button,
        Position = UDim2.fromOffset(80, moduleData.active and 21 or 23),
        Size = UDim2.fromOffset(134, 20),
        BackgroundTransparency = 1,
        Text = moduleData.name,
        Font = Enum.Font.GothamSemibold,
        TextSize = 16,
        TextColor3 = moduleData.active and THEME.Text or THEME.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    })

    if moduleData.active then
        create("TextLabel", {
            Parent = button,
            Position = UDim2.fromOffset(218, 22),
            Size = UDim2.fromOffset(58, 18),
            BackgroundTransparency = 1,
            Text = moduleData.detailLeft or "",
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(197, 222, 255),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7,
        })

        local detailDot = create("Frame", {
            Parent = button,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(279, 33),
            Size = UDim2.fromOffset(4, 4),
            BackgroundColor3 = Color3.fromRGB(201, 224, 255),
            BorderSizePixel = 0,
            ZIndex = 7,
        })

        addCorner(detailDot, 999)

        create("TextLabel", {
            Parent = button,
            Position = UDim2.fromOffset(292, 22),
            Size = UDim2.fromOffset(136, 18),
            BackgroundTransparency = 1,
            Text = moduleData.detailRight or "",
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = Color3.fromRGB(197, 222, 255),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7,
        })
    else
        local x = 218

        for _, width in ipairs(moduleData.bars or {}) do
            createGhostPill(
                button,
                UDim2.fromOffset(x, 30),
                width,
                Color3.fromRGB(57, 53, 60),
                0.38,
                6
            )
            x += width + 10
        end
    end

    local auxPill = createGhostPill(
        button,
        UDim2.fromOffset(528, 30),
        54,
        moduleData.active and Color3.fromRGB(72, 132, 220) or Color3.fromRGB(41, 39, 45),
        moduleData.active and 0.16 or 0.28,
        6
    )

    if not moduleData.auxPill then
        auxPill.Visible = false
    end

    local toggleHost = create("Frame", {
        Parent = button,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -44, 0.5, 0),
        Size = UDim2.fromOffset(72, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 7,
    })

    local menuHost = create("Frame", {
        Parent = toggleHost,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 8,
    })

    drawIcon(menuHost, "more-vertical", 18, moduleData.active and THEME.Text or THEME.TextMuted2, 9)

    local toggle = createToggle(
        toggleHost,
        moduleData.enabled,
        moduleData.active and Color3.fromRGB(79, 148, 255) or THEME.AccentBright
    )
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -22, 0.5, 0)

    if not moduleData.active then
        bindHover(button, THEME.CardDark, Color3.fromRGB(31, 27, 33), nil)
    end

    return holder
end

for _, moduleData in ipairs(MODULES) do
    createModuleCard(moduleScroller, moduleData)
end

local bottomGhost = create("Frame", {
    Parent = moduleScroller,
    Size = UDim2.new(1, -12, 0, 64),
    BackgroundColor3 = THEME.CardDark,
    BackgroundTransparency = 0.62,
    BorderSizePixel = 0,
    ZIndex = 4,
})

addCorner(bottomGhost, 12)
addGradient(
    bottomGhost,
    90,
    {
        ColorSequenceKeypoint.new(0, THEME.CardDark),
        ColorSequenceKeypoint.new(1, THEME.CardDark),
    },
    {
        NumberSequenceKeypoint.new(0, 0.28),
        NumberSequenceKeypoint.new(1, 0.88),
    }
)

local minimized = false
local expandedWindowSize = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y)
local minimizedWindowSize = UDim2.fromOffset(WINDOW_SIZE.X, TITLE_BAR_HEIGHT + 2)

local function setWindowSize(targetSize)
    tween(window, { Size = targetSize }, 0.18):Play()
    tween(shadow, { Size = targetSize }, 0.18):Play()
    tween(glow, { Size = UDim2.fromOffset(targetSize.X.Offset + 4, targetSize.Y.Offset + 4) }, 0.18):Play()
end

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        body.Visible = false
        setWindowSize(minimizedWindowSize)
    else
        body.Visible = true
        setWindowSize(expandedWindowSize)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

local dragging = false
local dragStart
local startPosition

local function updateDrag(input)
    if not dragging or not dragStart or not startPosition then
        return
    end

    local delta = input.Position - dragStart

    root.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    dragging = true
    dragStart = input.Position
    startPosition = root.Position

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

local function updateScale()
    local viewport = backdrop.AbsoluteSize
    local scale = math.min((viewport.X - 20) / ROOT_SIZE.X, (viewport.Y - 20) / ROOT_SIZE.Y, 1)
    rootScale.Scale = math.max(scale, 0.52)
end

updateScale()
backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)

tween(windowIntroScale, { Scale = 1 }, 0.22):Play()
