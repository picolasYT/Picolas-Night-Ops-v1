--// 🧠 PICOLAS NIGHT OPS v1 (Mobile) — 99 Noches
--// by PicolasYT
--// Visión nocturna, ESP de loot (cofres, curas, armas), recursos/animales y auto-talar con hacha

if getgenv and getgenv().PicolasNightOpsLoaded then return end
if getgenv then getgenv().PicolasNightOpsLoaded = true end

--== Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

--== Estado
local toggles = {
    vision = true,
    espLoot = true,
    espHeal = true,
    espGuns = true,
    espResources = true,
    espAnimals = true,
    autoChop = true,
}
local scanInterval = 4 -- segundos entre escaneos para evitar lag
local espFolder = workspace:FindFirstChild("PicolasESP") or Instance.new("Folder", workspace)
espFolder.Name = "PicolasESP"

--== Utilidades
local function safeLower(s)
    if typeof(s) == "string" then return string.lower(s) end
    return ""
end

local function hasAny(name, list)
    name = safeLower(name)
    for _, pat in ipairs(list) do
        if string.find(name, string.lower(pat)) then return true end
    end
    return false
end

local function notify(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title="Picolas Night Ops", Text=msg})
    end)
end

local function isAxeEquipped()
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return false, nil end
    local lname = safeLower(tool.Name)
    if string.find(lname, "axe") or string.find(lname, "hacha") then
        return true, tool
    end
    return false, tool
end

--== Efectos visuales (visión nocturna / táctica)
local cc = Lighting:FindFirstChild("PicolasCC") or Instance.new("ColorCorrectionEffect", Lighting)
cc.Name = "PicolasCC"
local bloom = Lighting:FindFirstChild("PicolasBloom") or Instance.new("BloomEffect", Lighting)
bloom.Name = "PicolasBloom"

local function applyNightVision(on)
    if on then
        cc.Enabled = true
        cc.Brightness = 0.08
        cc.Contrast = 0.15
        cc.Saturation = 0.2
        cc.TintColor = Color3.fromRGB(170, 255, 170) -- verde militar
        bloom.Enabled = true
        bloom.Intensity = 0.5
        bloom.Threshold = 1
        bloom.Size = 10
    else
        cc.Enabled = false
        bloom.Enabled = false
    end
end

-- Auto visión nocturna (basado en la intensidad ambiental)
local function isDark()
    -- Heurística simple: brillo ambiente bajo
    local amb = Lighting.Ambient
    local bri = (amb.R + amb.G + amb.B)/3
    return bri < 0.2 or Lighting.ClockTime and (Lighting.ClockTime < 6 or Lighting.ClockTime > 18)
end

--== Etiquetado (ESP)
local function tagBillboard(target, text, color)
    if not target or not target.Parent then return end
    local headCFrame
    if target:IsA("Model") and target.PrimaryPart then
        headCFrame = target.PrimaryPart.CFrame
    elseif target:IsA("BasePart") then
        headCFrame = target.CFrame
    else
        return
    end

    -- Evitar duplicados por target
    local existing = target:FindFirstChild("PicolasESPTag")
    if existing then
        -- Actualizar texto/color
        local lbl = existing:FindFirstChild("LBL")
        if lbl then
            lbl.Text = text
            lbl.TextColor3 = color
        end
        return
    end

    -- Crear BillboardGui atado al objeto
    local b = Instance.new("BillboardGui")
    b.Name = "PicolasESPTag"
    b.Size = UDim2.new(0, 120, 0, 26)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent = target

    local tl = Instance.new("TextLabel", b)
    tl.Name = "LBL"
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.Text = text
    tl.TextColor3 = color
end

-- Limpieza de ESP si los objetos desaparecen (se maneja solo: Billboard se destruye con el objeto)

