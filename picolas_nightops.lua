--// 🧠 PICOLAS NIGHT OPS v2 (Mobile) — 99 Noches
--// by PicolasYT
--// 8 toggles independientes + 2 filas de botones + colores ON/OFF

if getgenv and getgenv().PicolasNightOpsV2Loaded then return end
if getgenv then getgenv().PicolasNightOpsV2Loaded = true end

--== Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

--== Estado / Config
local T = {
  vision = true,
  chest = true,
  heal = true,
  guns = true,
  res = true,
  animals = true,
  chop = true,
}
local SCAN_INTERVAL = 3.5
local BTN_ON = Color3.fromRGB(50, 200, 90)
local BTN_OFF = Color3.fromRGB(60, 60, 60)

local LOOT_NAMES   = {"Chest","Crate","Loot","Box"}
local HEAL_NAMES   = {"Bandage","Medkit","Heal","Cure","Venda"}
local GUN_NAMES    = {"Revolver","Pistol","Gun","Rifle","Shotgun"}
local TREE_NAMES   = {"Tree","Arbol"}
local ORE_NAMES    = {"Rock","Ore","Stone","Mineral"}
local ANIMAL_NAMES = {"Animal","Wolf","Bear","Deer","Boar","Fox"}

--== Utils
local function notify(msg)
  pcall(function() StarterGui:SetCore("SendNotification",{Title="Picolas Night Ops",Text=msg}) end)
end
local function sl(s) if typeof(s)=="string" then return s:lower() end return "" end
local function hasAny(name, list)
  name = sl(name)
  for _,w in ipairs(list) do if name:find(w:lower()) then return true end end
  return false
end
local function dist(a,b) return (a-b).Magnitude end

local function isAxeEquipped()
  local tool = char:FindFirstChildOfClass("Tool")
  if not tool then return false,nil end
  local n = sl(tool.Name)
  if n:find("axe") or n:find("hacha") then return true,tool end
  return false,tool
end

--== Vision nocturna (ColorCorrection + Bloom)
local cc = Lighting:FindFirstChild("PicolasCC") or Instance.new("ColorCorrectionEffect",Lighting)
cc.Name="PicolasCC"
local bloom = Lighting:FindFirstChild("PicolasBloom") or Instance.new("BloomEffect",Lighting)
bloom.Name="PicolasBloom"

local function applyNightVision(on)
  if on then
    cc.Enabled=true; cc.Brightness=0.08; cc.Contrast=0.15; cc.Saturation=0.2; cc.TintColor=Color3.fromRGB(170,255,170)
    bloom.Enabled=true; bloom.Intensity=0.5; bloom.Threshold=1; bloom.Size=10
  else
    cc.Enabled=false; bloom.Enabled=false
  end
end

local function isDark()
  local amb=Lighting.Ambient; local bri=(amb.R+amb.G+amb.B)/3
  local night = Lighting.ClockTime and (Lighting.ClockTime<6 or Lighting.ClockTime>18)
  return bri<0.2 or night
end

--== ESP manager
local function tag(target, label, color, category)
  if not target or not target.Parent then return end
  local existing = target:FindFirstChild("PicolasESPTag")
  if not existing then
    local b=Instance.new("BillboardGui")
    b.Name="PicolasESPTag"; b.Size=UDim2.new(0,120,0,26); b.StudsOffset=Vector3.new(0,3,0); b.AlwaysOnTop=true
    b.Parent=target
    local tl=Instance.new("TextLabel",b)
    tl.Name="LBL"; tl.Size=UDim2.new(1,0,1,0); tl.BackgroundTransparency=1
    tl.Font=Enum.Font.GothamBold; tl.TextSize=14
  end
  local b = target:FindFirstChild("PicolasESPTag")
  local tl = b and b:FindFirstChild("LBL")
  if tl then tl.Text=label; tl.TextColor3=color end
  if b then b:SetAttribute("PicolasCat", category) end
end

