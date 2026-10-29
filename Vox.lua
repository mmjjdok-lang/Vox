--[[
    VOX HUB UI Library v2  |  5D Glass UI
    1) Intro   2) Library   3) Demo (uses every system)

    New in v2:
      Optional mini button | Heartbeat floating toggle | Opaque tabs + tab animations
      Note / Label / Tag systems | Config saving (Flags) | Player card (bottom-left)
      Top buttons: Hide / Collapse-to-title / X with legendary confirmation

    Update:
      Higher contrast (tabs frame, elements, window)
      Floating button has no X; the mini + button toggles it (+ add / - remove)
]]
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local Font = Enum.Font
local Left, Right, Center = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local ICONS_URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/solar/dist/Icons.lua"

-- ==========================================================
-- Helpers
-- ==========================================================
local AllConns = {}
local function Conn(sig, fn)
    local c = sig:Connect(fn)
    table.insert(AllConns, c)
    return c
end

local function New(class, props, kids)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for _, k in ipairs(kids or {}) do k.Parent = o end
    if parent then o.Parent = parent end
    return o
end

local function Tween(o, t, p, style, dir)
    local tw = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
    tw:Play()
    return tw
end

local function Corner(p, r) return New("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end
local function Stroke(p, c, t, tr) return New("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p}) end

local function Mount(gui)
    local ok = pcall(function() gui.Parent = CoreGui end)
    if not ok or not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local function Clean(name)
    pcall(function() local o = CoreGui:FindFirstChild(name) if o then o:Destroy() end end)
    local pg = LP:FindFirstChild("PlayerGui")
    if pg and pg:FindFirstChild(name) then pg[name]:Destroy() end
end

-- Icons (Footagesus / solar)
local IconsLib
pcall(function() IconsLib = loadstring(game:HttpGet(ICONS_URL))() end)
pcall(function() IconsLib.SetIconsType("solar") end)

local function ApplyIcon(img, name)
    if name == nil or name == "" then return false end
    if type(name) == "number" then img.Image = "rbxassetid://" .. name return true end
    if type(name) ~= "string" then return false end
    if name:match("^%d+$") then img.Image = "rbxassetid://" .. name return true end
    if name:find("://") then img.Image = name return true end
    if not IconsLib then return false end
    for _, n in ipairs({name, "solar:" .. name}) do
        local ok, res = pcall(function() return IconsLib.Icon(n) end)
        if ok and res then
            if type(res) == "string" then img.Image = res return true end
            if type(res) == "table" then
                local id = res[1] or res.Image or res.Id
                local d = res[2]
                if id then
                    img.Image = type(id) == "number" and ("rbxassetid://" .. id) or tostring(id)
                    if type(d) == "table" then
                        img.ImageRectSize = d.ImageRectSize or Vector2.zero
                        img.ImageRectOffset = d.ImageRectPosition or d.ImageRectOffset or Vector2.zero
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- Water drop ripple
local function Ripple(layer, pos, color, maxS)
    maxS = maxS or 240
    local rel = pos - layer.AbsolutePosition
    local function circle(tr)
        local c = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rel.X, rel.Y), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = color, BackgroundTransparency = tr, BorderSizePixel = 0, ZIndex = 100, Parent = layer})
        Corner(c, 999)
        return c
    end
    local drop = circle(0.55)
    Tween(drop, 0.7, {Size = UDim2.fromOffset(maxS, maxS), BackgroundTransparency = 1}, Enum.EasingStyle.Quart)
    for i = 1, 2 do
        task.delay((i - 1) * 0.12, function()
            local ring = circle(1)
            local st = Stroke(ring, color, 2.5, 0.15)
            Tween(ring, 0.9, {Size = UDim2.fromOffset(maxS * (1 + i * 0.2), maxS * (1 + i * 0.2))}, Enum.EasingStyle.Quint)
            Tween(st, 0.9, {Transparency = 1})
            Debris:AddItem(ring, 1)
        end)
    end
    Debris:AddItem(drop, 0.8)
end

local Gui

local function TrackDrag(hit, fn, onBegin, onEnd)
    local active
    hit.InputBegan:Connect(function(input)
        if active then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            active = input
            if onBegin then onBegin() end
            fn(input.Position)
        end
    end)
    Conn(UIS.InputChanged, function(input)
        if not active then return end
        if input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
            fn(input.Position)
        end
    end)
    Conn(UIS.InputEnded, function(input)
        if active and (input == active or (input.UserInputType == Enum.UserInputType.MouseButton1 and active.UserInputType == Enum.UserInputType.MouseButton1)) then
            active = nil
            if onEnd then onEnd() end
        end
    end)
end