--== Escaneo del mundo
local LOOT_NAMES = {"Chest","Crate","Loot","Box"}
local HEAL_NAMES = {"Bandage","Medkit","Heal","Cure","Venda"}
local GUN_NAMES  = {"Revolver","Pistol","Gun","Rifle","Shotgun"}
local TREE_NAMES = {"Tree","Arbol"}
local ORE_NAMES  = {"Rock","Ore","Stone","Mineral"}
local ANIMAL_NAMES = {"Animal","Wolf","Bear","Deer","Boar","Fox"}

local function distance(a, b)
    return (a - b).Magnitude
end

local function scanWorld()
    local counts = {loot=0, heal=0, guns=0, res=0, ani=0}
    local all = workspace:GetDescendants()

    for _, inst in ipairs(all) do
        local name = inst.Name
        if not name then continue end

        -- Loot (cofres)
        if toggles.espLoot and hasAny(name, LOOT_NAMES) then
            -- Etiqueta amarilla
            tagBillboard(inst, "🟡 Chest/Loot", Color3.fromRGB(255, 230, 0))
            counts.loot += 1
        end

        -- Curaciones
        if toggles.espHeal and hasAny(name, HEAL_NAMES) then
            tagBillboard(inst, "💚 Heal", Color3.fromRGB(50, 255, 120))
            counts.heal += 1
        end

        -- Armas
        if toggles.espGuns and hasAny(name, GUN_NAMES) then
            tagBillboard(inst, "🔴 Weapon", Color3.fromRGB(255, 70, 70))
            counts.guns += 1
        end

        -- Recursos: árboles / minerales
        if toggles.espResources and (hasAny(name, TREE_NAMES) or hasAny(name, ORE_NAMES)) then
            tagBillboard(inst, hasAny(name, TREE_NAMES) and "🌳 Tree" or "⛏️ Resource",
                hasAny(name, TREE_NAMES) and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(120, 150, 255))
            counts.res += 1
        end

        -- Animales
        if toggles.espAnimals and hasAny(name, ANIMAL_NAMES) then
            tagBillboard(inst, "🐾 Animal", Color3.fromRGB(255, 140, 0))
            counts.ani += 1
        end
    end

    return counts
end

--== Auto-talar árboles (requiere hacha equipada)
local function tryInteract(model)
    -- Intenta activar ProximityPrompt o ClickDetector si existe
    if not model or not model.Parent then return false end
    local ok = false
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function()
                fireproximityprompt(d) -- disponible en muchos ejecutores
                ok = true
            end)
        elseif d:IsA("ClickDetector") then
            pcall(function()
                fireclickdetector(d)
                ok = true
            end)
        end
    end
    return ok
end

local function nearestTree(maxDist)
    maxDist = maxDist or 18
    local nearest, nd = nil, math.huge
    for _, inst in ipairs(workspace:GetDescendants()) do
        if hasAny(inst.Name, TREE_NAMES) then
            local part
            if inst:IsA("Model") and inst.PrimaryPart then
                part = inst.PrimaryPart
            elseif inst:IsA("BasePart") then
                part = inst
            end
            if part then
                local d = distance(hrp.Position, part.Position)
                if d < nd and d <= maxDist then
                    nd = d
                    nearest = inst
                end
            end
        end
    end
    return nearest, nd
end

local autoChopConn
local function setAutoChop(on)
    if on then
        if autoChopConn then autoChopConn:Disconnect() end
        autoChopConn = RS.Heartbeat:Connect(function()
            local hasAxe = isAxeEquipped()
            if not hasAxe then return end
            local tree = nearestTree(18)
            if tree then
                -- acercarse un poco si hace falta
                local part = (tree:IsA("Model") and tree.PrimaryPart) or (tree:IsA("BasePart") and tree)
                if part then
                    if distance(hrp.Position, part.Position) > 6 then
                        hum:MoveTo(part.Position + Vector3.new(0, 0, 0))
                    end
                end
                -- intentar interactuar continuamente
                tryInteract(tree)
            end
        end)
        notify("🪓 Auto-talar ACTIVADO (con hacha)")
    else
        if autoChopConn then autoChopConn:Disconnect() end
        notify("🪓 Auto-talar DESACTIVADO")
    end
