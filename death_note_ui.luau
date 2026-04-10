--[[
    Death Note-inspired open book UI.
    Place this in a LocalScript inside StarterPlayerScripts or StarterGui.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local BOOK_ASPECT = 440 / 329
local DEFAULT_BOOK_WIDTH = 500
local TARGET_MIN_BOOK_WIDTH = 380
local ABSOLUTE_MIN_BOOK_WIDTH = 280
local MAX_BOOK_WIDTH = 920
local VIEWPORT_MARGIN = 48
local MAX_SUGGESTIONS = 8
local TOGGLE_KEY = Enum.KeyCode.RightShift

local localPlayer = Players.LocalPlayer
if not localPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    localPlayer = Players.LocalPlayer
end

local playerGui = localPlayer:WaitForChild("PlayerGui")

local existingGui = playerGui:FindFirstChild("DeathNoteBookUI")
if existingGui then
    existingGui:Destroy()
end

local connections = {}
local cleanup
local stopDragging
local stopResizing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataRemoteEvent = ReplicatedStorage:FindFirstChild("DataRemoteEvent")

local KillLogic = {
    SignatureId = 6574,
}

function KillLogic.GetNextSignature()
    local sig = "Players." .. localPlayer.Name .. ".PlayerScripts.ClientGunHandler:" .. tostring(KillLogic.SignatureId)
    KillLogic.SignatureId = KillLogic.SignatureId + 1
    return sig
end

function KillLogic.FireAttack(targetHumanoid, targetPosition)
    if not targetHumanoid or not DataRemoteEvent then
        return
    end

    local payload = {
        {
            "\x03",
            KillLogic.GetNextSignature()
        },
        {
            targetHumanoid,
            "Melee2"
        },
        {
            "\x03",
            KillLogic.GetNextSignature()
        },
        {
            targetHumanoid,
            "Attack",
            [6] = targetPosition
        }
    }

    DataRemoteEvent:FireServer(payload)
end

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

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
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

local function addCorner(parent, radiusScale, radiusOffset)
    return create("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(radiusScale or 0, radiusOffset or 0),
    })
end

local function addSmudge(parent, options)
    local smudge = create("Frame", {
        Parent = parent,
        AnchorPoint = options.AnchorPoint or Vector2.new(0.5, 0.5),
        Position = options.Position,
        Size = options.Size,
        Rotation = options.Rotation or 0,
        BackgroundColor3 = options.Color or Color3.fromRGB(111, 83, 46),
        BackgroundTransparency = options.BaseTransparency or 0.62,
        BorderSizePixel = 0,
        ZIndex = options.ZIndex or 2,
    })

    addCorner(smudge, 1, 0)

    create("UIGradient", {
        Parent = smudge,
        Rotation = options.GradientRotation or 0,
        Color = ColorSequence.new(smudge.BackgroundColor3),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.72),
            NumberSequenceKeypoint.new(0.5, 0.18),
            NumberSequenceKeypoint.new(0.8, 0.72),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    return smudge
end

local function addEdgeFade(parent, position, size, rotation, baseTransparency)
    local fade = create("Frame", {
        Parent = parent,
        Position = position,
        Size = size,
        BackgroundColor3 = Color3.fromRGB(80, 57, 30),
        BackgroundTransparency = baseTransparency or 0.8,
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    create("UIGradient", {
        Parent = fade,
        Rotation = rotation,
        Color = ColorSequence.new(fade.BackgroundColor3),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })
end

local function addLine(parent, position, size, rotation, transparency, zIndex)
    create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = position,
        Size = size,
        Rotation = rotation,
        BackgroundColor3 = Color3.fromRGB(22, 18, 14),
        BackgroundTransparency = transparency or 0.1,
        BorderSizePixel = 0,
        ZIndex = zIndex or 4,
    })
end

local function addInkCorner(parent, xDirection, yDirection)
    local x = xDirection < 0 and 0.05 or 0.95
    local y = yDirection < 0 and 0.06 or 0.94
    local xInset = xDirection < 0 and 0.09 or -0.09
    local yInset = yDirection < 0 and 0.09 or -0.09
    local diagonal = (xDirection * yDirection) > 0 and 42 or -42

    addSmudge(parent, {
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromScale(0.22, 0.18),
        Rotation = diagonal,
        Color = Color3.fromRGB(18, 14, 11),
        BaseTransparency = 0.28,
        ZIndex = 4,
    })

    addSmudge(parent, {
        Position = UDim2.fromScale(x + (xInset * 0.18), y + (yInset * 0.14)),
        Size = UDim2.fromScale(0.13, 0.11),
        Rotation = -diagonal,
        Color = Color3.fromRGB(32, 25, 18),
        BaseTransparency = 0.35,
        ZIndex = 4,
    })

    addLine(parent, UDim2.fromScale(x + (xInset * 0.45), y), UDim2.fromScale(0.2, 0.013), 0, 0.18)
    addLine(parent, UDim2.fromScale(x, y + (yInset * 0.45)), UDim2.fromScale(0.013, 0.2), 0, 0.18)
    addLine(parent, UDim2.fromScale(x + (xInset * 0.34), y + (yInset * 0.35)), UDim2.fromScale(0.16, 0.013), diagonal, 0.12)

    local ring = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x + (xInset * 0.42), y + (yInset * 0.42)),
        Size = UDim2.fromScale(0.06, 0.06),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    addCorner(ring, 1, 0)
    addStroke(ring, Color3.fromRGB(24, 20, 15), 2, 0.15)
end

local function addHeaderOrnament(parent)
    addLine(parent, UDim2.fromScale(0.5, 0.075), UDim2.fromScale(0.22, 0.009), 0, 0.2)
    addLine(parent, UDim2.fromScale(0.35, 0.078), UDim2.fromScale(0.07, 0.008), -18, 0.24)
    addLine(parent, UDim2.fromScale(0.65, 0.078), UDim2.fromScale(0.07, 0.008), 18, 0.24)

    local crest = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.075),
        Size = UDim2.fromScale(0.055, 0.045),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    addCorner(crest, 1, 0)
    addStroke(crest, Color3.fromRGB(30, 24, 18), 2, 0.12)
