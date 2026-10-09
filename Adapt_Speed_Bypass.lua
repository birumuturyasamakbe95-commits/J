-- ADAPT Speed Bypass (GUI redesigned to match reference)
-- Core bypass logic preserved from Miro Speed Bypass

local Services = {
    Players = game:GetService("Players"),
    UserInput = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    Tween = game:GetService("TweenService"),
    Http = game:GetService("HttpService"),
}

local LocalPlayer = Services.Players.LocalPlayer or Services.Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--=====================================================================
-- CONFIG
--=====================================================================
local CONSTANTS = {
    CONFIG_FILE = "AdaptSpeedBypass.json",
    GUI_NAME = "AdaptSpeedBypass",

    DEPTH = 296,
    SPAM_DELAY = 0.12,
    MIN_POWER = 1,
    MAX_POWER = 500000,

    DEFAULT_POWER_PC = 97000,
    DEFAULT_POWER_MOBILE = 65000,

    POWER_STEP = 1000,

    BG_ASSET = "95483558097214",
    TITLE_ASSET = "136691145364157",
    DISCORD = "https://discord.gg/adapt",
}

--=====================================================================
-- THEME (photo style)
--=====================================================================
local Theme = {
    Panel = Color3.fromRGB(12, 12, 14),
    PanelAlt = Color3.fromRGB(18, 18, 22),
    PanelSoft = Color3.fromRGB(22, 22, 26),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(170, 170, 175),
    Accent = Color3.fromRGB(255, 255, 255),
    Stroke = Color3.fromRGB(55, 55, 60),
    StrokeSoft = Color3.fromRGB(40, 40, 45),
    BorderGlow = Color3.fromRGB(200, 60, 40),
    Active = Color3.fromRGB(255, 255, 255),
    Inactive = Color3.fromRGB(140, 140, 145),
}

--=====================================================================
-- STATE
--=====================================================================
local State = {
    enabled = false,
    powerValue = CONSTANTS.DEFAULT_POWER_PC,
    mode = "PC",
    toggleKey = Enum.KeyCode.V,
    isVisible = true,
    listeningKey = false,
}

local Bypass = {
    running = false,
    bomb = nil,
    thread = nil,
    startedAt = 0,
}

--=====================================================================
-- CONFIG SAVE / LOAD
--=====================================================================
local function saveConfig()
    pcall(function()
        local data = {
            Enabled = State.enabled,
            PowerValue = State.powerValue,
            Mode = State.mode,
            ToggleKey = State.toggleKey.Name,
            IsVisible = State.isVisible,
        }
        writefile(CONSTANTS.CONFIG_FILE, Services.Http:JSONEncode(data))
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
        if data.ToggleKey and Enum.KeyCode[data.ToggleKey] then
            State.toggleKey = Enum.KeyCode[data.ToggleKey]
        end
    end)
end

--=====================================================================
-- BYPASS ENGINE
--=====================================================================
local function buildBomb(power)
    local spammed = {}
    table.insert(spammed, {})
    local z = spammed[1]
    for _ = 1, CONSTANTS.DEPTH do
        local nextTable = {}
        table.insert(z, nextTable)
        z = nextTable
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
    if Bypass.thread then
        pcall(task.cancel, Bypass.thread)
    end
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
    if State.enabled then
        startBypass(State.powerValue)
    end
end

--=====================================================================
-- UI HELPERS
--=====================================================================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1.2
    s.Transparency = transparency or 0.15
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function setImage(img, id)
    if not img then return end
    id = tostring(id or "")
    img.Image = "rbxassetid://" .. id
    task.delay(0.4, function()
        if not img or not img.Parent then return end
        local loaded = false
        pcall(function() loaded = img.IsLoaded end)
        if not loaded then
            img.Image = "rbxthumb://type=Asset&id=" .. id .. "&w=768&h=432"
        end
    end)
end

--=====================================================================
-- BUILD GUI
--=====================================================================
local Refs = {}