end

--== HUD Móvil (botones táctiles + contador)
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.Name = "PicolasNightOps"
gui.ResetOnSpawn = false

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 220, 0, 120)
panel.Position = UDim2.new(0, 15, 0, 15)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true

local stroke = Instance.new("UIStroke", panel)
stroke.Thickness = 2
task.spawn(function()
    local h=0
    while task.wait(0.03) do
        h=(h+2)%360
        stroke.Color = Color3.fromHSV(h/360,1,1)
    end
end)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, 0, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1,1,1)
title.Text = "🧠 Night Ops"

local countsLabel = Instance.new("TextLabel", panel)
countsLabel.Size = UDim2.new(1, -10, 0, 20)
countsLabel.Position = UDim2.new(0, 5, 0, 26)
countsLabel.BackgroundTransparency = 1
countsLabel.TextXAlignment = Enum.TextXAlignment.Left
countsLabel.Font = Enum.Font.Gotham
countsLabel.TextSize = 14
countsLabel.TextColor3 = Color3.fromRGB(210,210,210)
countsLabel.Text = "—"

local function makeBtn(txt, x, y, cb)
    local b = Instance.new("TextButton", panel)
    b.Size = UDim2.new(0, 66, 0, 30)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(45,45,45)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Text = txt
    b.AutoButtonColor = true
    b.MouseButton1Click:Connect(cb)
    return b
end

local btnVision = makeBtn("🌙", 5, 52, function()
    toggles.vision = not toggles.vision
    applyNightVision(toggles.vision and isDark())
    notify(toggles.vision and "🌙 Visión ON" or "🌙 Visión OFF")
end)

local btnESP = makeBtn("🎯ESP", 77, 52, function()
    -- Alterna paquete de ESP loot (cofres/curas/armas). Recursos/animales quedan aparte.
    local state = not (toggles.espLoot or toggles.espHeal or toggles.espGuns)
    toggles.espLoot, toggles.espHeal, toggles.espGuns = state, state, state
    notify(state and "🎯 ESP Loot/Heal/Guns ON" or "🎯 ESP Loot/Heal/Guns OFF")
end)

local btnChop = makeBtn("🪓", 149, 52, function()
    toggles.autoChop = not toggles.autoChop
    setAutoChop(toggles.autoChop)
end)

local btnMore = makeBtn("🌳/🐾", 5, 86, function()
    -- Alterna ESP recursos/animales
    local state = not (toggles.espResources or toggles.espAnimals)
    toggles.espResources, toggles.espAnimals = state, state
    notify(state and "🌳/🐾 ESP Recursos/Animales ON" or "🌳/🐾 ESP Recursos/Animales OFF")
end)

local btnHide = makeBtn("👁‍🗨", 149, 86, function()
    panel.Visible = not panel.Visible
end)

--== Ciclo principal
task.spawn(function()
    -- Auto night vision al iniciar
    applyNightVision(toggles.vision and isDark())
    setAutoChop(toggles.autoChop)

    -- Reaccionar a cambios de luz cada 1s
    task.spawn(function()
        while task.wait(1) do
            if toggles.vision then
                applyNightVision(isDark())
            end
        end
    end)

    -- Escanear mundo cada X seg y refrescar contador
    while task.wait(scanInterval) do
        local c = scanWorld()
        countsLabel.Text =
            ("🟡%d  💚%d  🔴%d  🌳%d  🐾%d"):format(c.loot, c.heal, c.guns, c.res, c.ani)
    end
end)

-- Seguridad al respawn
player.CharacterAdded:Connect(function(nc)
    char = nc
    hum = nc:WaitForChild("Humanoid")
    hrp = nc:WaitForChild("HumanoidRootPart")
    -- Reaplicar efectos
    applyNightVision(false)
    task.wait(1)
    applyNightVision(toggles.vision and isDark())
    setAutoChop(toggles.autoChop)
    notify("♻️ Night Ops listo tras respawn")
end)
