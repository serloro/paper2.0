--[[
    GameUI.client.lua
    Sistema de UI del juego con LOGS de depuración
    
    Métodos principales:
    - Initialize(): Inicializa la UI al entrar a una partida
    - Finalize(): Finaliza la UI al salir de una partida
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("🎨 [GameUI] Iniciando creación de UI para", player.Name)

-- IMPORTANTE: Destruir UI anterior si existe (para evitar duplicados)
local existingUI = playerGui:FindFirstChild("GameUI")
if existingUI then
	print("🎨 [GameUI] Destruyendo UI anterior")
	existingUI:Destroy()
end

-- ========== CREAR SCREENGUI ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ========== FRAME PRINCIPAL DEL HUD ==========
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUDFrame"
hudFrame.Size = UDim2.new(1, 0, 0, 80)
hudFrame.Position = UDim2.new(0, 0, 0, 0)
hudFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
hudFrame.BackgroundTransparency = 0.3
hudFrame.BorderSizePixel = 0
hudFrame.Visible = false  -- SIEMPRE empieza oculto
hudFrame.Parent = screenGui

print("🎨 [GameUI] HUD creado - Visible:", hudFrame.Visible)

-- Gradiente para el HUD
local hudGradient = Instance.new("UIGradient")
hudGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 35, 50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 20, 30))
})
hudGradient.Rotation = 90
hudGradient.Parent = hudFrame

-- ========== SECCIÓN: TEMPORIZADOR ==========
local timerSection = Instance.new("Frame")
timerSection.Name = "TimerSection"
timerSection.Size = UDim2.new(0.25, 0, 1, 0)
timerSection.Position = UDim2.new(0, 0, 0, 0)
timerSection.BackgroundTransparency = 1
timerSection.Parent = hudFrame

local timerIcon = Instance.new("TextLabel")
timerIcon.Name = "Icon"
timerIcon.Size = UDim2.new(0.3, 0, 1, 0)
timerIcon.BackgroundTransparency = 1
timerIcon.Text = "⏱️"
timerIcon.TextScaled = true
timerIcon.Font = Enum.Font.GothamBold
timerIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
timerIcon.Parent = timerSection

local timerValueLabel = Instance.new("TextLabel")
timerValueLabel.Name = "Value"
timerValueLabel.Size = UDim2.new(0.7, 0, 1, 0)
timerValueLabel.Position = UDim2.new(0.3, 0, 0, 0)
timerValueLabel.BackgroundTransparency = 1
timerValueLabel.Text = "60"
timerValueLabel.TextScaled = true
timerValueLabel.Font = Enum.Font.GothamBlack
timerValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerValueLabel.Parent = timerSection

-- ========== SECCIÓN: ÁREA/TERRITORIO ==========
local areaSection = Instance.new("Frame")
areaSection.Name = "AreaSection"
areaSection.Size = UDim2.new(0.25, 0, 1, 0)
areaSection.Position = UDim2.new(0.25, 0, 0, 0)
areaSection.BackgroundTransparency = 1
areaSection.Parent = hudFrame

local areaIcon = Instance.new("TextLabel")
areaIcon.Name = "Icon"
areaIcon.Size = UDim2.new(0.3, 0, 1, 0)
areaIcon.BackgroundTransparency = 1
areaIcon.Text = "📊"
areaIcon.TextScaled = true
areaIcon.Font = Enum.Font.GothamBold
areaIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
areaIcon.Parent = areaSection

local areaValueLabel = Instance.new("TextLabel")
areaValueLabel.Name = "Value"
areaValueLabel.Size = UDim2.new(0.7, 0, 1, 0)
areaValueLabel.Position = UDim2.new(0.3, 0, 0, 0)
areaValueLabel.BackgroundTransparency = 1
areaValueLabel.Text = "0%"
areaValueLabel.TextScaled = true
areaValueLabel.Font = Enum.Font.GothamBlack
areaValueLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
areaValueLabel.Parent = areaSection