local function untagIfCategoryOff(inst)
  local b = inst:FindFirstChild("PicolasESPTag")
  if not b then return end
  local cat = b:GetAttribute("PicolasCat")
  if (cat=="chest" and not T.chest) or
     (cat=="heal" and not T.heal) or
     (cat=="guns" and not T.guns) or
     (cat=="res" and not T.res) or
     (cat=="animals" and not T.animals) then
      b:Destroy()
  end
end

local function scanWorld()
  for _,inst in ipairs(workspace:GetDescendants()) do
    local n = inst.Name; if not n then continue end
    -- Cofres
    if hasAny(n, LOOT_NAMES) then
      if T.chest then tag(inst,"🟡 Chest/Loot", Color3.fromRGB(255,230,0),"chest")
      else untagIfCategoryOff(inst) end
    end
    -- Curaciones
    if hasAny(n, HEAL_NAMES) then
      if T.heal then tag(inst,"💚 Heal", Color3.fromRGB(50,255,120),"heal")
      else untagIfCategoryOff(inst) end
    end
    -- Armas
    if hasAny(n, GUN_NAMES) then
      if T.guns then tag(inst,"🔴 Weapon", Color3.fromRGB(255,70,70),"guns")
      else untagIfCategoryOff(inst) end
    end
    -- Recursos (árboles / minerales)
    if hasAny(n, TREE_NAMES) or hasAny(n, ORE_NAMES) then
      if T.res then
        local isTree = hasAny(n, TREE_NAMES)
        tag(inst, isTree and "🌳 Tree" or "⛏️ Resource", isTree and Color3.fromRGB(120,200,255) or Color3.fromRGB(120,150,255), "res")
      else untagIfCategoryOff(inst) end
    end
    -- Animales
    if hasAny(n, ANIMAL_NAMES) then
      if T.animals then tag(inst,"🐾 Animal", Color3.fromRGB(255,140,0),"animals")
      else untagIfCategoryOff(inst) end
    end
  end
end

--== Auto-talar
local function tryInteract(model)
  if not model or not model.Parent then return false end
  local ok=false
  for _,d in ipairs(model:GetDescendants()) do
    if d:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(d) ok=true end) end
    if d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) ok=true end) end
  end
  return ok
end

local function nearestTree(maxDist)
  maxDist=maxDist or 18
  local best,bd= nil, math.huge
  for _,inst in ipairs(workspace:GetDescendants()) do
    if hasAny(inst.Name, TREE_NAMES) then
      local part = (inst:IsA("Model") and inst.PrimaryPart) or (inst:IsA("BasePart") and inst) or nil
      if part then
        local d = dist(hrp.Position, part.Position)
        if d<bd and d<=maxDist then best,bd = inst,d end
      end
    end
  end
  return best, bd
end

local chopConn
local function setChop(on)
  if on then
    if chopConn then chopConn:Disconnect() end
    chopConn = RS.Heartbeat:Connect(function()
      local okAxe = isAxeEquipped()
      if not okAxe then return end
      local tree = nearestTree(18)
      if not tree then return end
      local part = (tree:IsA("Model") and tree.PrimaryPart) or (tree:IsA("BasePart") and tree)
      if part and dist(hrp.Position, part.Position) > 6 then
        hum:MoveTo(part.Position)
      end
      tryInteract(tree)
    end)
    notify("🪓 Auto-talar ACTIVADO (requiere hacha)")
  else
    if chopConn then chopConn:Disconnect() chopConn=nil end
    notify("🪓 Auto-talar DESACTIVADO")
  end
end

--== HUD (2 filas × 4 botones, colores ON/OFF)
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.Name="PicolasNightOpsV2"; gui.ResetOnSpawn=false

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 260, 0, 120)
panel.Position = UDim2.new(0, 15, 0, 15)
panel.BackgroundColor3 = Color3.fromRGB(20,20,20)
panel.BorderSizePixel = 0
panel.Active = true; panel.Draggable = true

local stroke = Instance.new("UIStroke",panel)
stroke.Thickness=2
task.spawn(function() local h=0; while task.wait(0.03) do h=(h+2)%360; stroke.Color=Color3.fromHSV(h/360,1,1) end end)