end

local function addFooterOrnament(parent)
    local plate = create("Frame", {
        Parent = parent,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.93),
        Size = UDim2.fromScale(0.16, 0.055),
        BackgroundColor3 = Color3.fromRGB(229, 214, 176),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 4,
    })

    addCorner(plate, 1, 0)
    addStroke(plate, Color3.fromRGB(28, 22, 16), 2, 0.15)

    addLine(parent, UDim2.fromScale(0.35, 0.93), UDim2.fromScale(0.09, 0.009), 8, 0.25)
    addLine(parent, UDim2.fromScale(0.65, 0.93), UDim2.fromScale(0.09, 0.009), -8, 0.25)
end

local function addPageTexture(page, heavierTexture)
    create("UIGradient", {
        Parent = page,
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 181, 138)),
            ColorSequenceKeypoint.new(0.22, Color3.fromRGB(236, 221, 186)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(245, 232, 198)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(211, 190, 150)),
        }),
    })

    addEdgeFade(page, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.08), 90, 0.84)
    addEdgeFade(page, UDim2.fromScale(0, 0.92), UDim2.fromScale(1, 0.08), 270, 0.84)
    addEdgeFade(page, UDim2.fromScale(0, 0), UDim2.fromScale(0.06, 1), 0, 0.82)
    addEdgeFade(page, UDim2.fromScale(0.94, 0), UDim2.fromScale(0.06, 1), 180, 0.82)

    addSmudge(page, {
        Position = UDim2.fromScale(0.2, 0.18),
        Size = UDim2.fromScale(0.26, 0.14),
        Rotation = -18,
    })

    addSmudge(page, {
        Position = UDim2.fromScale(0.72, 0.34),
        Size = UDim2.fromScale(0.32, 0.18),
        Rotation = 22,
        BaseTransparency = 0.68,
    })

    addSmudge(page, {
        Position = UDim2.fromScale(0.54, 0.68),
        Size = UDim2.fromScale(0.38, 0.22),
        Rotation = -8,
        BaseTransparency = 0.72,
    })

    addSmudge(page, {
        Position = UDim2.fromScale(0.3, 0.82),
        Size = UDim2.fromScale(0.24, 0.12),
        Rotation = 14,
        BaseTransparency = 0.78,
    })

    if heavierTexture then
        addSmudge(page, {
            Position = UDim2.fromScale(0.46, 0.5),
            Size = UDim2.fromScale(0.52, 0.3),
            Rotation = 4,
            BaseTransparency = 0.8,
        })

        addSmudge(page, {
            Position = UDim2.fromScale(0.82, 0.76),
            Size = UDim2.fromScale(0.19, 0.1),
            Rotation = -24,
            BaseTransparency = 0.72,
        })
    end