-- ========== SECCIÓN: JUGADORES VIVOS ==========
local aliveSection = Instance.new("Frame")
aliveSection.Name = "AliveSection"
aliveSection.Size = UDim2.new(0.25, 0, 1, 0)
aliveSection.Position = UDim2.new(0.5, 0, 0, 0)
aliveSection.BackgroundTransparency = 1
aliveSection.Parent = hudFrame

local aliveIcon = Instance.new("TextLabel")
aliveIcon.Name = "Icon"
aliveIcon.Size = UDim2.new(0.3, 0, 1, 0)
aliveIcon.BackgroundTransparency = 1
aliveIcon.Text = "👥"
aliveIcon.TextScaled = true
aliveIcon.Font = Enum.Font.GothamBold
aliveIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
aliveIcon.Parent = aliveSection

local aliveCountLabel = Instance.new("TextLabel")
aliveCountLabel.Name = "Value"
aliveCountLabel.Size = UDim2.new(0.7, 0, 1, 0)
aliveCountLabel.Position = UDim2.new(0.3, 0, 0, 0)
aliveCountLabel.BackgroundTransparency = 1
aliveCountLabel.Text = "8"
aliveCountLabel.TextScaled = true
aliveCountLabel.Font = Enum.Font.GothamBlack
aliveCountLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
aliveCountLabel.Parent = aliveSection

-- ========== SECCIÓN: ESTADO/ZONA ==========
local statusSection = Instance.new("Frame")
statusSection.Name = "StatusSection"
statusSection.Size = UDim2.new(0.25, 0, 1, 0)
statusSection.Position = UDim2.new(0.75, 0, 0, 0)
statusSection.BackgroundTransparency = 1
statusSection.Parent = hudFrame