local title = Instance.new("TextLabel", panel)
title.Size=UDim2.new(1,0,0,22)
title.BackgroundTransparency=1
title.Font=Enum.Font.GothamBold
title.TextSize=16
title.TextColor3=Color3.new(1,1,1)
title.Text="🧠 Night Ops v2"

local function makeBtn(txt, x, y, stateGetter, onToggle)
  local b=Instance.new("TextButton", panel)
  b.Size=UDim2.new(0, 60, 0, 32)
  b.Position=UDim2.new(0, x, 0, y)
  b.Text=txt; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=14
  b.AutoButtonColor=true
  local function refresh() b.BackgroundColor3 = stateGetter() and BTN_ON or BTN_OFF end
  refresh()
  b.MouseButton1Click:Connect(function() onToggle(); refresh() end)
  return b, refresh
end

-- Fila 1 (y=30): 🌙 🟡 💚 🔴
local _,r1 = makeBtn("🌙", 10, 30, function() return T.vision end, function()
  T.vision = not T.vision
  applyNightVision(T.vision and isDark())
  notify(T.vision and "🌙 Visión ON" or "🌙 Visión OFF")
end)

local _,r2 = makeBtn("🟡", 75, 30, function() return T.chest end, function()
  T.chest = not T.chest; notify(T.chest and "🟡 Cofres ON" or "🟡 Cofres OFF")
end)

local _,r3 = makeBtn("💚", 140, 30, function() return T.heal end, function()
  T.heal = not T.heal; notify(T.heal and "💚 Curaciones ON" or "💚 Curaciones OFF")
end)

local _,r4 = makeBtn("🔴", 205, 30, function() return T.guns end, function()
  T.guns = not T.guns; notify(T.guns and "🔴 Armas ON" or "🔴 Armas OFF")
end)

-- Fila 2 (y=70): 🌳 🐾 🪓 🎮
local _,r5 = makeBtn("🌳", 10, 70, function() return T.res end, function()
  T.res = not T.res; notify(T.res and "🌳 Recursos ON" or "🌳 Recursos OFF")
end)

local _,r6 = makeBtn("🐾", 75, 70, function() return T.animals end, function()
  T.animals = not T.animals; notify(T.animals and "🐾 Animales ON" or "🐾 Animales OFF")
end)

local _,r7 = makeBtn("🪓", 140, 70, function() return T.chop end, function()
  T.chop = not T.chop; setChop(T.chop)
end)

-- 🎮 Mostrar/Ocultar HUD (dentro del panel)
local _,r8 = makeBtn("🎮", 205, 70, function() return panel.Visible end, function()
  panel.Visible=false
end)

-- Botón flotante para volver a mostrar el panel
local showBtn = Instance.new("TextButton", gui)
showBtn.Size=UDim2.new(0,46,0,46)
showBtn.Position=UDim2.new(0, 15, 0, 140)
showBtn.Text="💡"; showBtn.TextSize=22; showBtn.Font=Enum.Font.GothamBold
showBtn.TextColor3=Color3.new(1,1,1)
showBtn.BackgroundColor3=Color3.fromRGB(35,35,35)
local s2=Instance.new("UIStroke",showBtn); s2.Thickness=2
task.spawn(function() local h=0; while task.wait(0.03) do h=(h+2)%360; s2.Color=Color3.fromHSV(h/360,1,1) end end)
showBtn.MouseButton1Click:Connect(function()
  panel.Visible=true
  r8() -- refresca color del botón 🎮
end)

--== Loops
-- Visión nocturna auto
task.spawn(function()
  while task.wait(1) do
    if T.vision then applyNightVision(isDark()) end
  end
end)

-- Escaneo periódico
task.spawn(function()
  while task.wait(SCAN_INTERVAL) do
    scanWorld()
  end
end)

-- Auto-talar inicial
setChop(T.chop)

-- Seguridad al respawn
player.CharacterAdded:Connect(function(nc)
  char=nc; hum=nc:WaitForChild("Humanoid"); hrp=nc:WaitForChild("HumanoidRootPart")
  applyNightVision(false); task.wait(1); applyNightVision(T.vision and isDark())
  setChop(T.chop)
  notify("♻️ Night Ops listo tras respawn")
end)