local function Rel(frame, pos)
    return math.clamp((pos.X - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1),
           math.clamp((pos.Y - frame.AbsolutePosition.Y) / frame.AbsoluteSize.Y, 0, 1)
end

-- One-finger, heavy (smoothed) dragging with tilt. Extra fingers are ignored.
local function Draggable(handle, target, o)
    o = o or {}
    local active, startPt, startCtr, cur, goal, conn
    local dragging, moved = false, 0
    local conns = {}
    local function clampC(p)
        local s = Gui.AbsoluteSize
        return Vector2.new(math.clamp(p.X, 30, s.X - 30), math.clamp(p.Y, 30, s.Y - 30))
    end
    local function step(dt)
        local d = goal - cur
        cur = cur + d * (1 - math.exp(-dt * (o.Speed or 9)))
        local rot = math.clamp(d.X * 0.035, -4, 4)
        target.Rotation = target.Rotation + (rot - target.Rotation) * (1 - math.exp(-dt * 12))
        target.Position = UDim2.fromOffset(cur.X, cur.Y)
        if o.OnStep then o.OnStep(d) end
        if not dragging and d.Magnitude < 0.3 and math.abs(target.Rotation) < 0.05 then
            target.Rotation = 0
            if o.OnStep then o.OnStep(Vector2.zero) end
            conn:Disconnect() conn = nil
        end
    end
    handle.InputBegan:Connect(function(input)
        if active then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        active, dragging, moved = input, true, 0
        startPt = Vector2.new(input.Position.X, input.Position.Y)
        target.AnchorPoint = Vector2.new(0.5, 0.5)
        cur = target.AbsolutePosition + target.AbsoluteSize / 2
        goal, startCtr = cur, cur
        if o.OnBegin then o.OnBegin() end
        if not conn then conn = RS.Heartbeat:Connect(step) end
    end)
    table.insert(conns, Conn(UIS.InputChanged, function(input)
        if not active then return end
        if input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
            local p = Vector2.new(input.Position.X, input.Position.Y)
            moved = math.max(moved, (p - startPt).Magnitude)
            goal = clampC(startCtr + (p - startPt))
        end
    end))
    table.insert(conns, Conn(UIS.InputEnded, function(input)
        if active and (input == active or (input.UserInputType == Enum.UserInputType.MouseButton1 and active.UserInputType == Enum.UserInputType.MouseButton1)) then
            active, dragging = nil, false
            if o.OnEnd then o.OnEnd(moved) end
        end
    end))
    return {Destroy = function() for _, c in ipairs(conns) do c:Disconnect() end if conn then conn:Disconnect() end end}
end

-- ==========================================================
-- Library
-- ==========================================================
local Library = {Themes = {}, Map = {}}

local ThemeData = {
    {"Green", 0, 255, 100}, {"Emerald", 16, 185, 129}, {"Lime", 132, 204, 22}, {"Mint", 110, 231, 183},
    {"Teal", 20, 184, 166}, {"Cyan", 6, 182, 212}, {"Sky", 56, 189, 248}, {"Blue", 59, 130, 246},
    {"Royal", 65, 105, 225}, {"Indigo", 99, 102, 241}, {"Violet", 139, 92, 246}, {"Purple", 168, 85, 247},
    {"Magenta", 217, 70, 239}, {"Pink", 236, 72, 153}, {"Rose", 244, 63, 94}, {"Red", 239, 68, 68},
    {"Crimson", 220, 20, 60}, {"Orange", 249, 115, 22}, {"Amber", 245, 158, 11}, {"Yellow", 250, 204, 21},
    {"Gold", 212, 175, 55}, {"Coral", 255, 127, 80}, {"Salmon", 250, 128, 114}, {"Peach", 255, 180, 140},
    {"Brown", 160, 100, 60}, {"Silver", 192, 192, 200}, {"Gray", 120, 120, 130}, {"Slate", 100, 116, 139},
    {"White", 245, 245, 245}, {"Ruby", 155, 17, 30},
}
Library.ColorNames = {}
for i, t in ipairs(ThemeData) do
    local c = Color3.fromRGB(t[2], t[3], t[4])
    Library.Themes[i] = {Name = t[1], Color = c}
    Library.Map[t[1]:lower()] = c
    Library.ColorNames[i] = t[1]
end

-- Colors are chosen by NAME ("Green", "Red", ...). Color3 is still tolerated.
function Library.ResolveColor(c)
    if type(c) == "string" and Library.Map[c:lower()] then return Library.Map[c:lower()] end
    if typeof(c) == "Color3" then return c end
    if type(c) == "number" and Library.Themes[c] then return Library.Themes[c].Color end
    return Library.Themes[1].Color
end
Library.Accent = Library.Themes[1].Color

Clean("VOX_UI")
Gui = New("ScreenGui", {Name = "VOX_UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999})
Mount(Gui)
Library.Gui = Gui

-- Removes the whole script: connections, windows, floating buttons, notifications
function Library:Unload()
    for _, c in ipairs(AllConns) do pcall(function() c:Disconnect() end) end
    table.clear(AllConns)
    Clean("VOX_KeyGui")
    Clean("VOX_IntroGui")
    pcall(function() Gui:Destroy() end)
end

-- ---------------------------------------------------------- Notify
local NotifyPos = {
    TopRight = {Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Right, UDim2.new(1.2, 0, 0, 0)},
    TopLeft = {Vector2.new(0, 0), UDim2.new(0, 12, 0, 12), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Left, UDim2.new(-1.2, 0, 0, 0)},
    BottomRight = {Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Right, UDim2.new(1.2, 0, 0, 0)},
    BottomLeft = {Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Left, UDim2.new(-1.2, 0, 0, 0)},
    TopCenter = {Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Center, UDim2.new(0, 0, -1.6, 0)},
    BottomCenter = {Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Center, UDim2.new(0, 0, 1.6, 0)},
}
local NotifyHolders = {}

function Library:Notify(c)
    c = c or {}
    local posName = NotifyPos[c.Position] and c.Position or "TopRight"
    local P = NotifyPos[posName]
    local col = c.Color and Library.ResolveColor(c.Color) or Library.Accent
    if not NotifyHolders[posName] or not NotifyHolders[posName].Parent then
        local h = New("Frame", {Name = "N_" .. posName, AnchorPoint = P[1], Position = P[2], Size = UDim2.new(0, 290, 1, -24), BackgroundTransparency = 1, ZIndex = 200, Parent = Gui})
        New("UIListLayout", {Padding = UDim.new(0, 8), VerticalAlignment = P[3], HorizontalAlignment = P[4], SortOrder = Enum.SortOrder.LayoutOrder, Parent = h})
        NotifyHolders[posName] = h
    end
    local outer = New("Frame", {Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, Parent = NotifyHolders[posName]})
    local card = New("TextButton", {Size = UDim2.fromScale(1, 1), Position = P[5], BackgroundColor3 = col:Lerp(BLACK, 0.9), BackgroundTransparency = 0.08, Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = outer})
    Corner(card, 10)
    Stroke(card, col, 1.5, 0.35)
    New("UIGradient", {Color = ColorSequence.new(col:Lerp(BLACK, 0.8), col:Lerp(BLACK, 0.95)), Rotation = 35, Parent = card})
    local ic = New("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(28, 28), ImageColor3 = col, Parent = card})
    if not ApplyIcon(ic, c.Icon) then
        ic:Destroy()
        New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(28, 28), Font = Font.GothamBlack, Text = "!", TextSize = 22, TextColor3 = col, Parent = card})
    end
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 10), Size = UDim2.new(1, -62, 0, 18), Font = Font.GothamBold, Text = c.Title or "Notification", TextSize = 14, TextColor3 = WHITE, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card})
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(50, 29), Size = UDim2.new(1, -62, 0, 30), Font = Font.Gotham, Text = c.Message or "", TextSize = 12, TextColor3 = Color3.fromRGB(190, 200, 195), TextXAlignment = Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = card})
    local track = New("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 3), BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = card})
    Corner(track, 2)
    local bar = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BorderSizePixel = 0, Parent = track})
    Corner(bar, 2)
    New("UIGradient", {Color = ColorSequence.new(col:Lerp(WHITE, 0.35), col), Parent = bar})

    local life = c.Time or 4
    local closed = false
    local function close()
        if closed then return end
        closed = true
        local tw = Tween(card, 0.4, {Position = P[5]}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        tw.Completed:Connect(function()
            Tween(outer, 0.25, {Size = UDim2.new(1, 0, 0, 0)})
            Debris:AddItem(outer, 0.3)
        end)
    end
    Tween(card, 0.55, {Position = UDim2.new()}, Enum.EasingStyle.Back)
    Tween(bar, life, {Size = UDim2.fromScale(0, 1)}, Enum.EasingStyle.Linear)
    task.delay(life, close)
    card.MouseButton1Click:Connect(close)
end

-- ---------------------------------------------------------- Legendary confirmation
-- Hold-to-confirm panel with pulsing warning, shake, rotating border and burst effect.
function Library:Confirm(c)
    c = c or {}
    local col = Library.ResolveColor(c.Color or "Red")
    local hold = c.HoldTime or 1.6

    local layer = New("Frame", {Name = "VOX_Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 500, Parent = Gui})
    local vig = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 500, Parent = layer})
    New("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.6)}), Rotation = 90, Parent = vig})
    Tween(layer, 0.4, {BackgroundTransparency = 0.35})
    Tween(vig, 0.6, {BackgroundTransparency = 0})

    local panel = New("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 252), BackgroundColor3 = col:Lerp(BLACK, 0.93), BackgroundTransparency = 0.03, GroupTransparency = 1, ZIndex = 501, Parent = layer})
    Corner(panel, 14)
    New("UIGradient", {Color = ColorSequence.new(col:Lerp(BLACK, 0.82), col:Lerp(BLACK, 0.96)), Rotation = 60, Parent = panel})
    local pst = Stroke(panel, WHITE, 2.5, 0)
    local pgrad = New("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, col:Lerp(WHITE, 0.4)), ColorSequenceKeypoint.new(0.5, col:Lerp(BLACK, 0.7)), ColorSequenceKeypoint.new(1, col:Lerp(WHITE, 0.4))}), Parent = pst})
    local gc = RS.RenderStepped:Connect(function() pgrad.Rotation = (os.clock() * 120) % 360 end)
    local ps = New("UIScale", {Scale = 0.5, Parent = panel})
    Tween(ps, 0.8, {Scale = 1}, Enum.EasingStyle.Elastic)
    Tween(panel, 0.3, {GroupTransparency = 0})

    -- pulsing warning icon
    local iconHolder = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, Parent = panel})
    local iconBg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = iconHolder})
    Corner(iconBg, 999)
    Stroke(iconBg, col, 2, 0.1)
    New("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Font.GothamBlack, Text = "!", TextSize = 30, TextColor3 = col:Lerp(WHITE, 0.3), Parent = iconBg})
    TS:Create(iconBg, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.fromScale(1.12, 1.12), Position = UDim2.fromScale(-0.06, -0.06)}):Play()
    local alive = true
    task.spawn(function()
        while alive do
            local ring = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, Parent = iconHolder})
            Corner(ring, 999)
            local rs = Stroke(ring, col, 2, 0.2)
            Tween(ring, 1.2, {Size = UDim2.fromOffset(120, 120)}, Enum.EasingStyle.Quad)
            Tween(rs, 1.2, {Transparency = 1})
            Debris:AddItem(ring, 1.3)
            task.wait(0.8)
        end
    end)

    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 24), Font = Font.GothamBlack, Text = c.Title or "ARE YOU SURE?", TextSize = 19, TextColor3 = WHITE, Parent = panel})
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 110), Size = UDim2.new(1, -48, 0, 40), Font = Font.Gotham, Text = c.Message or "This action cannot be undone.", TextSize = 12, TextColor3 = Color3.fromRGB(190, 200, 195), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = panel})

    local holdBtn = New("TextButton", {Position = UDim2.fromOffset(20, 158), Size = UDim2.new(1, -40, 0, 44), BackgroundColor3 = col:Lerp(BLACK, 0.8), Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = panel})
    Corner(holdBtn, 10)
    Stroke(holdBtn, col, 1.5, 0.2)
    local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = col, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = holdBtn})
    New("UIGradient", {Color = ColorSequence.new(col, col:Lerp(WHITE, 0.4)), Parent = fill})
    local txt = New("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Font.GothamBlack, Text = c.ConfirmText or "HOLD TO CONFIRM", TextSize = 14, TextColor3 = WHITE, ZIndex = 3, Parent = holdBtn})

    local cancel = New("TextButton", {Position = UDim2.fromOffset(20, 210), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Text = "Cancel", Font = Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(200, 205, 200), AutoButtonColor = false, Parent = panel})
    Corner(cancel, 8)
    cancel.MouseEnter:Connect(function() Tween(cancel, 0.2, {BackgroundTransparency = 0.8}) end)
    cancel.MouseLeave:Connect(function() Tween(cancel, 0.2, {BackgroundTransparency = 0.92}) end)

    local holding, t0, done, closed = nil, 0, false, false
    local hb, ie
    local function close(after)
        if closed then return end
        closed = true
        alive = false
        if hb then hb:Disconnect() end
        if ie then ie:Disconnect() end
        gc:Disconnect()
        Tween(ps, 0.35, {Scale = 0.8}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        Tween(panel, 0.3, {GroupTransparency = 1})
        Tween(layer, 0.35, {BackgroundTransparency = 1})
        Tween(vig, 0.35, {BackgroundTransparency = 1})
        Debris:AddItem(layer, 0.5)
        if after then task.delay(0.35, after) end
    end
    local function shake()
        task.spawn(function()
            for i = 1, 8 do
                panel.Position = UDim2.new(0.5, (i % 2 == 0 and 1 or -1) * (16 - i * 2), 0.5, 0)
                task.wait(0.03)
            end
            panel.Position = UDim2.fromScale(0.5, 0.5)
        end)
    end
    local function success()
        done = true
        txt.Text = "CONFIRMED"
        fill.Size = UDim2.fromScale(1, 1)
        Tween(fill, 0.2, {BackgroundColor3 = WHITE})
        panel.Position = UDim2.fromScale(0.5, 0.5)
        Ripple(layer, panel.AbsolutePosition + panel.AbsoluteSize / 2, col, 900)
        Tween(ps, 0.25, {Scale = 1.08}, Enum.EasingStyle.Back)
        task.delay(0.35, function() close(c.OnConfirm) end)
    end

    holdBtn.InputBegan:Connect(function(input)
        if holding or done then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            holding, t0 = input, os.clock()
            Tween(holdBtn, 0.2, {BackgroundColor3 = col:Lerp(BLACK, 0.65)})
        end
    end)
    ie = UIS.InputEnded:Connect(function(input)
        if holding and (input == holding or (input.UserInputType == Enum.UserInputType.MouseButton1 and holding.UserInputType == Enum.UserInputType.MouseButton1)) then
            holding = nil
            if not done then
                panel.Position = UDim2.fromScale(0.5, 0.5)
                if fill.Size.X.Scale > 0.05 then shake() end
                txt.Text = c.ConfirmText or "HOLD TO CONFIRM"
            end
        end
    end)
    hb = RS.Heartbeat:Connect(function(dt)
        if done or closed then return end
        if holding then
            local a = math.clamp((os.clock() - t0) / hold, 0, 1)
            fill.Size = UDim2.fromScale(a, 1)
            txt.Text = string.format("HOLDING...  %d%%", math.floor(a * 100))
            panel.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * a * 4, 0.5, math.random(-100, 100) / 100 * a * 4)
            if a >= 1 then success() end
        else
            local s = fill.Size.X.Scale
            if s > 0 then fill.Size = UDim2.fromScale(math.max(0, s - dt * 2.5), 1) end
        end
    end)
    cancel.MouseButton1Click:Connect(function() if not done then close(c.OnCancel) end end)
end

-- ---------------------------------------------------------- Key system
function Library:KeySystem(c)
    c = c or {}
    local col = Library.ResolveColor(c.Color)
    local done = Instance.new("BindableEvent")
    Clean("VOX_KeyGui")
    local kg = New("ScreenGui", {Name = "VOX_KeyGui", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2000})
    Mount(kg)
    local dim = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = kg})
    Tween(dim, 0.5, {BackgroundTransparency = 0.35})
    local panel = New("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 236), BackgroundColor3 = col:Lerp(BLACK, 0.92), BackgroundTransparency = 0.1, GroupTransparency = 1, Parent = dim})
    Corner(panel, 14)
    local pst = Stroke(panel, WHITE, 2, 0)
    local pgrad = New("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, col:Lerp(WHITE, 0.3)), ColorSequenceKeypoint.new(0.5, col:Lerp(BLACK, 0.6)), ColorSequenceKeypoint.new(1, col:Lerp(WHITE, 0.3))}), Parent = pst})
    local gc = RS.RenderStepped:Connect(function() pgrad.Rotation = (os.clock() * 60) % 360 end)
    New("UIGradient", {Color = ColorSequence.new(col:Lerp(BLACK, 0.8), col:Lerp(BLACK, 0.96)), Rotation = 50, Parent = panel})
    local sc = New("UIScale", {Scale = 0.75, Parent = panel})
    Tween(sc, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
    Tween(panel, 0.4, {GroupTransparency = 0})

    local ic = New("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 1, ImageColor3 = col, Parent = panel})
    if not ApplyIcon(ic, c.Icon) then ic:Destroy() end
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 24), Font = Font.GothamBlack, Text = c.Title or "KEY SYSTEM", TextSize = 20, TextColor3 = WHITE, Parent = panel})
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 16), Font = Font.Gotham, Text = c.Description or "Enter your key to continue", TextSize = 12, TextColor3 = Color3.fromRGB(170, 180, 175), Parent = panel})
    local box = New("TextBox", {Position = UDim2.fromOffset(20, 110), Size = UDim2.new(1, -40, 0, 36), BackgroundColor3 = col:Lerp(BLACK, 0.9), BackgroundTransparency = 0.2, PlaceholderText = "Key...", PlaceholderColor3 = Color3.fromRGB(120, 130, 125), Text = "", TextColor3 = WHITE, Font = Font.GothamMedium, TextSize = 14, ClearTextOnFocus = false, Parent = panel})
    Corner(box, 8)
    local bst = Stroke(box, col, 1, 0.5)
    box.Focused:Connect(function() Tween(bst, 0.2, {Transparency = 0, Thickness = 2}) end)
    box.FocusLost:Connect(function() Tween(bst, 0.2, {Transparency = 0.5, Thickness = 1}) end)

    local function mkBtn(text, pos, filled)
        local b = New("TextButton", {Position = pos, Size = UDim2.new(0.5, -26, 0, 38), BackgroundColor3 = col, BackgroundTransparency = filled and 0.1 or 0.85, Text = text, Font = Font.GothamBold, TextSize = 13, TextColor3 = filled and BLACK or col, AutoButtonColor = false, Parent = panel})
        Corner(b, 8)
        Stroke(b, col, 1.5, 0.2)
        local bs = New("UIScale", {Parent = b})
        b.MouseEnter:Connect(function() Tween(bs, 0.2, {Scale = 1.05}, Enum.EasingStyle.Back) end)
        b.MouseLeave:Connect(function() Tween(bs, 0.2, {Scale = 1}) end)
        b.MouseButton1Down:Connect(function() Tween(bs, 0.1, {Scale = 0.94}) end)
        return b
    end
    local getBtn = mkBtn("Get Key", UDim2.fromOffset(20, 164), false)
    local chkBtn = mkBtn("Check Key", UDim2.new(0.5, 6, 0, 164), true)

    getBtn.MouseButton1Click:Connect(function()
        if c.Url then
            pcall(function() setclipboard(c.Url) end)
            Library:Notify({Title = "Key Link", Message = "Link copied to clipboard", Color = c.Color, Time = 3, Icon = c.Icon})
        else
            Library:Notify({Title = "Key Link", Message = "No link provided", Color = "Red", Time = 3})
        end
    end)

    local function getKeys()
        local keys = {}
        if type(c.Key) == "table" then for _, k in ipairs(c.Key) do table.insert(keys, tostring(k)) end
        elseif c.Key then table.insert(keys, tostring(c.Key)) end
        if c.KeyUrl then
            pcall(function() table.insert(keys, (game:HttpGet(c.KeyUrl):match("^%s*(.-)%s*$"))) end)
        end
        return keys
    end

    chkBtn.MouseButton1Click:Connect(function()
        local txt = box.Text:match("^%s*(.-)%s*$")
        local ok = false
        for _, k in ipairs(getKeys()) do if k == txt and txt ~= "" then ok = true end end
        if ok then
            Library:Notify({Title = "Success", Message = "Key accepted", Color = c.Color, Time = 3, Icon = c.Icon})
            if c.Callback then pcall(c.Callback, txt) end
            Tween(sc, 0.4, {Scale = 0.8}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            Tween(panel, 0.35, {GroupTransparency = 1})
            Tween(dim, 0.4, {BackgroundTransparency = 1})
            task.delay(0.5, function() gc:Disconnect() kg:Destroy() done:Fire() end)
        else
            Library:Notify({Title = "Wrong Key", Message = "The key you entered is invalid", Color = "Red", Time = 3})
            task.spawn(function()
                for i = 1, 6 do
                    panel.Position = UDim2.new(0.5, (i % 2 == 0 and 1 or -1) * (14 - i * 2), 0.5, 0)
                    task.wait(0.04)
                end
                panel.Position = UDim2.fromScale(0.5, 0.5)
            end)
        end
    end)
    done.Event:Wait()
    return true
end
Library.Key = Library.KeySystem

-- ---------------------------------------------------------- Window
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = {Visible = true, Floats = {}, Tabs = {}, Flags = {}, Collapsed = false}
    local conns, reg, tags = {}, {}, {}
    local function WConn(sig, fn) local c = Conn(sig, fn) table.insert(conns, c) return c end
    local T = {}
    local function SetT(col)
        col = Library.ResolveColor(col)
        T.Accent = col
        T.Light = col:Lerp(WHITE, 0.35)
        local h, s = col:ToHSV()
        T.Dark = Color3.fromHSV(h, s * 0.7, 0.30)
        T.Deep = Color3.fromHSV(h, s * 0.75, 0.42)   -- tabs frame (solid, clearly visible)
        T.Mid = Color3.fromHSV(h, s * 0.7, 0.36)
        T.Elem = Color3.fromHSV(h, s * 0.65, 0.50)
        T.Text = Color3.fromRGB(250, 252, 251)
        T.Sub = Color3.fromRGB(215, 222, 218)
    end
    SetT(cfg.Color)
    Library.Accent = T.Accent
    local function Reg(fn) fn() table.insert(reg, fn) end

    local size = cfg.Size or UDim2.new(0, 550, 0, 356)
    local Holder = New("Frame", {Name = "VOX_Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, BackgroundTransparency = 1, Parent = Gui})

    -- 5D depth layers
    local layers = {}
    for i = 1, 3 do
        local l = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 7 * i), Size = UDim2.new(1, -14 * i, 1, -4), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.8 + 0.05 * i, BorderSizePixel = 0, ZIndex = i, Parent = Holder})
        Corner(l, 16)
        New("UIGradient", {Transparency = NumberSequence.new(0, 0.4), Rotation = 90, Parent = l})
        Reg(function() l.BackgroundColor3 = T.Accent end)
        layers[i] = {f = l, t = 0.8 + 0.05 * i}
    end

    -- Animated gradient border
    local border = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = Holder})
    Corner(border, 14)
    local bst = New("UIStroke", {Color = WHITE, Thickness = 2, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = border})
    local bgrad = New("UIGradient", {Parent = bst})
    Reg(function()
        bgrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.Light), ColorSequenceKeypoint.new(0.35, T.Accent), ColorSequenceKeypoint.new(0.7, T.Accent:Lerp(BLACK, 0.7)), ColorSequenceKeypoint.new(1, T.Light)})
    end)
    WConn(RS.RenderStepped, function() bgrad.Rotation = (os.clock() * 50) % 360 end)

    -- Main (CanvasGroup => rounded clipping + fade)
    local Main = New("CanvasGroup", {Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -3, 1, -3), BackgroundColor3 = WHITE, BackgroundTransparency = cfg.Transparency or 0.05, ZIndex = 6, Parent = Holder})
    Corner(Main, 13)
    local MainScale = New("UIScale", {Scale = 0.6, Parent = Main})
    local mgrad = New("UIGradient", {Rotation = 45, Parent = Main})
    Reg(function() mgrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, T.Mid), ColorSequenceKeypoint.new(0.5, T.Dark), ColorSequenceKeypoint.new(1, T.Deep)}) end)
    WConn(RS.RenderStepped, function() mgrad.Offset = Vector2.new(math.sin(os.clock() * 0.5) * 0.25, math.cos(os.clock() * 0.4) * 0.25) end)

    for i = 1, 2 do -- floating glow orbs
        local orb = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i == 1 and 0.2 or 0.85, i == 1 and 0.85 or 0.2), Size = UDim2.fromOffset(220, 220), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 1, Parent = Main})
        Corner(orb, 999)
        Reg(function() orb.BackgroundColor3 = T.Accent end)
        TS:Create(orb, TweenInfo.new(5 + i * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.fromScale(i == 1 and 0.45 or 0.6, i == 1 and 0.55 or 0.4)}):Play()
    end

    local RippleLayer = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 100, Parent = Main})
    local Body = New("CanvasGroup", {Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = Main})

    -- Top bar
    local top = New("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 8, Parent = Main})
    local line = New("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = top})
    Reg(function() line.BackgroundColor3 = T.Accent end)
    local wIcon = New("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(26, 26), ImageColor3 = T.Accent, ZIndex = 9, Parent = top})
    Reg(function() wIcon.ImageColor3 = T.Accent end)
    local hasIcon = ApplyIcon(wIcon, cfg.Icon)
    if not hasIcon then wIcon.Visible = false end
    local tx = hasIcon and 46 or 14

    local titleRow = New("Frame", {Position = UDim2.fromOffset(tx, 4), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 9, Parent = top})
    New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = titleRow})
    local title = New("TextLabel", {LayoutOrder = 0, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Font.GothamBlack, Text = cfg.Name or "VOX HUB", TextSize = 16, TextColor3 = WHITE, ZIndex = 9, Parent = titleRow})
    local tgrad = New("UIGradient", {Parent = title})
    Reg(function() tgrad.Color = ColorSequence.new(WHITE, T.Light) end)
    local desc = New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(tx, 24), Size = UDim2.new(1, -190, 0, 14), Font = Font.Gotham, Text = cfg.Description or "", TextSize = 11, TextColor3 = T.Sub, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9, Parent = top})

    local function topBtn(txt, x, hoverCol)
        local b = New("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -x, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = hoverCol, BackgroundTransparency = 0.9, Text = txt, Font = Font.GothamBold, TextSize = 16, TextColor3 = WHITE, AutoButtonColor = false, ZIndex = 10, Parent = top})
        Corner(b, 8)
        local s = New("UIScale", {Parent = b})
        b.MouseEnter:Connect(function() Tween(b, 0.2, {BackgroundTransparency = 0.45}) Tween(s, 0.25, {Scale = 1.12}, Enum.EasingStyle.Back) end)
        b.MouseLeave:Connect(function() Tween(b, 0.25, {BackgroundTransparency = 0.9}) Tween(s, 0.25, {Scale = 1}) end)
        b.MouseButton1Down:Connect(function() Tween(s, 0.1, {Scale = 0.9}) end)
        return b
    end
    local closeB = topBtn("x", 10, Color3.fromRGB(255, 70, 70))      -- deletes the script (with confirmation)
    local colB = topBtn("^", 42, T.Accent)                           -- collapse to title only
    local hideB = topBtn("-", 74, WHITE)                             -- hide the whole window

    -- Sidebar (opaque) + content
    local side = New("Frame", {Position = UDim2.fromOffset(8, 52), Size = UDim2.new(0, 130, 1, -60), BackgroundColor3 = T.Deep, BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 3, Parent = Body})
    Corner(side, 10)
    local sst = New("UIStroke", {Color = T.Accent, Thickness = 2, Transparency = 0.15, Parent = side})
    Reg(function() side.BackgroundColor3 = T.Deep sst.Color = T.Accent end)
    local selector = New("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = side})
    Corner(selector, 8)
    local selBar = New("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = selector})
    Corner(selBar, 2)
    Reg(function() selector.BackgroundColor3 = T.Accent selBar.BackgroundColor3 = T.Accent end)
    local sideScroll = New("ScrollingFrame", {Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 2, Parent = side})
    New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sideScroll})
    New("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = sideScroll})
    local content = New("Frame", {Position = UDim2.fromOffset(146, 52), Size = UDim2.new(1, -154, 1, -60), BackgroundTransparency = 1, ZIndex = 3, Parent = Body})

    -- Player card (bottom-left)
    local profile = New("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(1, -12, 0, 42), BackgroundColor3 = T.Elem, BorderSizePixel = 0, ZIndex = 4, Parent = side})
    Corner(profile, 10)
    local pfs = New("UIStroke", {Color = T.Accent, Thickness = 1, Transparency = 0.4, Parent = profile})
    Reg(function() profile.BackgroundColor3 = T.Elem pfs.Color = T.Accent end)
    local avatar = New("ImageLabel", {Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = T.Dark, Image = "", ImageTransparency = 1, ZIndex = 5, Parent = profile})
    Corner(avatar, 999)
    local avs = New("UIStroke", {Color = T.Accent, Thickness = 2, Parent = avatar})
    Reg(function() avs.Color = T.Accent end)
    local dot = New("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 1, 1, 1), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(60, 230, 110), BorderSizePixel = 0, ZIndex = 6, Parent = avatar})
    Corner(dot, 999)
    Stroke(dot, T.Deep, 2, 0)
    TS:Create(dot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.6}):Play()
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 5), Size = UDim2.new(1, -50, 0, 16), Font = Font.GothamBold, Text = LP.DisplayName, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = profile})
    New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 21), Size = UDim2.new(1, -50, 0, 14), Font = Font.Gotham, Text = "@" .. LP.Name, TextSize = 10, TextColor3 = T.Sub, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = profile})
    task.spawn(function()
        pcall(function()
            avatar.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            Tween(avatar, 0.6, {ImageTransparency = 0})
        end)
    end)
    local function profileIn(delay)
        profile.Position = UDim2.new(0, 6, 1, 60)
        task.delay(delay or 0.3, function() Tween(profile, 0.7, {Position = UDim2.new(0, 6, 1, -6)}, Enum.EasingStyle.Back) end)
    end

    -- Ripple everywhere in the window
    WConn(UIS.InputBegan, function(input)
        if not Window.Visible then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            local p, ap, as = input.Position, Main.AbsolutePosition, Main.AbsoluteSize
            if p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y then
                Ripple(RippleLayer, Vector2.new(p.X, p.Y), T.Accent, 260)
            end
        end
    end)

    -- Drag (top bar) with 5D parallax
    local drag = Draggable(top, Holder, {Speed = 8, OnStep = function(d)
        for i, l in ipairs(layers) do
            l.f.Position = UDim2.new(0.5, -d.X * 0.12 * i, 0.5, 7 * i - d.Y * 0.12 * i)
        end
    end, OnBegin = function()
        Tween(MainScale, 0.25, {Scale = 0.985})
        Tween(bst, 0.25, {Thickness = 3})
    end, OnEnd = function()
        Tween(MainScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
        Tween(bst, 0.4, {Thickness = 2})
    end})

    -- Show / hide animations
    local function playShow()
        Holder.Visible = true
        Holder.Rotation = -7
        MainScale.Scale = 0.6
        Main.GroupTransparency = 1
        bst.Thickness = 6
        Tween(MainScale, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
        Tween(Main, 0.35, {GroupTransparency = 0})
        Tween(Holder, 0.7, {Rotation = 0}, Enum.EasingStyle.Back)
        Tween(bst, 0.6, {Transparency = 0.1, Thickness = 2})
        for i, l in ipairs(layers) do
            l.f.Position = UDim2.new(0.5, 0, 0.5, 0)
            l.f.BackgroundTransparency = 1
            Tween(l.f, 0.5 + 0.12 * i, {Position = UDim2.new(0.5, 0, 0.5, 7 * i), BackgroundTransparency = l.t}, Enum.EasingStyle.Back)
        end
        profileIn(0.3)
    end
    local function playHide()
        Tween(MainScale, 0.4, {Scale = 0.5}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        Tween(Main, 0.3, {GroupTransparency = 1})
        Tween(Holder, 0.4, {Rotation = 8}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        Tween(bst, 0.3, {Transparency = 1})
        for _, l in ipairs(layers) do
            Tween(l.f, 0.3, {Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1})
        end
        Tween(profile, 0.3, {Position = UDim2.new(0, 6, 1, 60)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.delay(0.45, function() if not Window.Visible then Holder.Visible = false end end)
    end
    function Window:SetVisible(v)
        if v == Window.Visible then return end
        Window.Visible = v
        if v then playShow() else playHide() end
    end
    playShow()

    -- Collapse: only the title stays (centered); expanding lifts the title back up
    local fullH
    function Window:SetCollapsed(v)
        if v == Window.Collapsed then return end
        Window.Collapsed = v
        local curH = Holder.AbsoluteSize.Y
        if v then fullH = curH end
        local targetH = v and 52 or (fullH or curH)
        local p = Holder.Position
        Tween(Holder, 0.55, {
            Size = UDim2.new(size.X.Scale, size.X.Offset, 0, targetH),
            Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + (targetH - curH) / 2),
        }, Enum.EasingStyle.Quint)
        Tween(Body, 0.3, {GroupTransparency = v and 1 or 0})
        Tween(line, 0.3, {BackgroundTransparency = v and 1 or 0.7})
        Tween(desc, 0.3, {TextTransparency = v and 1 or 0})
        Tween(wIcon, 0.3, {ImageTransparency = v and 1 or 0})
        Tween(colB, 0.45, {Rotation = v and 180 or 0}, Enum.EasingStyle.Back)
        if v then
            Tween(titleRow, 0.55, {Position = UDim2.new(0.5, -titleRow.AbsoluteSize.X / 2, 0, 12)}, Enum.EasingStyle.Back)
            task.delay(0.3, function() if Window.Collapsed then Body.Visible = false end end)
        else
            Body.Visible = true
            Tween(titleRow, 0.55, {Position = UDim2.fromOffset(tx, 4)}, Enum.EasingStyle.Back)
        end
    end

    function Window:Destroy()
        Window:SetVisible(false)
        task.delay(0.5, function()
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            drag.Destroy()
            for f in pairs(Window.Floats) do pcall(function() Window.Floats[f]:Destroy() end) end
            Holder:Destroy()
            if Window.OpenButton then Window.OpenButton:Destroy() end
        end)
    end
    hideB.MouseButton1Click:Connect(function() Window:SetVisible(false) end)
    colB.MouseButton1Click:Connect(function() Window:SetCollapsed(not Window.Collapsed) end)
    closeB.MouseButton1Click:Connect(function()
        Library:Confirm({
            Title = "DELETE SCRIPT?",
            Message = "This will permanently remove " .. (cfg.Name or "VOX HUB") .. ", every floating button and all notifications from your screen.",
            ConfirmText = "HOLD TO DELETE",
            HoldTime = 1.8,
            Color = "Red",
            OnConfirm = function()
                Window:SetVisible(false)
                task.delay(0.6, function() Library:Unload() end)
            end,
        })
    end)
    if cfg.ToggleKey then
        WConn(UIS.InputBegan, function(i, gp)
            if not gp and i.KeyCode == cfg.ToggleKey then Window:SetVisible(not Window.Visible) end
        end)
    end

    -- Setters
    function Window:SetColor(c) SetT(c) Library.Accent = T.Accent for _, fn in ipairs(reg) do pcall(fn) end end
    function Window:SetTransparency(n) Tween(Main, 0.3, {BackgroundTransparency = math.clamp(n, 0, 1)}) end
    function Window:SetTitle(s) title.Text = s end
    function Window:SetDescription(s) desc.Text = s end
    function Window:SetIcon(n) wIcon.Visible = ApplyIcon(wIcon, n) end
    function Window:SetSize(s) size = s Tween(Holder, 0.5, {Size = s}, Enum.EasingStyle.Back) end
    function Window:Notify(c) Library:Notify(c) end

    -- ------------------------------------------------------ Tags (next to the title)
    function Window:Tag(c)
        c = c or {}
        local pill = New("Frame", {LayoutOrder = #tags + 1, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 9, Parent = titleRow})
        Corner(pill, 8)
        local st = New("UIStroke", {Thickness = 1, Transparency = 0.3, Parent = pill})
        New("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = pill})
        local lbl = New("TextLabel", {Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Font.GothamBold, Text = c.Name or "TAG", TextSize = 10, ZIndex = 10, Parent = pill})
        local obj = {}
        local function paint()
            local col = c.Color and Library.ResolveColor(c.Color) or T.Accent
            pill.BackgroundColor3 = col
            st.Color = col
            lbl.TextColor3 = col:Lerp(WHITE, 0.4)
        end
        Reg(paint)
        local sc = New("UIScale", {Scale = 0, Parent = pill})
        Tween(sc, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
        TS:Create(st, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.8}):Play()
        function obj:SetText(s) lbl.Text = s end
        function obj:SetColor(n) c.Color = n paint() end
        function obj:Destroy() Tween(sc, 0.25, {Scale = 0}, Enum.EasingStyle.Back, Enum.EasingDirection.In) Debris:AddItem(pill, 0.3) end
        table.insert(tags, obj)
        return obj
    end
    for _, t in ipairs(cfg.Tags or {}) do Window:Tag(t) end

    -- ------------------------------------------------------ Open button
    do
        local ob = cfg.OpenButton or {}
        if ob.Enabled ~= false then
            local OB = New("TextButton", {Name = "VOX_Open", AnchorPoint = Vector2.new(0.5, 0.5), Position = ob.Position or UDim2.new(0, 46, 0.5, 0), Size = ob.Size or UDim2.fromOffset(54, 54), BackgroundColor3 = ob.Color and Library.ResolveColor(ob.Color) or T.Dark, BackgroundTransparency = 0.12, Text = "", AutoButtonColor = false, Parent = Gui})
            Corner(OB, 16)
            local ost = Stroke(OB, T.Accent, 2, 0.1)
            Reg(function() ost.Color = T.Accent end)
            local oscale = New("UIScale", {Scale = 0, Parent = OB})
            Tween(oscale, 0.6, {Scale = 1}, Enum.EasingStyle.Back)
            local img = New("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.55, 0, 0.55, 0), BackgroundTransparency = 1, ImageColor3 = WHITE, Parent = OB})
            local hasImg = ApplyIcon(img, ob.Image)
            if not hasImg then img:Destroy() end
            New("TextLabel", {BackgroundTransparency = 1, Position = hasImg and UDim2.new(0, 0, 0.62, 0) or UDim2.new(), Size = hasImg and UDim2.new(1, 0, 0.3, 0) or UDim2.fromScale(1, 1), Font = Font.GothamBlack, Text = ob.Name or "VOX", TextSize = hasImg and 10 or 14, TextColor3 = WHITE, TextWrapped = true, Parent = OB})
            TS:Create(ost, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7}):Play()
            OB.MouseEnter:Connect(function() Tween(oscale, 0.25, {Scale = 1.1}, Enum.EasingStyle.Back) end)
            OB.MouseLeave:Connect(function() Tween(oscale, 0.25, {Scale = 1}) end)
            Draggable(OB, OB, {Speed = 10, OnBegin = function() Tween(oscale, 0.15, {Scale = 0.92}) end, OnEnd = function(m)
                Tween(oscale, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
                if m < 8 then Window:SetVisible(not Window.Visible) end
            end})
            Window.OpenButton = OB
        end
    end

    -- ------------------------------------------------------ Config saving
    local CFG_DIR = cfg.ConfigFolder or "VOX_HUB"
    local function fsOk() return (writefile and readfile and isfile and makefolder and isfolder and listfiles) and true or false end
    local function ser(v) if typeof(v) == "Color3" then return {__c = v:ToHex()} end return v end
    local function de(v) if type(v) == "table" and v.__c then return Color3.fromHex(v.__c) end return v end
    local function ensure() if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end end
    local function noFs() Library:Notify({Title = "Config", Message = "Your executor does not support file functions", Color = "Red", Time = 4}) end

    function Window:ListConfigs()
        local out = {}
        if not fsOk() then return out end
        pcall(function()
            ensure()
            for _, p in ipairs(listfiles(CFG_DIR)) do
                local n = p:match("([^/\\]+)%.json$")
                if n then table.insert(out, n) end
            end
        end)
        table.sort(out)
        return out
    end
    function Window:SaveConfig(name)
        name = (name and name ~= "") and name or "default"
        if not fsOk() then noFs() return false end
        local ok = pcall(function()
            ensure()
            local data = {}
            for k, o in pairs(Window.Flags) do
                local good, v = pcall(function() return o:Get() end)
                if good then data[k] = ser(v) end
            end
            writefile(CFG_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(data))
        end)
        Library:Notify({Title = "Config", Message = ok and ('Saved "' .. name .. '"') or "Failed to save config", Color = ok and nil or "Red", Time = 3, Icon = "save"})
        return ok
    end
    function Window:LoadConfig(name)
        name = (name and name ~= "") and name or "default"
        if not fsOk() then noFs() return false end
        local path = CFG_DIR .. "/" .. name .. ".json"
        if not isfile(path) then
            Library:Notify({Title = "Config", Message = 'Config "' .. name .. '" was not found', Color = "Red", Time = 3})
            return false
        end
        local ok = pcall(function()
            local data = HttpService:JSONDecode(readfile(path))
            for k, v in pairs(data) do
                local o = Window.Flags[k]
                if o then pcall(function() o:Set(de(v)) end) end
            end
        end)
        Library:Notify({Title = "Config", Message = ok and ('Loaded "' .. name .. '"') or "Failed to load config", Color = ok and nil or "Red", Time = 3})
        return ok
    end
    function Window:DeleteConfig(name)
        if not fsOk() or not delfile then noFs() return false end
        local path = CFG_DIR .. "/" .. tostring(name) .. ".json"
        local ok = pcall(function() if isfile(path) then delfile(path) end end)
        Library:Notify({Title = "Config", Message = ok and ('Deleted "' .. tostring(name) .. '"') or "Failed to delete", Color = ok and nil or "Red", Time = 3})
        return ok
    end
    function Window:SetAutoLoad(name)
        if not fsOk() then noFs() return end
        pcall(function()
            ensure()
            local p = CFG_DIR .. "/_autoload.txt"
            if name and name ~= "" then writefile(p, name)
            elseif isfile(p) and delfile then delfile(p) end
        end)
    end
    function Window:GetAutoLoad()
        if not fsOk() then return nil end
        local out
        pcall(function() local p = CFG_DIR .. "/_autoload.txt" if isfile(p) then out = readfile(p) end end)
        return (out and out ~= "") and out or nil
    end
    function Window:LoadAutoConfig()
        local n = Window:GetAutoLoad()
        if n then Window:LoadConfig(n) end
    end

    -- ------------------------------------------------------ Popups
    local function OpenPopup(w, h)
        local backdrop = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 60, Parent = Main})
        Tween(backdrop, 0.3, {BackgroundTransparency = 0.5})
        local panel = New("CanvasGroup", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundColor3 = T.Dark, BackgroundTransparency = 0.04, GroupTransparency = 1, Active = true, ZIndex = 61, Parent = backdrop})
        Corner(panel, 12)
        Stroke(panel, T.Accent, 1.5, 0.3)
        local ps = New("UIScale", {Scale = 0.8, Parent = panel})
        Tween(ps, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
        Tween(panel, 0.3, {GroupTransparency = 0})
        local closed = false
        local function close()
            if closed then return end
            closed = true
            Tween(ps, 0.3, {Scale = 0.85}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            Tween(panel, 0.25, {GroupTransparency = 1})
            Tween(backdrop, 0.3, {BackgroundTransparency = 1})
            Debris:AddItem(backdrop, 0.35)
        end
        backdrop.MouseButton1Click:Connect(close)
        return panel, close
    end

    local function PLabel(parent, text, x, y, w, h, align, size, col, font)
        return New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Font = font or Font.GothamMedium, Text = text, TextSize = size or 12, TextColor3 = col or T.Text, TextXAlignment = align or Left, Parent = parent})
    end

    local function MakeSlider(holder, min, max, def, inc, cb, label, lockScroll)
        min, max, inc = min or 0, max or 100, inc or 1
        local value = math.clamp(def or min, min, max)
        local track = New("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, Parent = holder})
        Corner(track, 3)
        local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = track})
        Corner(fill, 3)
        local fg = New("UIGradient", {Parent = fill})
        local knob = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, ZIndex = 3, Parent = track})
        Corner(knob, 999)
        local kst = Stroke(knob, T.Accent, 2, 0)
        Reg(function() fill.BackgroundColor3 = T.Accent kst.Color = T.Accent fg.Color = ColorSequence.new(T.Light, T.Accent) end)
        local hit = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = holder})
        local obj = {}
        local function render()
            local a = (max - min) == 0 and 0 or (value - min) / (max - min)
            Tween(fill, 0.1, {Size = UDim2.fromScale(a, 1)})
            Tween(knob, 0.1, {Position = UDim2.fromScale(a, 0.5)})
            if label then label.Text = tostring(value) end
        end
        local function fromAlpha(a)
            local v = min + (max - min) * a
            v = math.floor(v / inc + 0.5) * inc
            v = math.floor(math.clamp(v, min, max) * 1000 + 0.5) / 1000
            if v ~= value then value = v render() if cb then pcall(cb, value) end end
        end
        TrackDrag(hit, function(pos) local a = Rel(track, pos) fromAlpha(a) end,
            function() Tween(knob, 0.2, {Size = UDim2.fromOffset(20, 20)}, Enum.EasingStyle.Back) if lockScroll then lockScroll.ScrollingEnabled = false end end,
            function() Tween(knob, 0.3, {Size = UDim2.fromOffset(14, 14)}, Enum.EasingStyle.Back) if lockScroll then lockScroll.ScrollingEnabled = true end end)
        function obj:Set(v, silent)
            value = math.clamp(tonumber(v) or min, min, max)
            render()
            if not silent and cb then pcall(cb, value) end
        end
        function obj:Get() return value end
        render()
        return obj
    end

    local function OpenPicker(default, cb)
        local panel, close = OpenPopup(280, 250)
        local h, s, v = default:ToHSV()
        local orig = default
        local sv = New("Frame", {Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 120), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Parent = panel})
        Corner(sv, 8)
        local wf = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = sv})
        Corner(wf, 8)
        New("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = wf})
        local bf = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = sv})
        Corner(bf, 8)
        New("UIGradient", {Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = bf})
        local cur = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, ZIndex = 4, Parent = sv})
        Corner(cur, 999)
        Stroke(cur, WHITE, 2, 0)
        local svHit = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = sv})

        local hue = New("Frame", {Position = UDim2.fromOffset(12, 140), Size = UDim2.new(1, -24, 0, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = panel})
        Corner(hue, 7)
        New("UIGradient", {Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1))}), Parent = hue})
        local hk = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(8, 20), BackgroundColor3 = WHITE, ZIndex = 4, Parent = hue})
        Corner(hk, 4)
        Stroke(hk, BLACK, 1, 0.4)
        local hHit = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = hue})

        local prev = New("Frame", {Position = UDim2.fromOffset(12, 164), Size = UDim2.fromOffset(30, 28), BorderSizePixel = 0, BackgroundColor3 = default, Parent = panel})
        Corner(prev, 6)
        Stroke(prev, WHITE, 1, 0.7)
        local function mkBox(x, w, ph)
            local b = New("TextBox", {Position = UDim2.fromOffset(x, 164), Size = UDim2.fromOffset(w, 28), BackgroundColor3 = T.Elem, BackgroundTransparency = 0.15, PlaceholderText = ph, Text = "", TextColor3 = T.Text, PlaceholderColor3 = T.Sub, Font = Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, Parent = panel})
            Corner(b, 6)
            local st = Stroke(b, T.Accent, 1, 0.4)
            b.Focused:Connect(function() Tween(st, 0.2, {Transparency = 0}) end)
            b.FocusLost:Connect(function() Tween(st, 0.2, {Transparency = 0.4}) end)
            return b
        end
        local hex, rB, gB, bB = mkBox(48, 80, "#HEX"), mkBox(134, 36, "R"), mkBox(174, 36, "G"), mkBox(214, 36, "B")

        local function update(fire)
            local col = Color3.fromHSV(h, s, v)
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            Tween(cur, 0.08, {Position = UDim2.fromScale(s, 1 - v)})
            Tween(hk, 0.08, {Position = UDim2.fromScale(h, 0.5)})
            prev.BackgroundColor3 = col
            hex.Text = "#" .. col:ToHex():upper()
            rB.Text, gB.Text, bB.Text = tostring(math.floor(col.R * 255 + 0.5)), tostring(math.floor(col.G * 255 + 0.5)), tostring(math.floor(col.B * 255 + 0.5))
            if fire and cb then pcall(cb, col) end
        end
        TrackDrag(svHit, function(pos) local x, y = Rel(sv, pos) s, v = x, 1 - y update(true) end)
        TrackDrag(hHit, function(pos) local x = Rel(hue, pos) h = math.min(x, 0.999) update(true) end)
        hex.FocusLost:Connect(function()
            local ok, c3 = pcall(Color3.fromHex, hex.Text)
            if ok and c3 then h, s, v = c3:ToHSV() end
            update(true)
        end)
        local function rgbChanged()
            local r, g, b = tonumber(rB.Text), tonumber(gB.Text), tonumber(bB.Text)
            if r and g and b then h, s, v = Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255)):ToHSV() end
            update(true)
        end
        rB.FocusLost:Connect(rgbChanged) gB.FocusLost:Connect(rgbChanged) bB.FocusLost:Connect(rgbChanged)

        local function pbtn(text, x, w, filled, fn)
            local b = New("TextButton", {Position = UDim2.fromOffset(x, 204), Size = UDim2.fromOffset(w, 32), BackgroundColor3 = T.Accent, BackgroundTransparency = filled and 0.1 or 0.75, Text = text, Font = Font.GothamBold, TextSize = 13, TextColor3 = filled and BLACK or T.Text, AutoButtonColor = false, Parent = panel})
            Corner(b, 8)
            Stroke(b, T.Accent, 1.2, 0.3)
            local bs = New("UIScale", {Parent = b})
            b.MouseEnter:Connect(function() Tween(bs, 0.2, {Scale = 1.05}, Enum.EasingStyle.Back) end)
            b.MouseLeave:Connect(function() Tween(bs, 0.2, {Scale = 1}) end)
            b.MouseButton1Click:Connect(fn)
        end
        pbtn("Cancel", 12, 120, false, function() if cb then pcall(cb, orig) end close() end)
        pbtn("Done", 148, 120, true, close)
        update(false)
    end

    local function OpenFloatPanel(info)
        local panel, close = OpenPopup(290, 262)
        local opts = {Name = info.Name, Size = 56, Transparency = 0.1, Color = T.Accent}
        PLabel(panel, info.Toggle and "Floating Toggle" or "Floating Button", 14, 10, 262, 20, Left, 14, T.Text, Font.GothamBlack)
        PLabel(panel, "Name", 14, 40, 60, 28, Left, 12, T.Sub)
        local nb = New("TextBox", {Position = UDim2.fromOffset(74, 40), Size = UDim2.fromOffset(200, 28), BackgroundColor3 = T.Elem, BackgroundTransparency = 0.15, Text = opts.Name, PlaceholderText = "Button name", TextColor3 = T.Text, PlaceholderColor3 = T.Sub, Font = Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, Parent = panel})
        Corner(nb, 6)
        local nst = Stroke(nb, T.Accent, 1, 0.4)
        nb.Focused:Connect(function() Tween(nst, 0.2, {Transparency = 0}) end)
        nb.FocusLost:Connect(function() Tween(nst, 0.2, {Transparency = 0.4}) opts.Name = nb.Text ~= "" and nb.Text or info.Name end)

        PLabel(panel, "Size", 14, 80, 60, 18, Left, 12, T.Sub)
        local sl1 = PLabel(panel, "56", 214, 80, 60, 18, Right, 12, T.Accent)
        local h1 = New("Frame", {Position = UDim2.fromOffset(14, 100), Size = UDim2.fromOffset(262, 18), BackgroundTransparency = 1, Parent = panel})
        MakeSlider(h1, 30, 120, 56, 1, function(v) opts.Size = v end, sl1)

        PLabel(panel, "Transparency", 14, 124, 120, 18, Left, 12, T.Sub)
        local sl2 = PLabel(panel, "0.1", 214, 124, 60, 18, Right, 12, T.Accent)
        local h2 = New("Frame", {Position = UDim2.fromOffset(14, 144), Size = UDim2.fromOffset(262, 18), BackgroundTransparency = 1, Parent = panel})
        MakeSlider(h2, 0, 0.9, 0.1, 0.05, function(v) opts.Transparency = v end, sl2)

        PLabel(panel, "Border Color", 14, 172, 120, 24, Left, 12, T.Sub)
        local sw = New("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(276, 172), Size = UDim2.fromOffset(60, 24), BackgroundColor3 = opts.Color, Text = "", AutoButtonColor = false, Parent = panel})
        Corner(sw, 6)
        Stroke(sw, WHITE, 1, 0.6)
        sw.MouseButton1Click:Connect(function() OpenPicker(opts.Color, function(c) opts.Color = c sw.BackgroundColor3 = c end) end)

        local function pbtn(text, x, w, filled, fn)
            local b = New("TextButton", {Position = UDim2.fromOffset(x, 208), Size = UDim2.fromOffset(w, 40), BackgroundColor3 = T.Accent, BackgroundTransparency = filled and 0.1 or 0.75, Text = text, Font = Font.GothamBold, TextSize = 12, TextColor3 = filled and BLACK or T.Text, TextWrapped = true, AutoButtonColor = false, Parent = panel})
            Corner(b, 8)
            Stroke(b, T.Accent, 1.2, 0.3)
            local bs = New("UIScale", {Parent = b})
            b.MouseEnter:Connect(function() Tween(bs, 0.2, {Scale = 1.05}, Enum.EasingStyle.Back) end)
            b.MouseLeave:Connect(function() Tween(bs, 0.2, {Scale = 1}) end)
            b.MouseButton1Click:Connect(fn)
        end
        pbtn("Exit UI", 14, 124, false, function() close() Window:SetVisible(false) end)                      -- no floating button
        pbtn("Exit + Add Button", 152, 124, true, function() close() Window:SpawnFloat(info, opts) Window:SetVisible(false) end) -- with floating button
    end

    -- Floating button (no X). It is removed from the mini "-" button inside the UI.
    -- For toggles it behaves as a toggle and pulses like a heartbeat while ON.
    function Window:SpawnFloat(info, o)
        if Window.Floats[info] then Window.Floats[info]:Destroy() end
        local base = o.Size
        local norm = UDim2.fromOffset(base, base)
        local b = New("TextButton", {Name = "VOX_Float", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = norm, BackgroundColor3 = T.Dark, BackgroundTransparency = o.Transparency, Text = "", AutoButtonColor = false, Parent = Gui})
        Corner(b, 14)
        local st = Stroke(b, o.Color, 2.5, 0)
        local sc = New("UIScale", {Scale = 0, Parent = b})
        Tween(sc, 0.6, {Scale = 1}, Enum.EasingStyle.Elastic)
        New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromScale(0, info.Toggle and -0.08 or 0), Size = UDim2.fromScale(1, 1), Font = Font.GothamBold, Text = o.Name, TextSize = 12, TextColor3 = WHITE, TextWrapped = true, Parent = b})
        local stateL
        if info.Toggle then
            stateL = New("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Font = Font.GothamBlack, Text = "OFF", TextSize = 10, TextColor3 = Color3.fromRGB(170, 175, 172), Parent = b})
        end

        local alive, on, pulsing = true, false, false
        local function pulse()
            if pulsing then return end
            pulsing = true
            task.spawn(function()
                local big = UDim2.fromOffset(base * 1.16, base * 1.16)
                local mid = UDim2.fromOffset(base * 1.08, base * 1.08)
                local sine = Enum.EasingStyle.Sine
                while alive and on do -- lub-dub heartbeat
                    Tween(b, 0.12, {Size = big}, sine) Tween(st, 0.12, {Thickness = 5}, sine) task.wait(0.13)
                    Tween(b, 0.1, {Size = norm}, sine) Tween(st, 0.1, {Thickness = 2.5}, sine) task.wait(0.11)
                    Tween(b, 0.1, {Size = mid}, sine) Tween(st, 0.1, {Thickness = 4}, sine) task.wait(0.11)
                    Tween(b, 0.2, {Size = norm}, sine) Tween(st, 0.2, {Thickness = 2.5}, sine) task.wait(0.7)
                end
                pulsing = false
                if alive then Tween(b, 0.25, {Size = norm}, Enum.EasingStyle.Back) Tween(st, 0.25, {Thickness = 2.5}) end
            end)
        end
        if info.Listen then
            info.Listen(function(state)
                if not alive then return end
                on = state
                Tween(b, 0.3, {BackgroundColor3 = state and o.Color:Lerp(BLACK, 0.55) or T.Dark})
                if stateL then
                    stateL.Text = state and "ON" or "OFF"
                    Tween(stateL, 0.3, {TextColor3 = state and o.Color:Lerp(WHITE, 0.4) or Color3.fromRGB(170, 175, 172)})
                end
                if state then pulse() end
            end)
        end

        local dragObj
        local obj = {}
        function obj:Destroy()
            alive = false
            Window.Floats[info] = nil
            if dragObj then dragObj.Destroy() end
            Tween(sc, 0.25, {Scale = 0}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            Debris:AddItem(b, 0.3)
        end
        dragObj = Draggable(b, b, {Speed = 10, OnBegin = function() Tween(sc, 0.15, {Scale = 0.9}) end, OnEnd = function(m)
            Tween(sc, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
            if m < 8 then
                pcall(info.Action)
                Ripple(b, b.AbsolutePosition + b.AbsoluteSize / 2, o.Color, o.Size * 1.6)
            end
        end})
        Window.Floats[info] = obj
    end

    -- ------------------------------------------------------ Elements
    local function Elements(Tab, scroll)
        local function Base(topH, name, desc, rightRes)
            rightRes = rightRes or 110
            local f = New("Frame", {Size = UDim2.new(1, -4, 0, topH), BackgroundColor3 = T.Elem, BackgroundTransparency = 0.1, BorderSizePixel = 0, ClipsDescendants = true, Parent = scroll})
            Corner(f, 9)
            local st = New("UIStroke", {Color = T.Accent, Thickness = 1, Transparency = 0.45, Parent = f})
            local sc = New("UIScale", {Name = "EScale", Scale = 0.85, Parent = f})
            Reg(function() f.BackgroundColor3 = T.Elem st.Color = T.Accent end)
            New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, desc and 6 or 0), Size = UDim2.new(1, -rightRes, 0, desc and 20 or topH), Font = Font.GothamBold, Text = name, TextColor3 = T.Text, TextSize = 13, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f})
            if desc then
                New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -rightRes, 0, 16), Font = Font.Gotham, Text = desc, TextColor3 = T.Sub, TextSize = 11, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f})
            end
            f.MouseEnter:Connect(function() Tween(st, 0.25, {Transparency = 0}) Tween(f, 0.25, {BackgroundTransparency = 0}) end)
            f.MouseLeave:Connect(function() Tween(st, 0.3, {Transparency = 0.45}) Tween(f, 0.3, {BackgroundTransparency = 0.1}) end)
            Tween(sc, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
            return f, sc
        end

        local function Press(btn, sc)
            btn.MouseButton1Down:Connect(function() Tween(sc, 0.1, {Scale = 0.97}) end)
            local function up() Tween(sc, 0.4, {Scale = 1}, Enum.EasingStyle.Back) end
            btn.MouseButton1Up:Connect(up)
            btn.MouseLeave:Connect(up)
        end

        -- Small square button: "+" opens the floating-button panel, "-" removes the existing floating button.
        local function Mini(f, rightX, cy, info)
            local m = New("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -rightX, 0, cy), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.75, Text = "+", Font = Font.GothamBold, TextSize = 16, TextColor3 = T.Accent, AutoButtonColor = false, ZIndex = 5, Parent = f})
            Corner(m, 6)
            local ms = New("UIStroke", {Color = T.Accent, Thickness = 1.5, Transparency = 0.1, Parent = m})
            Reg(function() m.TextColor3 = T.Accent m.BackgroundColor3 = T.Accent ms.Color = T.Accent end)
            m.MouseEnter:Connect(function() Tween(m, 0.25, {BackgroundTransparency = 0.5, Rotation = 90}, Enum.EasingStyle.Back) end)
            m.MouseLeave:Connect(function() Tween(m, 0.3, {BackgroundTransparency = 0.75, Rotation = 0}) end)
            WConn(RS.Heartbeat, function()
                local t = Window.Floats[info] and "-" or "+"
                if m.Text ~= t then m.Text = t end
            end)
            m.MouseButton1Click:Connect(function()
                local ex = Window.Floats[info]
                if ex then
                    ex:Destroy()
                    Library:Notify({Title = "Floating Button", Message = "Removed", Time = 2, Color = "Red"})
                else
                    OpenFloatPanel(info)
                end
            end)
        end

        local function FocusFx(box, st)
            box.Focused:Connect(function() Tween(st, 0.2, {Transparency = 0, Thickness = 2}) end)
            box.FocusLost:Connect(function() Tween(st, 0.25, {Transparency = 0.4, Thickness = 1}) end)
        end

        local function Flag(c, obj) if c.Flag then Window.Flags[c.Flag] = obj end end

        function Tab:Section(name)
            local l = New("TextLabel", {Size = UDim2.new(1, -4, 0, 22), BackgroundTransparency = 1, Font = Font.GothamBlack, Text = string.upper(name or "SECTION"), TextSize = 11, TextColor3 = T.Accent, TextXAlignment = Left, Parent = scroll})
            Reg(function() l.TextColor3 = T.Accent end)
            New("UIPadding", {PaddingLeft = UDim.new(0, 4), Parent = l})
            New("UIScale", {Name = "EScale", Parent = l})
        end

        -- Label system: Tab:Label("text") or Tab:Label({Text=, Color=, Size=, Bold=, Align="Center"})
        function Tab:Label(c)
            if type(c) ~= "table" then c = {Text = tostring(c or "Label")} end
            local l = New("TextLabel", {Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = c.Bold and Font.GothamBold or Font.Gotham, Text = c.Text or "Label", TextSize = c.Size or 12, TextXAlignment = c.Align == "Center" and Center or Left, TextWrapped = true, TextTransparency = 1, Parent = scroll})
            New("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = l})
            New("UIScale", {Name = "EScale", Parent = l})
            local function paint() l.TextColor3 = c.Color and Library.ResolveColor(c.Color) or T.Sub end
            Reg(paint)
            Tween(l, 0.6, {TextTransparency = 0})
            local obj = {}
            function obj:SetText(s) l.Text = s end
            function obj:SetColor(n) c.Color = n Tween(l, 0.3, {TextColor3 = Library.ResolveColor(n)}) end
            return obj
        end

        -- Note system: Tab:Note({Title=, Text=, Color="Yellow"})
        function Tab:Note(c)
            c = c or {}
            local col = Library.ResolveColor(c.Color or "Yellow")
            local f = New("Frame", {Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = col, BackgroundTransparency = 0.78, BorderSizePixel = 0, ClipsDescendants = true, Parent = scroll})
            Corner(f, 9)
            local st = Stroke(f, col, 1, 0.35)
            New("UIScale", {Name = "EScale", Parent = f})
            local bar = New("Frame", {Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0, Parent = f})
            local inner = New("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = f})
            New("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner})
            New("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 9), Parent = inner})
            local tl = New("TextLabel", {LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Font.GothamBlack, Text = string.upper(c.Title or "NOTE"), TextSize = 11, TextColor3 = col, TextXAlignment = Left, Parent = inner})
            local bl = New("TextLabel", {LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Font.Gotham, Text = c.Text or "", TextSize = 12, TextColor3 = Color3.fromRGB(235, 240, 237), TextXAlignment = Left, TextWrapped = true, Parent = inner})
            TS:Create(st, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.8}):Play()
            TS:Create(bar, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.4}):Play()
            local obj = {}
            function obj:SetText(s) bl.Text = s end
            function obj:SetTitle(s) tl.Text = string.upper(s) end
            function obj:SetColor(n)
                local cc = Library.ResolveColor(n)
                Tween(f, 0.3, {BackgroundColor3 = cc}) Tween(bar, 0.3, {BackgroundColor3 = cc}) Tween(tl, 0.3, {TextColor3 = cc}) st.Color = cc
            end
            return obj
        end

        -- Button (MiniButton = false removes the small square button)
        function Tab:Button(c)
            c = c or {}
            local topH = c.Desc and 50 or 40
            local mini = c.MiniButton ~= false
            local f, sc = Base(topH, c.Name or "Button", c.Desc, mini and 80 or 50)
            local btn = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = f})
            local arrow = New("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, topH / 2), Size = UDim2.fromOffset(16, 20), BackgroundTransparency = 1, Font = Font.GothamBlack, Text = ">", TextSize = 16, TextColor3 = T.Accent, Parent = f})
            Reg(function() arrow.TextColor3 = T.Accent end)
            Press(btn, sc)
            local function run()
                if c.Callback then task.spawn(pcall, c.Callback) end
                Tween(arrow, 0.15, {Position = UDim2.new(1, -4, 0, topH / 2)})
                task.delay(0.15, function() Tween(arrow, 0.4, {Position = UDim2.new(1, -12, 0, topH / 2)}, Enum.EasingStyle.Back) end)
            end
            btn.MouseButton1Click:Connect(run)
            if mini then Mini(f, 40, topH / 2, {Name = c.Name or "Button", Action = run}) end
            return {Fire = run}
        end

        -- Toggle (+ optional merged Slider, + optional mini button)
        function Tab:Toggle(c)
            c = c or {}
            local topH = c.Desc and 50 or 40
            local S = c.Slider
            local mini = c.MiniButton ~= false
            local f, sc = Base(S and (topH + 30) or topH, c.Name or "Toggle", c.Desc, mini and 130 or 100)
            local state = c.Default == true
            local listeners = {}
            local btn = New("TextButton", {Size = UDim2.new(1, 0, 0, topH), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = f})
            local pill = New("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, topH / 2), Size = UDim2.fromOffset(42, 22), BackgroundColor3 = Color3.fromRGB(55, 62, 58), BorderSizePixel = 0, Parent = f})
            Corner(pill, 11)
            local knob = New("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = pill})
            Corner(knob, 8)
            local obj = {}
            local function render(anim)
                local t = anim and 0.35 or 0
                Tween(pill, t, {BackgroundColor3 = state and T.Accent or Color3.fromRGB(55, 62, 58)})
                Tween(knob, t, {Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16)}, Enum.EasingStyle.Back)
                for _, fn in ipairs(listeners) do pcall(fn, state) end
            end
            Reg(function() render(false) end)
            function obj:Set(v, silent)
                state = v and true or false
                render(true)
                if not silent and c.Callback then task.spawn(pcall, c.Callback, state) end
            end
            function obj:Get() return state end
            Press(btn, sc)
            btn.MouseButton1Click:Connect(function()
                Tween(knob, 0.12, {Size = UDim2.fromOffset(22, 16)})
                obj:Set(not state)
            end)
            if mini then
                Mini(f, 62, topH / 2, {Name = c.Name or "Toggle", Toggle = true, Action = function() obj:Set(not state) end, Listen = function(fn) table.insert(listeners, fn) fn(state) end})
            end
            if S then
                local vl = New("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, topH + 13), Size = UDim2.fromOffset(50, 18), BackgroundTransparency = 1, Font = Font.GothamBold, Text = "", TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Right, Parent = f})
                Reg(function() vl.TextColor3 = T.Accent end)
                local holder = New("Frame", {Position = UDim2.fromOffset(12, topH + 4), Size = UDim2.new(1, -78, 0, 18), BackgroundTransparency = 1, Parent = f})
                obj.Slider = MakeSlider(holder, S.Min, S.Max, S.Default, S.Increment, S.Callback, vl, scroll)
                if S.Flag then Window.Flags[S.Flag] = obj.Slider end
            end
            render(false)
            Flag(c, obj)
            return obj
        end

        -- Slider (min / max)
        function Tab:Slider(c)
            c = c or {}
            local topH = c.Desc and 50 or 34
            local f = Base(topH + 24, c.Name or "Slider", c.Desc, 90)
            local vl = New("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(70, 18), BackgroundTransparency = 1, Font = Font.GothamBold, Text = "", TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Right, Parent = f})
            Reg(function() vl.TextColor3 = T.Accent end)
            local holder = New("Frame", {Position = UDim2.fromOffset(12, topH + 2), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Parent = f})
            local obj = MakeSlider(holder, c.Min, c.Max, c.Default, c.Increment, c.Callback, vl, scroll)
            Flag(c, obj)
            return obj
        end

        -- Textbox: Name = outside label, Placeholder = text inside the box
        function Tab:Textbox(c)
            c = c or {}
            local topH = c.Desc and 50 or 40
            local f = Base(topH, c.Name or "Textbox", c.Desc, 190)
            local box = New("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0, topH / 2), Size = UDim2.fromOffset(160, 26), BackgroundColor3 = T.Dark, BackgroundTransparency = 0.1, Text = c.Default or "", PlaceholderText = c.Placeholder or "Type here...", PlaceholderColor3 = T.Sub, TextColor3 = T.Text, Font = Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, ClipsDescendants = true, Parent = f})
            Corner(box, 6)
            local st = New("UIStroke", {Color = T.Accent, Thickness = 1, Transparency = 0.4, Parent = box})
            Reg(function() st.Color = T.Accent end)
            FocusFx(box, st)
            box.FocusLost:Connect(function(enter)
                if c.Numeric then box.Text = box.Text:gsub("[^%d%.%-]", "") end
                if c.Callback then task.spawn(pcall, c.Callback, box.Text, enter) end
            end)
            local obj = {}
            function obj:Set(s, silent)
                box.Text = tostring(s or "")
                if not silent and c.Callback then task.spawn(pcall, c.Callback, box.Text, false) end
            end
            function obj:Get() return box.Text end
            Flag(c, obj)
            return obj
        end

        -- Color picker
        function Tab:ColorPicker(c)
            c = c or {}
            local topH = c.Desc and 50 or 40
            local f, sc = Base(topH, c.Name or "Color", c.Desc)
            local col = c.Default or Color3.fromRGB(0, 255, 100)
            local btn = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = f})
            local sw = New("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, topH / 2), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = col, BorderSizePixel = 0, Parent = f})
            Corner(sw, 6)
            Stroke(sw, WHITE, 1, 0.6)
            Press(btn, sc)
            local obj = {}
            function obj:Set(c3, silent)
                if type(c3) == "string" then local ok, r = pcall(Color3.fromHex, c3) c3 = ok and r or col end
                col = c3
                Tween(sw, 0.2, {BackgroundColor3 = c3})
                if not silent and c.Callback then task.spawn(pcall, c.Callback, c3) end
            end
            function obj:Get() return col end
            btn.MouseButton1Click:Connect(function()
                OpenPicker(col, function(c3)
                    col = c3 sw.BackgroundColor3 = c3
                    if c.Callback then task.spawn(pcall, c.Callback, c3) end
                end)
            end)
            Flag(c, obj)
            return obj
        end

        -- Dropdown (unlimited options, search box appears when the list is long)
        function Tab:Dropdown(c)
            c = c or {}
            local topH = c.Desc and 50 or 40
            local f, sc = Base(topH, c.Name or "Dropdown", c.Desc, 190)
            local options = c.Options or {}
            local multi = c.Multi
            local sel, cur, open, items = {}, nil, false, {}
            local head = New("TextButton", {Size = UDim2.new(1, 0, 0, topH), BackgroundTransparency = 1, Text = "", ZIndex = 2, Parent = f})
            local valL = New("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0, topH / 2), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1, Font = Font.Gotham, Text = "-", TextSize = 12, TextColor3 = T.Accent, TextXAlignment = Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f})
            Reg(function() valL.TextColor3 = T.Accent end)
            local arrow = New("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0, topH / 2), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Font = Font.GothamBold, Text = "v", TextSize = 12, TextColor3 = T.Sub, Parent = f})
            Press(head, sc)

            local box
            local function searchOn() return c.Search or #options > 6 end
            local list = New("ScrollingFrame", {Position = UDim2.new(0, 8, 0, topH + 6), Size = UDim2.new(1, -16, 0, 130), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = f})
            New("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list})
            local function layout()
                local y = topH + 6
                box.Visible = searchOn()
                box.Position = UDim2.new(0, 8, 0, y)
                if searchOn() then y = y + 32 end
                local n = 0
                for _ in pairs(items) do n = n + 1 end
                local lh = math.clamp(n * 29, 29, 130)
                list.Position = UDim2.new(0, 8, 0, y)
                list.Size = UDim2.new(1, -16, 0, lh)
                return y + lh + 8
            end
            box = New("TextBox", {Size = UDim2.new(1, -16, 0, 26), BackgroundColor3 = T.Dark, BackgroundTransparency = 0.1, PlaceholderText = "Search...", PlaceholderColor3 = T.Sub, Text = "", TextColor3 = T.Text, Font = Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Visible = false, Parent = f})
            Corner(box, 6)
            local bst2 = New("UIStroke", {Color = T.Accent, Thickness = 1, Transparency = 0.4, Parent = box})
            FocusFx(box, bst2)

            local function isSel(o) if multi then return sel[o] == true end return cur == o end
            local function paint()
                for o, b in pairs(items) do
                    local s = isSel(o)
                    Tween(b, 0.2, {BackgroundTransparency = s and 0.55 or 1, TextColor3 = s and T.Accent or T.Text})
                end
            end
            local function updateVal()
                if multi then
                    local t = {}
                    for _, o in ipairs(options) do if sel[o] then table.insert(t, tostring(o)) end end
                    valL.Text = #t == 0 and "-" or (#t <= 2 and table.concat(t, ", ") or (#t .. " selected"))
                else valL.Text = cur ~= nil and tostring(cur) or "-" end
            end
            local function value()
                if multi then local t = {} for _, o in ipairs(options) do if sel[o] then table.insert(t, o) end end return t end
                return cur
            end
            local function setOpen(s)
                open = s
                Tween(arrow, 0.35, {Rotation = s and 180 or 0}, Enum.EasingStyle.Back)
                Tween(f, 0.4, {Size = UDim2.new(1, -4, 0, s and layout() or topH)})
            end
            local function build(filter)
                for _, ch in ipairs(list:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
                items = {}
                local q = (filter or ""):lower()
                for i, o in ipairs(options) do
                    local s = tostring(o)
                    if q == "" or s:lower():find(q, 1, true) then
                        local b = New("TextButton", {Size = UDim2.new(1, -6, 0, 26), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, Text = s, Font = Font.Gotham, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Left, AutoButtonColor = false, LayoutOrder = i, Parent = list})
                        Corner(b, 6)
                        New("UIPadding", {PaddingLeft = UDim.new(0, 10), Parent = b})
                        items[o] = b
                        b.MouseEnter:Connect(function() if not isSel(o) then Tween(b, 0.15, {BackgroundTransparency = 0.8}) end end)
                        b.MouseLeave:Connect(function() if not isSel(o) then Tween(b, 0.2, {BackgroundTransparency = 1}) end end)
                        b.MouseButton1Click:Connect(function()
                            if multi then sel[o] = (not sel[o]) or nil else cur = o end
                            paint() updateVal()
                            if c.Callback then task.spawn(pcall, c.Callback, value()) end
                            if not multi then setOpen(false) end
                        end)
                    end
                end
                paint()
                if open then Tween(f, 0.25, {Size = UDim2.new(1, -4, 0, layout())}) end
            end
            box:GetPropertyChangedSignal("Text"):Connect(function() build(box.Text) end)
            head.MouseButton1Click:Connect(function() setOpen(not open) end)

            if multi and type(c.Default) == "table" then for _, o in ipairs(c.Default) do sel[o] = true end
            elseif not multi then cur = c.Default end
            build() updateVal()

            local obj = {}
            function obj:Get() return value() end
            function obj:Set(v)
                if multi then sel = {} for _, o in ipairs(v or {}) do sel[o] = true end else cur = v end
                paint() updateVal()
                if c.Callback then task.spawn(pcall, c.Callback, value()) end
            end
            function obj:Refresh(newOptions, keep)
                options = newOptions or {}
                if not keep then sel, cur = {}, nil end
                box.Text = ""
                build() updateVal()
            end
            Flag(c, obj)
            return obj
        end

        -- Ready-made config manager (save / load / delete / auto load)
        function Tab:ConfigManager()
            Tab:Section("Configuration")
            local nameBox = Tab:Textbox({Name = "Config Name", Placeholder = "default"})
            local dd
            dd = Tab:Dropdown({Name = "Saved Configs", Desc = "Pick one to load or delete", Options = Window:ListConfigs(), Callback = function(v)
                if v then nameBox:Set(v, true) end
            end})
            local function current()
                local n = nameBox:Get()
                if n == "" then n = dd:Get() or "default" end
                return n
            end
            local function refresh() dd:Refresh(Window:ListConfigs(), false) end
            Tab:Button({Name = "Save Config", Desc = "Writes every flagged option to a file", MiniButton = false, Callback = function() Window:SaveConfig(current()) refresh() end})
            Tab:Button({Name = "Load Config", Desc = "Applies the saved values", MiniButton = false, Callback = function() Window:LoadConfig(current()) end})
            Tab:Button({Name = "Delete Config", MiniButton = false, Callback = function() Window:DeleteConfig(current()) refresh() end})
            Tab:Button({Name = "Refresh List", MiniButton = false, Callback = refresh})
            Tab:Toggle({Name = "Auto Load", Desc = "Load this config on startup", MiniButton = false, Default = Window:GetAutoLoad() ~= nil, Callback = function(on)
                Window:SetAutoLoad(on and current() or nil)
            end})
        end
    end

    -- ------------------------------------------------------ Tabs
    local function moveSelector(tab, instant)
        local y = tab.Btn.AbsolutePosition.Y - side.AbsolutePosition.Y
        local h = tab.Btn.AbsoluteSize.Y
        if instant then
            selector.Position = UDim2.fromOffset(6, y)
            selector.Size = UDim2.new(1, -12, 0, h)
        else
            Tween(selector, 0.5, {Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, h)}, Enum.EasingStyle.Back)
        end
    end
    sideScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if Window.Active then moveSelector(Window.Active, true) end
    end)

    local function Select(tab)
        if Window.Active == tab then return end
        local old = Window.Active
        Window.Active = tab
        local dir = (old and tab.Index < old.Index) and -1 or 1
        if old then
            Tween(old.Page, 0.25, {GroupTransparency = 1, Position = UDim2.fromOffset(0, -18 * dir)})
            Tween(old.Lbl, 0.25, {TextColor3 = T.Sub})
            Tween(old.Ic, 0.25, {ImageColor3 = T.Sub})
            task.delay(0.26, function() if Window.Active ~= old then old.Page.Visible = false end end)
        end
        tab.Page.Position = UDim2.fromOffset(0, 24 * dir)
        tab.Page.GroupTransparency = 1
        tab.Page.Visible = true
        Tween(tab.Page, 0.5, {GroupTransparency = 0, Position = UDim2.new()}, Enum.EasingStyle.Back)
        Tween(selector, 0.3, {BackgroundTransparency = 0.5})
        moveSelector(tab, false)
        Tween(tab.Lbl, 0.25, {TextColor3 = T.Text})
        Tween(tab.Ic, 0.25, {ImageColor3 = T.Accent})
        -- icon bounce
        tab.Ic.Size = UDim2.fromOffset(12, 12)
        tab.Ic.Position = UDim2.new(0, 13, 0.5, -6)
        Tween(tab.Ic, 0.6, {Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 10, 0.5, -9)}, Enum.EasingStyle.Elastic)
        -- staggered element entrance
        for i, ch in ipairs(tab.Scroll:GetChildren()) do
            local s = ch:FindFirstChild("EScale")
            if s then
                s.Scale = 0.88
                task.delay(i * 0.035, function() Tween(s, 0.45, {Scale = 1}, Enum.EasingStyle.Back) end)
            end
        end
    end

    function Window:Tab(c)
        c = c or {}
        local Tab = {Index = #Window.Tabs + 1}
        local btn = New("TextButton", {Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4, Parent = sideScroll})
        Corner(btn, 8)
        local ic = New("ImageLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.5, -9), Size = UDim2.fromOffset(18, 18), ImageColor3 = T.Sub, ZIndex = 5, Parent = btn})
        local has = ApplyIcon(ic, c.Icon)
        if not has then ic.Visible = false end
        local lbl = New("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, has and 36 or 14, 0, 0), Size = UDim2.new(1, -42, 1, 0), Font = Font.GothamMedium, Text = c.Name or "Tab", TextColor3 = T.Sub, TextSize = 13, TextXAlignment = Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = btn})
        btn.MouseEnter:Connect(function() if Window.Active ~= Tab then Tween(lbl, 0.2, {TextColor3 = T.Text, Position = UDim2.new(0, (has and 36 or 14) + 4, 0, 0)}) end end)
        btn.MouseLeave:Connect(function() if Window.Active ~= Tab then Tween(lbl, 0.2, {TextColor3 = T.Sub, Position = UDim2.new(0, has and 36 or 14, 0, 0)}) end end)

        local page = New("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 3, Parent = content})
        local scroll = New("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page})
        New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll})
        New("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4), Parent = scroll})
        Reg(function() scroll.ScrollBarImageColor3 = T.Accent end)

        Tab.Btn, Tab.Ic, Tab.Lbl, Tab.Page, Tab.Scroll = btn, ic, lbl, page, scroll
        Elements(Tab, scroll)
        btn.MouseButton1Click:Connect(function() Select(Tab) end)
        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then task.delay(0.1, function() Select(Tab) end) end
        return Tab
    end

    return Window
end

-- ==========================================================
-- Intro (VOX HUB welcome, 5D + tinted by the window color)
-- ==========================================================
local function PlayIntro(accent)
    accent = accent or Color3.fromRGB(0, 255, 100)
    Clean("VOX_IntroGui")
    local sg = New("ScreenGui", {Name = "VOX_IntroGui", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10000})
    Mount(sg)
    local bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = sg})
    New("UIGradient", {Color = ColorSequence.new(accent:Lerp(BLACK, 0.93), accent:Lerp(BLACK, 0.985)), Rotation = 45, Parent = bg})

    local avatar = New("ImageLabel", {Size = UDim2.fromOffset(80, 80), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -65), BackgroundTransparency = 1, Image = "rbxassetid://0", ImageTransparency = 1, Parent = bg})
    Corner(avatar, 999)
    local astroke = New("UIStroke", {Color = accent, Thickness = 2.5, Transparency = 1, Parent = avatar})
    task.spawn(function()
        pcall(function()
            avatar.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end)
    end)

    local labels = {}
    local function mk(offset, col, z)
        local l = New("TextLabel", {Size = UDim2.fromOffset(600, 90), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, offset, 0.5, -5 + offset), BackgroundTransparency = 1, Font = Font.GothamBlack, Text = "VOX HUB", TextColor3 = col, TextSize = 10, TextTransparency = 1, ZIndex = z, Parent = bg})
        table.insert(labels, l)
        return l
    end
    for i = 4, 1, -1 do mk(i * 2, accent:Lerp(BLACK, 0.2 + 0.15 * i), 1) end -- 5D depth layers
    local vox = mk(0, WHITE, 5)
    New("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, accent:Lerp(WHITE, 0.3)), ColorSequenceKeypoint.new(0.5, accent), ColorSequenceKeypoint.new(1, accent:Lerp(BLACK, 0.6))}), Parent = vox})

    local loadBg = New("Frame", {Size = UDim2.fromOffset(240, 6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 55), BackgroundColor3 = accent:Lerp(BLACK, 0.9), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = bg})
    Corner(loadBg, 999)
    local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = loadBg})
    Corner(fill, 999)
    New("UIGradient", {Color = ColorSequence.new(accent:Lerp(WHITE, 0.2), accent:Lerp(BLACK, 0.3)), Parent = fill})
    local pct = New("TextLabel", {Size = UDim2.fromOffset(100, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 82), BackgroundTransparency = 1, Font = Font.GothamBold, Text = "0%", TextColor3 = accent:Lerp(WHITE, 0.4), TextSize = 12, TextTransparency = 1, Parent = bg})

    local finished = Instance.new("BindableEvent")
    task.spawn(function()
        task.wait(0.2)
        local inInfo = TweenInfo.new(1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        TS:Create(avatar, inInfo, {ImageTransparency = 0}):Play()
        TS:Create(astroke, inInfo, {Transparency = 0}):Play()
        for _, l in ipairs(labels) do
            TS:Create(l, inInfo, {TextSize = 65, TextTransparency = (l == vox) and 0 or 0.35}):Play()
        end
        TS:Create(loadBg, inInfo, {BackgroundTransparency = 0}):Play()
        TS:Create(pct, inInfo, {TextTransparency = 0}):Play()
        TS:Create(fill, TweenInfo.new(4.0, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1)}):Play()

        local t0 = tick()
        while tick() - t0 < 4.0 do
            pct.Text = math.floor(math.clamp((tick() - t0) / 4.0, 0, 1) * 100) .. "%"
            task.wait()
        end
        pct.Text = "100%"
        task.wait(0.3)

        local out = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TS:Create(bg, out, {BackgroundTransparency = 1}):Play()
        TS:Create(avatar, out, {ImageTransparency = 1}):Play()
        TS:Create(astroke, out, {Transparency = 1}):Play()
        for _, l in ipairs(labels) do TS:Create(l, out, {TextTransparency = 1, TextSize = 75}):Play() end
        TS:Create(loadBg, out, {BackgroundTransparency = 1}):Play()
        TS:Create(fill, out, {BackgroundTransparency = 1}):Play()
        local fp = TS:Create(pct, out, {TextTransparency = 1})
        fp:Play()
        fp.Completed:Connect(function() sg:Destroy() finished:Fire() end)
    end)
    finished.Event:Wait()
end


Window:LoadAutoConfig()