end

local function round(value)
    return math.floor(value + 0.5)
end

local screenGui = create("ScreenGui", {
    Parent = playerGui,
    Name = "DeathNoteBookUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 50,
})

local customCursor = create("ImageLabel", {
    Parent = screenGui,
    Name = "CustomCursor",
    Size = UDim2.fromOffset(26, 26),
    BackgroundTransparency = 1,
    Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
    ZIndex = 1000,
    Visible = true,
})

local backdrop = create("Frame", {
    Parent = screenGui,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 0,
})

local bookHolder = create("Frame", {
    Parent = backdrop,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(0, 0),
    Size = UDim2.fromOffset(DEFAULT_BOOK_WIDTH, round(DEFAULT_BOOK_WIDTH / BOOK_ASPECT)),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 1,
})

local modalButton = create("TextButton", {
    Parent = bookHolder,
    Size = UDim2.fromOffset(0, 0),
    BackgroundTransparency = 1,
    Text = "",
    Modal = true,
    Visible = true,
    ZIndex = 0,
})

create("Frame", {
    Parent = bookHolder,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.515),
    Size = UDim2.fromScale(1.04, 1.06),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ZIndex = 1,
})

create("Frame", {
    Parent = bookHolder,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.525),
    Size = UDim2.fromScale(1.08, 1.11),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.84,
    BorderSizePixel = 0,
    ZIndex = 1,
})

local book = create("Frame", {
    Parent = bookHolder,
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(7, 5, 4),
    BorderSizePixel = 0,
    ZIndex = 2,
})

local dragHandle = create("Frame", {
    Parent = bookHolder,
    Size = UDim2.fromScale(1, 0.08),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 9,
})

local leftPage = create("Frame", {
    Parent = book,
    Position = UDim2.fromScale(0.02, 0.02),
    Size = UDim2.fromScale(0.46, 0.96),
    BackgroundColor3 = Color3.fromRGB(241, 228, 193),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
})

local spine = create("Frame", {
    Parent = book,
    Position = UDim2.fromScale(0.49, 0),
    Size = UDim2.fromScale(0.02, 1),
    BackgroundColor3 = Color3.fromRGB(10, 8, 7),
    BorderSizePixel = 0,
    ZIndex = 3,
})

local rightPage = create("Frame", {
    Parent = book,
    Position = UDim2.fromScale(0.53, 0.02),
    Size = UDim2.fromScale(0.45, 0.96),
    BackgroundColor3 = Color3.fromRGB(241, 228, 193),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 3,
})

local resizeHandle = create("TextButton", {
    Parent = bookHolder,
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.fromScale(1, 1),
    Size = UDim2.fromOffset(36, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Active = true,
    ZIndex = 10,
})

addLine(resizeHandle, UDim2.fromScale(0.68, 0.8), UDim2.fromOffset(12, 2), -45, 0.15, 10)
addLine(resizeHandle, UDim2.fromScale(0.52, 0.8), UDim2.fromOffset(10, 2), -45, 0.25, 10)
addLine(resizeHandle, UDim2.fromScale(0.8, 0.64), UDim2.fromOffset(10, 2), -45, 0.25, 10)

create("UIGradient", {
    Parent = spine,
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 24, 20)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(5, 4, 3)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 24, 20)),
    }),
})

addPageTexture(leftPage, true)
addPageTexture(rightPage, false)