local function destroyOld()
    local old = PlayerGui:FindFirstChild(CONSTANTS.GUI_NAME)
    if old then old:Destroy() end
    pcall(function()
        local cg = game:GetService("CoreGui")
        local o = cg:FindFirstChild(CONSTANTS.GUI_NAME)
        if o then o:Destroy() end
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
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function buildGui()
    destroyOld()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = CONSTANTS.GUI_NAME
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 120
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(screenGui) end
    end)
    local ok = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not ok then screenGui.Parent = PlayerGui end

    -- Outer glow border (red/orange like photo)
    local outer = Instance.new("Frame")
    outer.Name = "Outer"
    outer.Size = UDim2.new(0, 340, 0, 268)
    outer.Position = UDim2.new(0.5, -170, 0.5, -134)
    outer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    outer.BackgroundTransparency = 1
    outer.BorderSizePixel = 0
    outer.Parent = screenGui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(1, 0, 1, 0)
    main.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    main.BackgroundTransparency = 0.08
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = outer
    corner(main, 18)
    local mainStroke = stroke(main, Theme.BorderGlow, 2.2, 0.25)

    -- Background image
    local bg = Instance.new("ImageLabel")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundTransparency = 1
    bg.ScaleType = Enum.ScaleType.Crop
    bg.ImageTransparency = 0.35
    bg.ZIndex = 0
    bg.Parent = main
    setImage(bg, CONSTANTS.BG_ASSET)

    -- Dark wash so text stays readable
    local wash = Instance.new("Frame")
    wash.Size = UDim2.new(1, 0, 1, 0)
    wash.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    wash.BackgroundTransparency = 0.45
    wash.BorderSizePixel = 0
    wash.ZIndex = 1
    wash.Parent = main
    corner(wash, 18)

    -- Content padding container
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -24, 1, -24)
    content.Position = UDim2.new(0, 12, 0, 12)
    content.BackgroundTransparency = 1
    content.ZIndex = 5
    content.Parent = main

    ----------------------------------------------------------------
    -- HEADER CARD (ADAPT + discord + PC/MOBILE + minimize)
    ----------------------------------------------------------------
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 78)
    header.BackgroundColor3 = Theme.Panel
    header.BackgroundTransparency = 0.25
    header.BorderSizePixel = 0
    header.ZIndex = 6
    header.Parent = content
    corner(header, 14)
    stroke(header, Theme.Stroke, 1.1, 0.35)

    -- ADAPT title image
    local titleImg = Instance.new("ImageLabel")
    titleImg.Name = "AdaptTitle"
    titleImg.Size = UDim2.new(0, 150, 0, 42)
    titleImg.Position = UDim2.new(0, 14, 0, 8)
    titleImg.BackgroundTransparency = 1
    titleImg.ScaleType = Enum.ScaleType.Fit
    titleImg.ZIndex = 8
    titleImg.Parent = header
    setImage(titleImg, CONSTANTS.TITLE_ASSET)

    -- Fallback text if image fails
    local titleFallback = Instance.new("TextLabel")
    titleFallback.Name = "AdaptFallback"
    titleFallback.Size = UDim2.new(0, 150, 0, 42)
    titleFallback.Position = UDim2.new(0, 14, 0, 8)
    titleFallback.BackgroundTransparency = 1
    titleFallback.Text = "ADAPT"
    titleFallback.Font = Enum.Font.GothamBlack
    titleFallback.TextSize = 28
    titleFallback.TextColor3 = Theme.Text
    titleFallback.TextXAlignment = Enum.TextXAlignment.Left
    titleFallback.TextStrokeTransparency = 0.6
    titleFallback.ZIndex = 7
    titleFallback.Parent = header
    task.delay(1.2, function()
        if titleImg and titleImg.Parent then
            local loaded = false
            pcall(function() loaded = titleImg.IsLoaded end)
            if loaded and titleFallback then
                titleFallback.Visible = false
            end
        end
    end)

    -- Discord under title
    local discordLbl = Instance.new("TextLabel")
    discordLbl.Name = "Discord"
    discordLbl.Size = UDim2.new(0, 180, 0, 18)
    discordLbl.Position = UDim2.new(0, 16, 0, 52)
    discordLbl.BackgroundTransparency = 1
    discordLbl.Text = CONSTANTS.DISCORD
    discordLbl.Font = Enum.Font.Gotham
    discordLbl.TextSize = 11
    discordLbl.TextColor3 = Theme.TextDim
    discordLbl.TextXAlignment = Enum.TextXAlignment.Left
    discordLbl.ZIndex = 8
    discordLbl.Parent = header

    -- Minimize button
    local minBtn = Instance.new("TextButton")
    minBtn.Name = "Minimize"
    minBtn.Size = UDim2.new(0, 28, 0, 22)
    minBtn.Position = UDim2.new(1, -34, 0, 8)
    minBtn.BackgroundColor3 = Theme.PanelSoft
    minBtn.BackgroundTransparency = 0.2
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Theme.Text
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 10
    minBtn.Parent = header
    corner(minBtn, 7)
    stroke(minBtn, Theme.Stroke, 1, 0.4)

    -- Mode container (PC / MOBILE)
    local modeBox = Instance.new("Frame")
    modeBox.Name = "ModeBox"
    modeBox.Size = UDim2.new(0, 132, 0, 34)
    modeBox.Position = UDim2.new(1, -148, 0, 34)
    modeBox.BackgroundColor3 = Theme.PanelAlt
    modeBox.BackgroundTransparency = 0.15
    modeBox.BorderSizePixel = 0
    modeBox.ZIndex = 8
    modeBox.Parent = header
    corner(modeBox, 10)
    stroke(modeBox, Theme.Stroke, 1, 0.4)

    local pcBtn = Instance.new("TextButton")
    pcBtn.Name = "PC"
    pcBtn.Size = UDim2.new(0.5, -4, 1, -6)
    pcBtn.Position = UDim2.new(0, 3, 0, 3)
    pcBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    pcBtn.BackgroundTransparency = 0.12
    pcBtn.BorderSizePixel = 0
    pcBtn.Text = "PC"
    pcBtn.Font = Enum.Font.GothamBold
    pcBtn.TextSize = 12
    pcBtn.TextColor3 = Color3.fromRGB(10, 10, 12)
    pcBtn.AutoButtonColor = false
    pcBtn.ZIndex = 9
    pcBtn.Parent = modeBox
    corner(pcBtn, 8)

    local mobileBtn = Instance.new("TextButton")
    mobileBtn.Name = "Mobile"
    mobileBtn.Size = UDim2.new(0.5, -4, 1, -6)
    mobileBtn.Position = UDim2.new(0.5, 1, 0, 3)
    mobileBtn.BackgroundColor3 = Theme.PanelSoft
    mobileBtn.BackgroundTransparency = 1
    mobileBtn.BorderSizePixel = 0
    mobileBtn.Text = "MOBILE"
    mobileBtn.Font = Enum.Font.GothamBold
    mobileBtn.TextSize = 11
    mobileBtn.TextColor3 = Theme.Inactive
    mobileBtn.AutoButtonColor = false
    mobileBtn.ZIndex = 9
    mobileBtn.Parent = modeBox
    corner(mobileBtn, 8)

    ----------------------------------------------------------------
    -- POWER CARD
    ----------------------------------------------------------------
    local powerCard = Instance.new("Frame")
    powerCard.Name = "PowerCard"
    powerCard.Size = UDim2.new(1, 0, 0, 88)
    powerCard.Position = UDim2.new(0, 0, 0, 90)
    powerCard.BackgroundColor3 = Theme.Panel
    powerCard.BackgroundTransparency = 0.25
    powerCard.BorderSizePixel = 0
    powerCard.ZIndex = 6
    powerCard.Parent = content
    corner(powerCard, 14)
    stroke(powerCard, Theme.Stroke, 1.1, 0.35)

    local powerTitle = Instance.new("TextLabel")
    powerTitle.Size = UDim2.new(1, -20, 0, 22)
    powerTitle.Position = UDim2.new(0, 14, 0, 8)
    powerTitle.BackgroundTransparency = 1
    powerTitle.Text = "POWER:"
    powerTitle.Font = Enum.Font.GothamBold
    powerTitle.TextSize = 13
    powerTitle.TextColor3 = Theme.Text
    powerTitle.TextXAlignment = Enum.TextXAlignment.Left
    powerTitle.ZIndex = 7
    powerTitle.Parent = powerCard

    -- Status pill (ENABLED / DISABLED)
    local statusPill = Instance.new("TextButton")
    statusPill.Name = "Status"
    statusPill.Size = UDim2.new(0, 92, 0, 22)
    statusPill.Position = UDim2.new(1, -106, 0, 8)
    statusPill.BackgroundColor3 = Theme.PanelSoft
    statusPill.BackgroundTransparency = 0.2
    statusPill.BorderSizePixel = 0
    statusPill.Text = "DISABLED"
    statusPill.Font = Enum.Font.GothamBold
    statusPill.TextSize = 11
    statusPill.TextColor3 = Theme.TextDim
    statusPill.AutoButtonColor = false
    statusPill.ZIndex = 8
    statusPill.Parent = powerCard
    corner(statusPill, 8)
    stroke(statusPill, Theme.Stroke, 1, 0.4)

    -- Controls row
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(1, -20, 0, 40)
    controls.Position = UDim2.new(0, 10, 0, 38)
    controls.BackgroundTransparency = 1
    controls.ZIndex = 7
    controls.Parent = powerCard

    local leftBtn = Instance.new("TextButton")
    leftBtn.Name = "PowerDown"
    leftBtn.Size = UDim2.new(0, 40, 0, 40)
    leftBtn.Position = UDim2.new(0, 0, 0, 0)
    leftBtn.BackgroundColor3 = Theme.PanelAlt
    leftBtn.BackgroundTransparency = 0.1
    leftBtn.BorderSizePixel = 0
    leftBtn.Text = "◀"
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextSize = 16
    leftBtn.TextColor3 = Theme.Text
    leftBtn.AutoButtonColor = false
    leftBtn.ZIndex = 8
    leftBtn.Parent = controls
    corner(leftBtn, 10)
    stroke(leftBtn, Theme.Stroke, 1, 0.35)

    local powerBox = Instance.new("TextBox")
    powerBox.Name = "PowerValue"
    powerBox.Size = UDim2.new(1, -100, 0, 40)
    powerBox.Position = UDim2.new(0, 50, 0, 0)
    powerBox.BackgroundColor3 = Theme.PanelAlt
    powerBox.BackgroundTransparency = 0.15
    powerBox.BorderSizePixel = 0
    powerBox.Text = tostring(State.powerValue)
    powerBox.Font = Enum.Font.GothamBlack
    powerBox.TextSize = 22
    powerBox.TextColor3 = Theme.Text
    powerBox.ClearTextOnFocus = false
    powerBox.TextXAlignment = Enum.TextXAlignment.Center
    powerBox.ZIndex = 8
    powerBox.Parent = controls
    corner(powerBox, 10)
    stroke(powerBox, Theme.Stroke, 1, 0.35)

    local rightBtn = Instance.new("TextButton")
    rightBtn.Name = "PowerUp"
    rightBtn.Size = UDim2.new(0, 40, 0, 40)
    rightBtn.Position = UDim2.new(1, -40, 0, 0)
    rightBtn.BackgroundColor3 = Theme.PanelAlt
    rightBtn.BackgroundTransparency = 0.1
    rightBtn.BorderSizePixel = 0
    rightBtn.Text = "▶"
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextSize = 16
    rightBtn.TextColor3 = Theme.Text
    rightBtn.AutoButtonColor = false
    rightBtn.ZIndex = 8
    rightBtn.Parent = controls
    corner(rightBtn, 10)
    stroke(rightBtn, Theme.Stroke, 1, 0.35)

    ----------------------------------------------------------------
    -- HOTKEY CARD
    ----------------------------------------------------------------
    local keyCard = Instance.new("Frame")
    keyCard.Name = "HotkeyCard"
    keyCard.Size = UDim2.new(1, 0, 0, 52)
    keyCard.Position = UDim2.new(0, 0, 0, 190)
    keyCard.BackgroundColor3 = Theme.Panel
    keyCard.BackgroundTransparency = 0.25
    keyCard.BorderSizePixel = 0
    keyCard.ZIndex = 6
    keyCard.Parent = content
    corner(keyCard, 14)
    stroke(keyCard, Theme.Stroke, 1.1, 0.35)

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(0.5, 0, 1, 0)
    keyLabel.Position = UDim2.new(0, 16, 0, 0)
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
    keyBtn.Size = UDim2.new(0, 52, 0, 32)
    keyBtn.Position = UDim2.new(1, -66, 0.5, -16)
    keyBtn.BackgroundColor3 = Theme.PanelAlt
    keyBtn.BackgroundTransparency = 0.1
    keyBtn.BorderSizePixel = 0
    keyBtn.Text = State.toggleKey.Name
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 14
    keyBtn.TextColor3 = Theme.Text
    keyBtn.AutoButtonColor = false
    keyBtn.ZIndex = 8
    keyBtn.Parent = keyCard
    corner(keyBtn, 10)
    stroke(keyBtn, Theme.Stroke, 1, 0.35)

    ----------------------------------------------------------------
    -- REFS
    ----------------------------------------------------------------
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
        fullSize = UDim2.new(0, 340, 0, 268),
        miniSize = UDim2.new(0, 340, 0, 102),
    }

    makeDraggable(header, outer)
    makeDraggable(main, outer)

    return Refs