local zoneLabel = Instance.new("TextLabel")
zoneLabel.Name = "Zone"
zoneLabel.Size = UDim2.new(1, 0, 0.5, 0)
zoneLabel.BackgroundTransparency = 1
zoneLabel.Text = "🛡️ SAFE ZONE"
zoneLabel.TextScaled = true
zoneLabel.Font = Enum.Font.GothamBold
zoneLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
zoneLabel.Parent = statusSection

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0.5, 0)
statusLabel.Position = UDim2.new(0, 0, 0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "IN MATCH"
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
statusLabel.Parent = statusSection

-- ========== FRAME DE MENSAJES ==========
local messageFrame = Instance.new("Frame")
messageFrame.Name = "MessageFrame"
messageFrame.Size = UDim2.new(0.6, 0, 0.2, 0)
messageFrame.Position = UDim2.new(0.2, 0, 0.4, 0)
messageFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
messageFrame.BackgroundTransparency = 0.2
messageFrame.BorderSizePixel = 0
messageFrame.Visible = false
messageFrame.Parent = screenGui

local messageCorner = Instance.new("UICorner")
messageCorner.CornerRadius = UDim.new(0, 15)
messageCorner.Parent = messageFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.Size = UDim2.new(1, -20, 1, -20)
messageLabel.Position = UDim2.new(0, 10, 0, 10)
messageLabel.BackgroundTransparency = 1
messageLabel.Text = ""
messageLabel.TextScaled = true
messageLabel.Font = Enum.Font.GothamBlack
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.Parent = messageFrame

-- ========================================
-- MÓDULO GameUI
-- ========================================
local GameUI = {}

-- Estado interno
GameUI.isActive = false

-- ========================================
-- MÉTODO PRINCIPAL: INITIALIZE
-- ========================================
function GameUI.Initialize()
	print("🎨 [GameUI] ========== INITIALIZE ==========")
	print("🎨 [GameUI] Estado anterior: isActive =", GameUI.isActive)
	print("🎨 [GameUI] HUD visible anterior:", hudFrame.Visible)

	-- Activar UI
	GameUI.isActive = true

	-- Resetear valores
	timerValueLabel.Text = "60"
	timerValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	areaValueLabel.Text = "0%"
	aliveCountLabel.Text = "8"
	zoneLabel.Text = "🛡️ SAFE ZONE"
	zoneLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusLabel.Text = "IN MATCH"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

	-- Mostrar HUD
	hudFrame.Visible = true
	messageFrame.Visible = false

	print("🎨 [GameUI] Estado nuevo: isActive =", GameUI.isActive)
	print("🎨 [GameUI] HUD visible nuevo:", hudFrame.Visible)
	print("🎨 [GameUI] ========== FIN INITIALIZE ==========")
end

-- ========================================
-- MÉTODO PRINCIPAL: FINALIZE
-- ========================================
function GameUI.Finalize()
	print("🎨 [GameUI] ========== FINALIZE ==========")
	print("🎨 [GameUI] Estado anterior: isActive =", GameUI.isActive)
	print("🎨 [GameUI] HUD visible anterior:", hudFrame.Visible)

	-- Desactivar UI
	GameUI.isActive = false

	-- Ocultar HUD
	hudFrame.Visible = false
	messageFrame.Visible = false

	-- Limpiar valores
	timerValueLabel.Text = "--"
	areaValueLabel.Text = "0%"
	aliveCountLabel.Text = "0"
	statusLabel.Text = ""
	zoneLabel.Text = ""

	print("🎨 [GameUI] Estado nuevo: isActive =", GameUI.isActive)
	print("🎨 [GameUI] HUD visible nuevo:", hudFrame.Visible)
	print("🎨 [GameUI] ========== FIN FINALIZE ==========")
end

-- ========================================
-- MÉTODOS DE ACTUALIZACIÓN
-- ========================================

function GameUI.SetTimer(seconds)
	if not GameUI.isActive then 
		print("🎨 [GameUI] SetTimer ignorado - isActive:", GameUI.isActive)
		return 
	end

	timerValueLabel.Text = tostring(seconds)

	if seconds <= 10 then
		timerValueLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	elseif seconds <= 30 then
		timerValueLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	else
		timerValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function GameUI.SetAreaPercentage(percentage)
	if not GameUI.isActive then return end
	areaValueLabel.Text = string.format("%.1f%%", percentage)
end

function GameUI.SetAliveCount(count)
	if not GameUI.isActive then 
		print("🎨 [GameUI] SetAliveCount ignorado - isActive:", GameUI.isActive)
		return 
	end
	print("🎨 [GameUI] SetAliveCount:", count)
	aliveCountLabel.Text = tostring(count)
end

function GameUI.SetZoneStatus(isInSafe, isTracing)
	if not GameUI.isActive then return end

	if isTracing then
		zoneLabel.Text = "✏️ TRACING"
		zoneLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	elseif isInSafe then
		zoneLabel.Text = "🛡️ SAFE ZONE"
		zoneLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		zoneLabel.Text = "⚠️ DANGER"
		zoneLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	end
end

function GameUI.SetStatus(text, color)
	if not GameUI.isActive then return end
	statusLabel.Text = text
	if color then
		statusLabel.TextColor3 = color
	end
end

-- ========================================
-- MENSAJES (funcionan siempre)
-- ========================================

function GameUI.ShowMessage(text, duration, color)
	print("🎨 [GameUI] ShowMessage:", text)
	messageLabel.Text = text
	if color then
		messageLabel.TextColor3 = color
	end

	messageFrame.Visible = true

	if duration then
		task.delay(duration, function()
			messageFrame.Visible = false
		end)
	end
end

function GameUI.HideMessage()
	messageFrame.Visible = false
end

-- ========================================
-- COMPATIBILIDAD (alias)
-- ========================================

GameUI.Show = GameUI.Initialize
GameUI.Hide = GameUI.Finalize
GameUI.ForceHide = GameUI.Finalize

function GameUI.IsActive()
	return GameUI.isActive
end

-- Exponer globalmente
_G.GameUI = GameUI

print("🎨 [GameUI] Módulo cargado correctamente")

return GameUI