local leftBorder = create("Frame", {
    Parent = leftPage,
    Position = UDim2.fromScale(0.045, 0.035),
    Size = UDim2.fromScale(0.91, 0.93),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

addStroke(leftBorder, Color3.fromRGB(19, 15, 12), 3, 0.05)

local innerBorder = create("Frame", {
    Parent = leftBorder,
    Position = UDim2.fromScale(0.04, 0.03),
    Size = UDim2.fromScale(0.92, 0.94),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

addStroke(innerBorder, Color3.fromRGB(25, 20, 14), 1.5, 0.22)

addInkCorner(leftBorder, -1, -1)
addInkCorner(leftBorder, 1, -1)
addInkCorner(leftBorder, -1, 1)
addInkCorner(leftBorder, 1, 1)
addHeaderOrnament(leftBorder)
addFooterOrnament(leftBorder)

local titleLabel = create("TextLabel", {
    Parent = leftBorder,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.13),
    Size = UDim2.fromScale(0.72, 0.11),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Rotation = -4,
    Text = "DEATH NOTE",
    TextColor3 = Color3.fromRGB(31, 27, 23),
    TextScaled = true,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = titleLabel,
    MinTextSize = 18,
    MaxTextSize = 42,
})

local subtitleLabel = create("TextLabel", {
    Parent = leftBorder,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.fromScale(0.5, 0.205),
    Size = UDim2.fromScale(0.42, 0.05),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Rotation = -2,
    Text = "How to use it",
    TextColor3 = Color3.fromRGB(46, 38, 30),
    TextScaled = true,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = subtitleLabel,
    MinTextSize = 10,
    MaxTextSize = 22,
})

local bodyLabel = create("TextLabel", {
    Parent = leftBorder,
    Position = UDim2.fromScale(0.13, 0.275),
    Size = UDim2.fromScale(0.74, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = table.concat({
        "The human whose name is written in",
        "this note shall die.",
        "",
        "The note takes effect only when",
        "the writer keeps the victim's face",
        "clearly in mind while writing.",
        "",
        "If the cause of death is written",
        "within forty seconds, it will",
        "happen exactly as described.",
        "",
        "If no cause is written, the victim",
        "simply dies of a heart attack.",
    }, "\n"),
    TextColor3 = Color3.fromRGB(39, 33, 26),
    TextScaled = true,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = bodyLabel,
    MinTextSize = 9,
    MaxTextSize = 17,
})

local rightContent = create("Frame", {
    Parent = rightPage,
    Position = UDim2.fromScale(0.09, 0.12),
    Size = UDim2.fromScale(0.82, 0.76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 4,
})

local rightTitle = create("TextLabel", {
    Parent = rightContent,
    Size = UDim2.fromScale(0.58, 0.11),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Write a Name",
    TextColor3 = Color3.fromRGB(39, 33, 26),
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = rightTitle,
    MinTextSize = 12,
    MaxTextSize = 24,
})

local uninjectButton = create("TextButton", {
    Parent = rightContent,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.fromScale(0.34, 0.11),
    BackgroundColor3 = Color3.fromRGB(224, 205, 168),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "Uninject",
    TextColor3 = Color3.fromRGB(33, 26, 19),
    TextScaled = true,
    Font = Enum.Font.Garamond,
    ZIndex = 6,
})

addCorner(uninjectButton, 0, 6)
addStroke(uninjectButton, Color3.fromRGB(31, 25, 19), 1.5, 0.18)

create("UITextSizeConstraint", {
    Parent = uninjectButton,
    MinTextSize = 10,
    MaxTextSize = 18,
})

local rightSubtitle = create("TextLabel", {
    Parent = rightContent,
    Position = UDim2.fromScale(0, 0.1),
    Size = UDim2.fromScale(1, 0.08),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Type a player username from this server.",
    TextColor3 = Color3.fromRGB(69, 57, 43),
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = rightSubtitle,
    MinTextSize = 9,
    MaxTextSize = 16,
})

addLine(rightContent, UDim2.fromScale(0.5, 0.205), UDim2.fromScale(1, 0.006), 0, 0.35, 5)

local nameBox = create("TextBox", {
    Parent = rightContent,
    Position = UDim2.fromScale(0, 0.25),
    Size = UDim2.fromScale(1, 0.12),
    BackgroundColor3 = Color3.fromRGB(236, 222, 188),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    PlaceholderText = "Username",
    Text = "",
    TextColor3 = Color3.fromRGB(29, 24, 18),
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Garamond,
    ZIndex = 6,
})

addStroke(nameBox, Color3.fromRGB(31, 25, 19), 2, 0.18)

create("UITextSizeConstraint", {
    Parent = nameBox,
    MinTextSize = 12,
    MaxTextSize = 24,
})

local nameBoxPadding = create("UIPadding", {
    Parent = nameBox,
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
})

local killButton = create("TextButton", {
    Parent = rightContent,
    Position = UDim2.fromScale(0, 0.38),
    Size = UDim2.fromScale(1, 0.1),
    BackgroundColor3 = Color3.fromRGB(44, 18, 18),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "KILL",
    TextColor3 = Color3.fromRGB(241, 228, 193),
    TextScaled = true,
    Font = Enum.Font.Garamond,
    ZIndex = 6,
})

addCorner(killButton, 0, 4)
addStroke(killButton, Color3.fromRGB(20, 10, 10), 2, 0.1)

create("UITextSizeConstraint", {
    Parent = killButton,
    MinTextSize = 14,
    MaxTextSize = 22,
})

local function triggerKill()
    local name = nameBox.Text
    local targetPlayer = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
            targetPlayer = p
            break
        end
    end

    if targetPlayer and targetPlayer.Character then
        local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        local rootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

        if humanoid and rootPart then
            KillLogic.FireAttack(humanoid, rootPart.Position)
            
            -- Visual feedback: Quick flicker of the button
            local oldColor = killButton.BackgroundColor3
            killButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            task.delay(0.15, function()
                killButton.BackgroundColor3 = oldColor
            end)
        end
    end
end

local hintLabel = create("TextLabel", {
    Parent = rightContent,
    Position = UDim2.fromScale(0, 0.49),
    Size = UDim2.fromScale(1, 0.06),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "Type a username or click a player below.",
    TextColor3 = Color3.fromRGB(79, 64, 49),
    TextScaled = true,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Garamond,
    ZIndex = 5,
})

create("UITextSizeConstraint", {
    Parent = hintLabel,
    MinTextSize = 8,
    MaxTextSize = 15,
})

local suggestionsFrame = create("ScrollingFrame", {
    Parent = rightContent,
    Position = UDim2.fromScale(0, 0.56),
    Size = UDim2.fromScale(1, 0.41),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(53, 43, 31),
    ScrollingDirection = Enum.ScrollingDirection.Y,
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    ZIndex = 5,
})

local suggestionsPadding = create("UIPadding", {
    Parent = suggestionsFrame,
    PaddingRight = UDim.new(0, 4),
})

local suggestionsLayout = create("UIListLayout", {
    Parent = suggestionsFrame,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local currentBookWidth = DEFAULT_BOOK_WIDTH
local currentBookHeight = round(DEFAULT_BOOK_WIDTH / BOOK_ASPECT)
local isCleaningUp = false
local isUiVisible = true

local function getViewportSize()
    local size = backdrop.AbsoluteSize
    if size.X > 0 and size.Y > 0 then
        return size
    end

    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(1280, 720)
end

local function getWidthBounds()
    local viewport = getViewportSize()
    local maxWidth = math.min(
        MAX_BOOK_WIDTH,
        math.max(ABSOLUTE_MIN_BOOK_WIDTH, viewport.X - VIEWPORT_MARGIN),
        math.max(ABSOLUTE_MIN_BOOK_WIDTH, (viewport.Y - VIEWPORT_MARGIN) * BOOK_ASPECT)
    )

    local minWidth = math.min(TARGET_MIN_BOOK_WIDTH, maxWidth)

    return minWidth, maxWidth
end

local function clampBookCenter(centerX, centerY, width, height)
    local viewport = getViewportSize()
    local halfWidth = width * 0.5
    local halfHeight = height * 0.5

    local minX = halfWidth + 8
    local maxX = viewport.X - halfWidth - 8
    local minY = halfHeight + 8
    local maxY = viewport.Y - halfHeight - 8

    if maxX >= minX then
        centerX = math.clamp(centerX, minX, maxX)
    else
        centerX = viewport.X * 0.5
    end

    if maxY >= minY then
        centerY = math.clamp(centerY, minY, maxY)
    else
        centerY = viewport.Y * 0.5
    end

    return centerX, centerY
end

local function applyBookWidth(proposedWidth, pinnedTopLeft)
    local minWidth, maxWidth = getWidthBounds()
    local clampedWidth = math.clamp(proposedWidth, minWidth, maxWidth)
    local clampedHeight = round(clampedWidth / BOOK_ASPECT)

    currentBookWidth = clampedWidth
    currentBookHeight = clampedHeight

    bookHolder.Size = UDim2.fromOffset(clampedWidth, clampedHeight)

    local centerX
    local centerY

    if pinnedTopLeft then
        centerX = pinnedTopLeft.X + (clampedWidth * 0.5)
        centerY = pinnedTopLeft.Y + (clampedHeight * 0.5)
    else
        centerX = bookHolder.Position.X.Offset
        centerY = bookHolder.Position.Y.Offset
    end

    centerX, centerY = clampBookCenter(centerX, centerY, clampedWidth, clampedHeight)
    bookHolder.Position = UDim2.fromOffset(centerX, centerY)
end

local function centerBook()
    local viewport = getViewportSize()
    applyBookWidth(DEFAULT_BOOK_WIDTH)
    bookHolder.Position = UDim2.fromOffset(viewport.X * 0.5, viewport.Y * 0.5)
    applyBookWidth(currentBookWidth)
end

local function getMatchRank(player, queryLower)
    if queryLower == "" then
        return 4
    end

    local nameLower = string.lower(player.Name)
    local displayLower = string.lower(player.DisplayName)

    if nameLower == queryLower then
        return 0
    end

    if string.sub(nameLower, 1, #queryLower) == queryLower then
        return 1
    end

    if string.sub(displayLower, 1, #queryLower) == queryLower then
        return 2
    end

    if string.find(nameLower, queryLower, 1, true) then
        return 3
    end

    if string.find(displayLower, queryLower, 1, true) then
        return 4
    end

    return 99
end

local function getMatchingPlayers(query)
    local queryLower = string.lower(query)
    local entries = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local rank = getMatchRank(player, queryLower)
        if queryLower == "" or rank < 99 then
            table.insert(entries, {
                Player = player,
                Rank = rank,
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank < b.Rank
        end

        return string.lower(a.Player.Name) < string.lower(b.Player.Name)
    end)

    local matches = {}
    for _, entry in ipairs(entries) do
        table.insert(matches, entry.Player)
    end

    return matches
end

local currentSuggestedName = nil

local function refreshSuggestionCanvas()
    suggestionsFrame.CanvasSize = UDim2.fromOffset(0, suggestionsLayout.AbsoluteContentSize.Y + 6)
end

local function applySuggestedName(playerName)
    nameBox.Text = playerName
    nameBox.CursorPosition = #playerName + 1
end

local function acceptTopSuggestion()
    if currentSuggestedName and string.lower(nameBox.Text) ~= string.lower(currentSuggestedName) then
        applySuggestedName(currentSuggestedName)
        return true
    end

    return false
end

local function setUiVisible(visible)
    if isCleaningUp then
        return
    end

    isUiVisible = visible
    backdrop.Visible = visible
    modalButton.Visible = visible
    customCursor.Visible = visible

    if not visible then
        stopDragging()
        stopResizing()
    end
end

cleanup = function()
    if isCleaningUp then
        return
    end

    isCleaningUp = true
    stopDragging()
    stopResizing()

    for _, connection in ipairs(connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end

    table.clear(connections)

    if screenGui.Parent then
        screenGui:Destroy()
    end

    if script and script:IsA("LocalScript") then
        task.defer(function()
            if script.Parent then
                script:Destroy()
            end
        end)
    end
end

local function refreshSuggestions()
    for _, child in ipairs(suggestionsFrame:GetChildren()) do
        if child:IsA("GuiButton") or child.Name == "EmptyState" then
            child:Destroy()
        end
    end

    local query = nameBox.Text
    local matches = getMatchingPlayers(query)

    if query == "" then
        currentSuggestedName = nil
        hintLabel.Text = "Type a username or click a player below."
    else
        currentSuggestedName = matches[1] and matches[1].Name or nil

        if currentSuggestedName and string.lower(currentSuggestedName) ~= string.lower(query) then
            hintLabel.Text = 'Press Enter or Tab to autofill "' .. currentSuggestedName .. '".'
        elseif currentSuggestedName then
            hintLabel.Text = "Exact player match."
        else
            hintLabel.Text = "No player matches the current text."
        end
    end

    local visibleCount = math.min(MAX_SUGGESTIONS, #matches)

    if visibleCount == 0 then
        create("TextLabel", {
            Parent = suggestionsFrame,
            Name = "EmptyState",
            Size = UDim2.new(1, -2, 0, 34),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "No players found in this server.",
            TextColor3 = Color3.fromRGB(82, 67, 50),
            TextScaled = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Font = Enum.Font.Garamond,
            ZIndex = 5,
        })
    else
        for index = 1, visibleCount do
            local player = matches[index]
            local isTopMatch = query ~= "" and currentSuggestedName == player.Name
            local button = create("TextButton", {
                Parent = suggestionsFrame,
                Size = UDim2.new(1, -2, 0, 38),
                BackgroundColor3 = isTopMatch and Color3.fromRGB(225, 206, 168) or Color3.fromRGB(234, 219, 186),
                BackgroundTransparency = isTopMatch and 0.05 or 0.14,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = player.DisplayName == player.Name and player.Name or (player.Name .. " (" .. player.DisplayName .. ")"),
                TextColor3 = Color3.fromRGB(30, 24, 18),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = Enum.Font.Garamond,
                LayoutOrder = index,
                ZIndex = 6,
            })

            addStroke(button, Color3.fromRGB(31, 25, 19), 1.5, 0.28)

            create("UIPadding", {
                Parent = button,
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
            })

            create("UITextSizeConstraint", {
                Parent = button,
                MinTextSize = 10,
                MaxTextSize = 18,
            })

            button.MouseButton1Click:Connect(function()
                applySuggestedName(player.Name)
                refreshSuggestions()
                task.defer(function()
                    nameBox:CaptureFocus()
                end)
            end)
        end
    end

    refreshSuggestionCanvas()
end

refreshSuggestionCanvas()
centerBook()
refreshSuggestions()

connect(nameBox:GetPropertyChangedSignal("Text"), refreshSuggestions)
connect(Players.PlayerAdded, refreshSuggestions)
connect(Players.PlayerRemoving, refreshSuggestions)
connect(suggestionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), refreshSuggestionCanvas)
connect(backdrop:GetPropertyChangedSignal("AbsoluteSize"), function()
    applyBookWidth(currentBookWidth)
end)

connect(killButton.MouseButton1Click, triggerKill)

connect(nameBox.FocusLost, function(enterPressed)
    if enterPressed then
        if not acceptTopSuggestion() then
            -- If no suggestion was accepted (already matched or no matches), try to kill
            triggerKill()
        end
    end
end)

connect(uninjectButton.MouseButton1Click, cleanup)

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if input.KeyCode == TOGGLE_KEY then
        setUiVisible(not isUiVisible)
        return
    end

    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.Tab and UserInputService:GetFocusedTextBox() == nameBox then
        if acceptTopSuggestion() then
            task.defer(function()
                nameBox:CaptureFocus()
            end)
        end
    end
end)

local dragging = false
local resizing = false
local dragStartInput
local dragStartCenter
local resizeStartInput
local resizeStartWidth
local resizeStartTopLeft

stopDragging = function()
    dragging = false
    dragStartInput = nil
    dragStartCenter = nil
end

stopResizing = function()
    resizing = false
    resizeStartInput = nil
    resizeStartWidth = nil
    resizeStartTopLeft = nil
end

local function beginDrag(input)
    if resizing then
        return
    end

    dragging = true
    dragStartInput = input.Position
    dragStartCenter = Vector2.new(bookHolder.Position.X.Offset, bookHolder.Position.Y.Offset)

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            stopDragging()
        end
    end)
end

local function beginResize(input)
    if dragging then
        return
    end

    resizing = true
    resizeStartInput = input.Position
    resizeStartWidth = currentBookWidth
    resizeStartTopLeft = Vector2.new(
        bookHolder.Position.X.Offset - (currentBookWidth * 0.5),
        bookHolder.Position.Y.Offset - (currentBookHeight * 0.5)
    )

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            stopResizing()
        end
    end)
end

connect(dragHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)

connect(resizeHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        beginResize(input)
    end
end)

connect(RunService.RenderStepped, function()
    if isUiVisible and not isCleaningUp then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        
        -- Force cursor icon visibility
        local mouse = localPlayer:GetMouse()
        if mouse and mouse.Icon == "" then
            mouse.Icon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
        end

        -- Custom UI Cursor Tracking
        local mousePos = UserInputService:GetMouseLocation()
        customCursor.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
        customCursor.Visible = true
    else
        customCursor.Visible = false
    end
end)

connect(UserInputService.InputChanged, function(input)
    if dragging and dragStartInput and dragStartCenter then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStartInput
            local centerX = dragStartCenter.X + delta.X
            local centerY = dragStartCenter.Y + delta.Y

            centerX, centerY = clampBookCenter(centerX, centerY, currentBookWidth, currentBookHeight)
            bookHolder.Position = UDim2.fromOffset(centerX, centerY)
        end
    elseif resizing and resizeStartInput and resizeStartWidth and resizeStartTopLeft then
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - resizeStartInput
            local widthDelta = round((delta.X + (delta.Y * BOOK_ASPECT)) * 0.5)

            applyBookWidth(resizeStartWidth + widthDelta, resizeStartTopLeft)
        end
    end
end)