end

--=====================================================================
-- UI REFRESH
--=====================================================================
local function refreshMode()
    local pc, mb = Refs.pcBtn, Refs.mobileBtn
    if not pc or not mb then return end
    if State.mode == "PC" then
        pc.BackgroundTransparency = 0.12
        pc.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        pc.TextColor3 = Color3.fromRGB(10, 10, 12)
        mb.BackgroundTransparency = 1
        mb.TextColor3 = Theme.Inactive
    else
        mb.BackgroundTransparency = 0.12
        mb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        mb.TextColor3 = Color3.fromRGB(10, 10, 12)
        pc.BackgroundTransparency = 1
        pc.TextColor3 = Theme.Inactive
    end
end

local function refreshStatus()
    local pill = Refs.statusPill
    local strokeObj = Refs.mainStroke
    if not pill then return end
    if State.enabled then
        pill.Text = "ENABLED"
        pill.TextColor3 = Color3.fromRGB(80, 255, 140)
        if strokeObj then strokeObj.Color = Color3.fromRGB(60, 200, 100) end
    else
        pill.Text = "DISABLED"
        pill.TextColor3 = Theme.TextDim
        if strokeObj then strokeObj.Color = Theme.BorderGlow end
    end
end

local function refreshPower()
    if Refs.powerBox then
        Refs.powerBox.Text = tostring(State.powerValue)
    end
end

local function refreshKey()
    if Refs.keyBtn then
        Refs.keyBtn.Text = State.toggleKey.Name
        Refs.keyBtn.TextColor3 = Theme.Text
    end
end

local function refreshVisibility()
    local visible = State.isVisible
    if Refs.powerCard then Refs.powerCard.Visible = visible end
    if Refs.keyCard then Refs.keyCard.Visible = visible end
    if Refs.outer then
        Refs.outer.Size = visible and Refs.fullSize or Refs.miniSize
    end
    if Refs.minBtn then
        Refs.minBtn.Text = visible and "—" or "+"
    end
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
    if State.enabled then
        startBypass(State.powerValue)
    else
        stopBypass()
    end
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

    -- Hold to spam power change
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
        if val then
            setPower(val)
        else
            refreshPower()
        end
    end)

    r.keyBtn.MouseButton1Click:Connect(function()
        if State.listeningKey then return end
        State.listeningKey = true
        r.keyBtn.Text = "..."
        r.keyBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
        local conn
        conn = Services.UserInput.InputBegan:Connect(function(input, gpe)
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

    -- Global hotkey
    Services.UserInput.InputBegan:Connect(function(input, gpe)
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
bindEvents()

if State.enabled then
    startBypass(State.powerValue)
end

_G.AdaptSpeedBypass = {
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

print("[ADAPT] Speed Bypass loaded")
