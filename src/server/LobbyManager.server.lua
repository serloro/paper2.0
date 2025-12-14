--[[
    LobbyManager.lua
    Gestión del lobby principal - Sala cerrada con paneles y portales
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Cargar módulos
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local DataManager = require(ReplicatedStorage:WaitForChild("DataManager"))
local MatchManager = require(ReplicatedStorage:WaitForChild("MatchManager"))

-- Referencias
local LobbyFolder = workspace:FindFirstChild("Lobby") or Instance.new("Folder", workspace)
LobbyFolder.Name = "Lobby"

-- Usuarios con acceso al portal debug
local DEBUG_USERS = {"serloro", "serloro3"}

-- Estado
local PlayerCooldowns = {}
local PORTAL_COOLDOWN = 3

-- Sala de espera
local WaitingPlayers = {}
local WaitingRoomTimer = 0
local WAITING_ROOM_TIMEOUT = 20  -- 20 segundos de espera
local MAX_WAITING_PLAYERS = 8
local WaitingRoomActive = false

--[[
╔════════════════════════════════════════════════════════════════════════════╗
║                         LOBBY MEDIEVAL - PASILLO                           ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║   SPAWN ──► TIENDA ──► SCOREBOARDS ──► PORTAL                             ║
║   (Z=0)     (Z=30)      (Z=60)         (Z=100)                             ║
║                                                                            ║
║   El jugador aparece en Z=0 y camina hacia el portal en Z=100             ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
]]

local LOBBY = {
	-- Dimensiones (sala amplia)
	WIDTH = 70,         -- Ancho (X)
	LENGTH = 140,       -- Largo (Z) - más largo para dar espacio
	HEIGHT = 20,        -- Altura paredes

	-- El jugador mira hacia Z negativo por defecto
	SPAWN_Z = 115,      -- Spawn (pared trasera en Z=140)
	SHOP_Z = 90,        -- Tienda
	SCORE_Z = 60,       -- Scoreboards
	PORTAL_Z = 15,      -- Portal (pared frontal en Z=0)
}

-- El lobby empieza aquí
local LOBBY_POSITION = Vector3.new(0, 0, 0)

-- ============================================
-- FUNCIONES DE UTILIDAD
-- ============================================

local function IsDebugUser(player)
	local playerName = player.Name:lower()
	for _, name in ipairs(DEBUG_USERS) do
		if playerName == name:lower() or playerName:find(name:lower()) then
			return true
		end
	end
	return false
end

-- ============================================
-- CREAR ANTORCHA CON FUEGO
-- ============================================
local function CreateTorch(position, parent)
	local torchFolder = Instance.new("Folder")
	torchFolder.Name = "Torch"
	torchFolder.Parent = parent or LobbyFolder

	-- Soporte de la antorcha (hierro)
	local holder = Instance.new("Part")
	holder.Name = "Holder"
	holder.Size = Vector3.new(0.5, 3, 0.5)
	holder.Position = position
	holder.Anchored = true
	holder.Material = Enum.Material.Metal
	holder.Color = Color3.fromRGB(50, 40, 30)
	holder.Parent = torchFolder

	-- Base de la antorcha
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(1, 0.5, 1)
	base.Position = position + Vector3.new(0, 1.5, 0)
	base.Anchored = true
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(60, 50, 40)
	base.Parent = torchFolder

	-- Fuego (parte brillante)
	local fire = Instance.new("Part")
	fire.Name = "Fire"
	fire.Shape = Enum.PartType.Ball
	fire.Size = Vector3.new(1.2, 1.5, 1.2)
	fire.Position = position + Vector3.new(0, 2.5, 0)
	fire.Anchored = true
	fire.Material = Enum.Material.Neon
	fire.Color = Color3.fromRGB(255, 150, 50)
	fire.CanCollide = false
	fire.Parent = torchFolder

	-- Luz del fuego
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 150, 50)
	fireLight.Brightness = 2
	fireLight.Range = 25
	fireLight.Parent = fire

	-- Partículas de fuego
	local fireParticles = Instance.new("ParticleEmitter")
	fireParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 0))
	})
	fireParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	fireParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	fireParticles.Lifetime = NumberRange.new(0.5, 1)
	fireParticles.Rate = 30
	fireParticles.Speed = NumberRange.new(2, 4)
	fireParticles.SpreadAngle = Vector2.new(10, 10)
	fireParticles.LightEmission = 1
	fireParticles.Parent = fire

	-- Chispas
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
	sparks.Size = NumberSequence.new(0.1)
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparks.Lifetime = NumberRange.new(0.5, 1.5)
	sparks.Rate = 5
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.LightEmission = 1
	sparks.Parent = fire

	-- Animación de parpadeo
	task.spawn(function()
		while fire and fire.Parent do
			local flicker = 1.5 + math.random() * 1
			fireLight.Brightness = flicker
			fire.Size = Vector3.new(1 + math.random() * 0.3, 1.3 + math.random() * 0.4, 1 + math.random() * 0.3)
			task.wait(0.1)
		end
	end)

	return torchFolder
end

-- ============================================
-- CREAR ITEM DE TIENDA (estilo medieval)
-- ============================================
local function CreateShopItem(position, itemData, facing)
	local itemFolder = Instance.new("Folder")
	itemFolder.Name = itemData.name .. "_Stand"
	itemFolder.Parent = LobbyFolder

	-- Pedestal de piedra
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Size = Vector3.new(6, 3, 6)
	pedestal.Position = position + Vector3.new(0, 1.5, 0)
	pedestal.Anchored = true
	pedestal.Material = Enum.Material.Cobblestone
	pedestal.Color = Color3.fromRGB(80, 75, 70)
	pedestal.Parent = itemFolder

	-- Decoración superior del pedestal
	local pedestalTop = Instance.new("Part")
	pedestalTop.Name = "PedestalTop"
	pedestalTop.Size = Vector3.new(7, 0.5, 7)
	pedestalTop.Position = position + Vector3.new(0, 3.25, 0)
	pedestalTop.Anchored = true
	pedestalTop.Material = Enum.Material.Slate
	pedestalTop.Color = Color3.fromRGB(60, 55, 50)
	pedestalTop.Parent = itemFolder

	-- Objeto flotante con brillo
	local displayItem = Instance.new("Part")
	displayItem.Name = "DisplayItem"
	displayItem.Shape = itemData.shape or Enum.PartType.Ball
	displayItem.Size = itemData.displaySize or Vector3.new(2.5, 2.5, 2.5)
	displayItem.Position = position + Vector3.new(0, 6, 0)
	displayItem.Anchored = true
	displayItem.Material = Enum.Material.Neon
	displayItem.Color = itemData.color
	displayItem.Parent = itemFolder

	-- Rotación y flotación
	task.spawn(function()
		local baseY = position.Y + 6
		local time = 0
		while displayItem and displayItem.Parent do
			time = time + 0.05
			displayItem.CFrame = CFrame.new(position.X, baseY + math.sin(time) * 0.5, position.Z) 
				* CFrame.Angles(0, math.rad(time * 30), 0)
			task.wait(0.03)
		end
	end)

	-- Luz mágica
	local itemLight = Instance.new("PointLight")
	itemLight.Color = itemData.color
	itemLight.Brightness = 2
	itemLight.Range = 15
	itemLight.Parent = displayItem

	-- Partículas mágicas
	local magicParticles = Instance.new("ParticleEmitter")
	magicParticles.Color = ColorSequence.new(itemData.color)
	magicParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0)
	})
	magicParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	magicParticles.Lifetime = NumberRange.new(1, 2)
	magicParticles.Rate = 15
	magicParticles.Speed = NumberRange.new(0.5, 1.5)
	magicParticles.SpreadAngle = Vector2.new(360, 360)
	magicParticles.LightEmission = 0.8
	magicParticles.Parent = displayItem

	-- Cartel de madera (girado 90° mirando hacia el pasillo central)
	local signOffset = facing == "left" and 5 or -5  -- Más apartado
	local signPost = Instance.new("Part")
	signPost.Name = "SignPost"
	signPost.Size = Vector3.new(0.5, 8, 0.5)
	signPost.Position = position + Vector3.new(signOffset, 4, 0)
	signPost.Anchored = true
	signPost.Material = Enum.Material.Wood
	signPost.Color = Color3.fromRGB(100, 70, 40)
	signPost.Parent = itemFolder

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(8, 8, 0.5)
	sign.Position = position + Vector3.new(signOffset, 10, 0)
	sign.Orientation = Vector3.new(0, facing == "left" and 90 or -90, 0)  -- Girado 180° para mirar al centro
	sign.Anchored = true
	sign.Material = Enum.Material.Wood
	sign.Color = Color3.fromRGB(80, 55, 30)
	sign.Parent = itemFolder

	-- Función para crear el contenido del cartel
	local function CreateSignContent(parent)
		local mainFrame = Instance.new("Frame")
		mainFrame.Size = UDim2.new(1, 0, 1, 0)
		mainFrame.BackgroundTransparency = 1
		mainFrame.Parent = parent

		-- Icono
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0.20, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = itemData.icon
		iconLabel.TextScaled = true
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextColor3 = itemData.color
		iconLabel.Parent = mainFrame

		-- Nombre
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.15, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.20, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = itemData.displayName
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.Fantasy
		nameLabel.TextColor3 = Color3.fromRGB(255, 230, 180)
		nameLabel.Parent = mainFrame

		-- Descripción (beneficios)
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.95, 0, 0.30, 0)
		descLabel.Position = UDim2.new(0.025, 0, 0.38, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = itemData.description or ""
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.GothamBold
		descLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
		descLabel.TextWrapped = true
		descLabel.Parent = mainFrame

		-- Precio
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(1, 0, 0.18, 0)
		priceLabel.Position = UDim2.new(0, 0, 0.72, 0)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = "💰 " .. itemData.price .. " R$"
		priceLabel.TextScaled = true
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		priceLabel.Parent = mainFrame
	end

	-- GUI en cara Front
	local surfaceGuiFront = Instance.new("SurfaceGui")
	surfaceGuiFront.Name = "SignGuiFront"
	surfaceGuiFront.Face = Enum.NormalId.Front
	surfaceGuiFront.Parent = sign
	CreateSignContent(surfaceGuiFront)

	-- GUI en cara Back (para ver desde el otro lado)
	local surfaceGuiBack = Instance.new("SurfaceGui")
	surfaceGuiBack.Name = "SignGuiBack"
	surfaceGuiBack.Face = Enum.NormalId.Back
	surfaceGuiBack.Parent = sign
	CreateSignContent(surfaceGuiBack)

	-- Zona de compra
	local buyZone = Instance.new("Part")
	buyZone.Name = "BuyButton_" .. itemData.name
	buyZone.Size = Vector3.new(6, 4, 6)
	buyZone.Position = position + Vector3.new(0, 2, 0)
	buyZone.Anchored = true
	buyZone.Transparency = 1
	buyZone.CanCollide = false
	buyZone.Parent = itemFolder

	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.ActionText = "Buy / Comprar"
	proximityPrompt.ObjectText = itemData.displayName
	proximityPrompt.HoldDuration = 0.5
	proximityPrompt.MaxActivationDistance = 8
	proximityPrompt.Parent = buyZone

	proximityPrompt.Triggered:Connect(function(player)
		local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
		if RemotesFolder then
			local purchaseEvent = RemotesFolder:FindFirstChild("PurchaseGamePass")
			if purchaseEvent then
				purchaseEvent:FireServer(itemData.name)
			end
		end
		print("🛒", player.Name, "quiere comprar", itemData.displayName)
	end)

	return itemFolder
end

-- ============================================
-- ITEMS DE LA TIENDA
-- ============================================
local SHOP_ITEMS = {
	{
		name = "VIP",
		displayName = "VIP PASS",
		description = "+20% Speed & +50% Starting Zone",
		icon = "💎",
		price = 199,
		color = Color3.fromRGB(100, 180, 255),
		shape = Enum.PartType.Block,
		displaySize = Vector3.new(2.5, 2.5, 2.5)
	},
	{
		name = "TRAIL",
		displayName = "RAINBOW TRAIL",
		description = "Rainbow particles when you walk",
		icon = "✨",
		price = 99,
		color = Color3.fromRGB(255, 100, 255),
		shape = Enum.PartType.Ball,
		displaySize = Vector3.new(2, 2, 2)
	},
	{
		name = "GOLDEN_SKIN",
		displayName = "GOLDEN SKIN",
		description = "Exclusive golden look & crown",
		icon = "🌟",
		price = 149,
		color = Color3.fromRGB(255, 215, 0),
		shape = Enum.PartType.Block,
		displaySize = Vector3.new(2, 3.5, 1)
	}
}

-- ============================================
-- CREAR LOBBY - SALA MEDIEVAL
-- ============================================

local function CreateLobby()
	for _, child in ipairs(LobbyFolder:GetChildren()) do
		child:Destroy()
	end

	local W = LOBBY.WIDTH
	local L = LOBBY.LENGTH
	local H = LOBBY.HEIGHT

	print("🏰 Creando lobby " .. W .. "x" .. L .. "...")

	-- ══════════════════════════════════════════════════════════════
	-- SUELO INVISIBLE (solo para colisión)
	-- ══════════════════════════════════════════════════════════════
	local floorCollision = Instance.new("Part")
	floorCollision.Name = "FloorCollision"
	floorCollision.Size = Vector3.new(W + 20, 1, L + 20)
	floorCollision.Position = LOBBY_POSITION + Vector3.new(0, -0.5, L/2)
	floorCollision.Anchored = true
	floorCollision.Transparency = 1
	floorCollision.Parent = LobbyFolder

	-- Suelo visual (elevado para evitar z-fighting)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(W, 0.5, L)
	floor.Position = LOBBY_POSITION + Vector3.new(0, 0.25, L/2)
	floor.Anchored = true
	floor.CanCollide = false
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(45, 40, 38)
	floor.Parent = LobbyFolder

	-- ══════════════════════════════════════════════════════════════
	-- PAREDES CON ESTILO
	-- ══════════════════════════════════════════════════════════════
	local wallColor = Color3.fromRGB(55, 50, 48)
	local trimColor = Color3.fromRGB(35, 30, 28)

	-- Pared trasera (detrás del spawn, en Z = L)
	local wallBack = Instance.new("Part")
	wallBack.Name = "WallBack"
	wallBack.Size = Vector3.new(W + 6, H, 3)
	wallBack.Position = LOBBY_POSITION + Vector3.new(0, H/2, L + 1.5)  -- Z = 141.5
	wallBack.Anchored = true
	wallBack.Material = Enum.Material.Brick
	wallBack.Color = wallColor
	wallBack.Parent = LobbyFolder

	-- Pared frontal (detrás del portal, en Z = 0)
	local wallFront = Instance.new("Part")
	wallFront.Name = "WallFront"
	wallFront.Size = Vector3.new(W + 6, H, 3)
	wallFront.Position = LOBBY_POSITION + Vector3.new(0, H/2, -1.5)  -- Z = -1.5
	wallFront.Anchored = true
	wallFront.Material = Enum.Material.Brick
	wallFront.Color = wallColor
	wallFront.Parent = LobbyFolder

	-- Paredes laterales
	for _, side in ipairs({-1, 1}) do
		local wall = Instance.new("Part")
		wall.Name = side == -1 and "WallLeft" or "WallRight"
		wall.Size = Vector3.new(3, H, L + 6)
		wall.Position = LOBBY_POSITION + Vector3.new(side * (W/2 + 1.5), H/2, L/2)
		wall.Anchored = true
		wall.Material = Enum.Material.Brick
		wall.Color = wallColor
		wall.Parent = LobbyFolder

		-- Franja decorativa inferior
		local trim = Instance.new("Part")
		trim.Name = "WallTrim"
		trim.Size = Vector3.new(3.5, 2, L + 6)
		trim.Position = LOBBY_POSITION + Vector3.new(side * (W/2 + 1.5), 1, L/2)
		trim.Anchored = true
		trim.Material = Enum.Material.Slate
		trim.Color = trimColor
		trim.Parent = LobbyFolder
	end

	-- Techo con vigas
	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Size = Vector3.new(W + 6, 2, L + 6)
	ceiling.Position = LOBBY_POSITION + Vector3.new(0, H + 1, L/2)
	ceiling.Anchored = true
	ceiling.Material = Enum.Material.Wood
	ceiling.Color = Color3.fromRGB(40, 28, 18)
	ceiling.Parent = LobbyFolder

	-- ══════════════════════════════════════════════════════════════
	-- SPAWN (lado opuesto al portal, cerca de la pared trasera)
	-- ══════════════════════════════════════════════════════════════
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 0.3, 8)
	spawn.Position = LOBBY_POSITION + Vector3.new(0, 0.65, 130)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(60, 120, 200)
	spawn.Transparency = 0.6
	spawn.Neutral = true
	spawn.Parent = LobbyFolder

	-- ══════════════════════════════════════════════════════════════
	-- ALFOMBRA ROJA (desde spawn hasta portal)
	-- ══════════════════════════════════════════════════════════════
	local carpetLength = LOBBY.SPAWN_Z - LOBBY.PORTAL_Z  -- Ahora spawn > portal
	local carpetCenterZ = (LOBBY.SPAWN_Z + LOBBY.PORTAL_Z) / 2
	local carpet = Instance.new("Part")
	carpet.Name = "RedCarpet"
	carpet.Size = Vector3.new(10, 0.4, carpetLength)
	carpet.Position = LOBBY_POSITION + Vector3.new(0, 0.7, carpetCenterZ)
	carpet.Anchored = true
	carpet.CanCollide = false
	carpet.Material = Enum.Material.Fabric
	carpet.Color = Color3.fromRGB(120, 20, 20)
	carpet.Parent = LobbyFolder

	-- Bordes dorados de la alfombra
	for _, side in ipairs({-1, 1}) do
		local border = Instance.new("Part")
		border.Name = "CarpetBorder"
		border.Size = Vector3.new(0.8, 0.45, carpetLength)
		border.Position = LOBBY_POSITION + Vector3.new(side * 5.4, 0.72, carpetCenterZ)
		border.Anchored = true
		border.CanCollide = false
		border.Material = Enum.Material.Foil
		border.Color = Color3.fromRGB(180, 140, 40)
		border.Parent = LobbyFolder
	end

	-- ══════════════════════════════════════════════════════════════
	-- TIENDA (a los lados)
	-- ══════════════════════════════════════════════════════════════
	local shopX = 24
	if SHOP_ITEMS[1] then
		CreateShopItem(LOBBY_POSITION + Vector3.new(-shopX, 0.5, LOBBY.SHOP_Z), SHOP_ITEMS[1], "right")
	end
	if SHOP_ITEMS[2] then
		CreateShopItem(LOBBY_POSITION + Vector3.new(shopX, 0.5, LOBBY.SHOP_Z), SHOP_ITEMS[2], "left")
	end
	if SHOP_ITEMS[3] then
		CreateShopItem(LOBBY_POSITION + Vector3.new(-shopX, 0.5, LOBBY.SHOP_Z + 18), SHOP_ITEMS[3], "right")
	end

	-- ══════════════════════════════════════════════════════════════
	-- COLUMNAS DECORATIVAS
	-- ══════════════════════════════════════════════════════════════
	local columnPositions = {25, 55, 85}
	for _, z in ipairs(columnPositions) do
		for _, side in ipairs({-1, 1}) do
			local x = side * (W/2 - 5)

			-- Base
			local base = Instance.new("Part")
			base.Name = "ColumnBase"
			base.Size = Vector3.new(5, 1.5, 5)
			base.Position = LOBBY_POSITION + Vector3.new(x, 1.25, z)
			base.Anchored = true
			base.Material = Enum.Material.Slate
			base.Color = trimColor
			base.Parent = LobbyFolder

			-- Columna
			local column = Instance.new("Part")
			column.Name = "Column"
			column.Size = Vector3.new(3, H - 4, 3)
			column.Position = LOBBY_POSITION + Vector3.new(x, H/2, z)
			column.Anchored = true
			column.Material = Enum.Material.Brick
			column.Color = Color3.fromRGB(65, 58, 55)
			column.Parent = LobbyFolder

			-- Antorcha
			CreateTorch(LOBBY_POSITION + Vector3.new(x - side * 2, 10, z), LobbyFolder)
		end
	end

	-- ══════════════════════════════════════════════════════════════
	-- ILUMINACIÓN
	-- ══════════════════════════════════════════════════════════════
	local light1 = Instance.new("PointLight")
	light1.Color = Color3.fromRGB(255, 200, 120)
	light1.Brightness = 1.5
	light1.Range = 60
	light1.Parent = ceiling

	print("✅ Lobby creado")
end

-- ============================================
-- CREAR PORTALES
-- ============================================

local function CreatePortals()
	-- ========== PORTAL PRINCIPAL (mirando hacia el spawn, Z positivo) ==========
	local portalFrame = Instance.new("Part")
	portalFrame.Name = "NormalPortalFrame"
	portalFrame.Size = Vector3.new(12, 16, 2)
	portalFrame.Position = LOBBY_POSITION + Vector3.new(0, 8, LOBBY.PORTAL_Z + 5)
	portalFrame.Orientation = Vector3.new(0, 180, 0)  -- Girado para mirar hacia el spawn
	portalFrame.Anchored = true
	portalFrame.Material = Enum.Material.Brick
	portalFrame.Color = Color3.fromRGB(60, 55, 50)
	portalFrame.Parent = LobbyFolder

	local portalInner = Instance.new("Part")
	portalInner.Name = "PortalInner"
	portalInner.Size = Vector3.new(8, 12, 1)
	portalInner.Position = LOBBY_POSITION + Vector3.new(0, 7, LOBBY.PORTAL_Z + 5)
	portalInner.Orientation = Vector3.new(0, 180, 0)
	portalInner.Anchored = true
	portalInner.Material = Enum.Material.SmoothPlastic
	portalInner.Color = Color3.fromRGB(5, 5, 15)
	portalInner.Parent = LobbyFolder

	local normalPortal = Instance.new("Part")
	normalPortal.Name = "NormalPortal"
	normalPortal.Size = Vector3.new(7, 11, 0.5)
	normalPortal.Position = LOBBY_POSITION + Vector3.new(0, 7, LOBBY.PORTAL_Z + 6)
	normalPortal.Orientation = Vector3.new(0, 180, 0)
	normalPortal.Anchored = true
	normalPortal.CanCollide = false
	normalPortal.Material = Enum.Material.Neon
	normalPortal.Color = Color3.fromRGB(50, 150, 255)
	normalPortal.Transparency = 0.3
	normalPortal.Parent = LobbyFolder

	-- Partículas mágicas del portal
	local portalParticles = Instance.new("ParticleEmitter")
	portalParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 150, 255))
	})
	portalParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	portalParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	portalParticles.Lifetime = NumberRange.new(1, 2)
	portalParticles.Rate = 50
	portalParticles.Speed = NumberRange.new(2, 5)
	portalParticles.SpreadAngle = Vector2.new(180, 180)
	portalParticles.LightEmission = 1
	portalParticles.Parent = normalPortal

	-- Luz del portal
	local portalLight = Instance.new("PointLight")
	portalLight.Color = Color3.fromRGB(50, 150, 255)
	portalLight.Brightness = 3
	portalLight.Range = 25
	portalLight.Parent = normalPortal

	-- Cartel encima del portal (mirando hacia el spawn)
	local signBoard = Instance.new("Part")
	signBoard.Name = "PortalSign"
	signBoard.Size = Vector3.new(12, 3, 0.5)
	signBoard.Position = LOBBY_POSITION + Vector3.new(0, 17, LOBBY.PORTAL_Z + 6)
	signBoard.Orientation = Vector3.new(0, 180, 0)
	signBoard.Anchored = true
	signBoard.Material = Enum.Material.Wood
	signBoard.Color = Color3.fromRGB(70, 45, 25)
	signBoard.Parent = LobbyFolder

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = signBoard

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.Text = "⚔️ ENTER BATTLE ⚔️"
	signText.TextScaled = true
	signText.Font = Enum.Font.Fantasy
	signText.TextColor3 = Color3.fromRGB(255, 220, 150)
	signText.Parent = signGui

	-- ========== PORTAL DEBUG (en la pared lateral) ==========
	local debugPortal = Instance.new("Part")
	debugPortal.Name = "DebugPortal"
	debugPortal.Size = Vector3.new(0.5, 6, 4)
	debugPortal.Position = LOBBY_POSITION + Vector3.new(LOBBY.WIDTH/2 - 0.5, 4, 60)
	debugPortal.Anchored = true
	debugPortal.CanCollide = false
	debugPortal.Material = Enum.Material.Neon
	debugPortal.Color = Color3.fromRGB(255, 100, 50)
	debugPortal.Transparency = 1
	debugPortal.Parent = LobbyFolder

	local debugSign = Instance.new("Part")
	debugSign.Name = "DebugSign"
	debugSign.Size = Vector3.new(0.5, 2, 4)
	debugSign.Position = LOBBY_POSITION + Vector3.new(LOBBY.WIDTH/2 - 0.5, 9, 60)
	debugSign.Anchored = true
	debugSign.Material = Enum.Material.Wood
	debugSign.Color = Color3.fromRGB(80, 50, 30)
	debugSign.Transparency = 1
	debugSign.Parent = LobbyFolder

	local debugSignGui = Instance.new("SurfaceGui")
	debugSignGui.Face = Enum.NormalId.Left
	debugSignGui.Enabled = false
	debugSignGui.Parent = debugSign

	local debugSignText = Instance.new("TextLabel")
	debugSignText.Size = UDim2.new(1, 0, 1, 0)
	debugSignText.BackgroundTransparency = 1
	debugSignText.Text = "🐛 DEBUG"
	debugSignText.TextScaled = true
	debugSignText.Font = Enum.Font.Fantasy
	debugSignText.TextColor3 = Color3.fromRGB(255, 180, 100)
	debugSignText.Parent = debugSignGui

	print("⚔️ Portales creados")
end

-- ============================================
-- CREAR PANELES DE PUNTUACIÓN - ESTILO MEDIEVAL
-- ============================================

local function CreateScoreboards()
	-- Paneles a CADA LADO de la alfombra roja, mirando hacia el jugador
	local scoreX = 18  -- Distancia desde el centro (a cada lado de la alfombra)

	-- ========== PANEL DIARIO (lado derecho de la alfombra) ==========
	local dailyBoard = Instance.new("Part")
	dailyBoard.Name = "DailyScoreBoard"
	dailyBoard.Size = Vector3.new(12, 14, 0.5)
	dailyBoard.Position = LOBBY_POSITION + Vector3.new(scoreX, 8, LOBBY.SCORE_Z)
	dailyBoard.Orientation = Vector3.new(0, 0, 0)  -- Mirando hacia Z (hacia el jugador)
	dailyBoard.Anchored = true
	dailyBoard.Material = Enum.Material.Wood
	dailyBoard.Color = Color3.fromRGB(60, 42, 28)
	dailyBoard.Parent = LobbyFolder

	-- Marco decorativo
	local dailyFrame = Instance.new("Part")
	dailyFrame.Name = "DailyFrame"
	dailyFrame.Size = Vector3.new(13.5, 15.5, 0.3)
	dailyFrame.Position = LOBBY_POSITION + Vector3.new(scoreX, 8, LOBBY.SCORE_Z)
	dailyFrame.Orientation = Vector3.new(0, 0, 0)
	dailyFrame.Anchored = true
	dailyFrame.Material = Enum.Material.Slate
	dailyFrame.Color = Color3.fromRGB(35, 28, 22)
	dailyFrame.Parent = LobbyFolder

	-- GUI en el lado frontal (mirando hacia el spawn)
	local dailyGuiFront = Instance.new("SurfaceGui")
	dailyGuiFront.Name = "DailyGui"
	dailyGuiFront.Face = Enum.NormalId.Front
	dailyGuiFront.Parent = dailyBoard
	CreateScoreboardUI(dailyGuiFront, "🏆 TODAY'S BEST", Color3.fromRGB(255, 200, 50))

	-- GUI en el lado trasero (mirando hacia el portal)
	local dailyGuiBack = Instance.new("SurfaceGui")
	dailyGuiBack.Name = "DailyGuiBack"
	dailyGuiBack.Face = Enum.NormalId.Back
	dailyGuiBack.Parent = dailyBoard
	CreateScoreboardUI(dailyGuiBack, "🏆 TODAY'S BEST", Color3.fromRGB(255, 200, 50))

	local dailyLight = Instance.new("PointLight")
	dailyLight.Color = Color3.fromRGB(255, 180, 80)
	dailyLight.Brightness = 1.5
	dailyLight.Range = 18
	dailyLight.Parent = dailyBoard

	-- ========== PANEL SEMANAL (lado izquierdo de la alfombra) ==========
	local weeklyBoard = Instance.new("Part")
	weeklyBoard.Name = "WeeklyScoreBoard"
	weeklyBoard.Size = Vector3.new(12, 14, 0.5)
	weeklyBoard.Position = LOBBY_POSITION + Vector3.new(-scoreX, 8, LOBBY.SCORE_Z)
	weeklyBoard.Orientation = Vector3.new(0, 0, 0)  -- Mirando hacia Z (hacia el jugador)
	weeklyBoard.Anchored = true
	weeklyBoard.Material = Enum.Material.Wood
	weeklyBoard.Color = Color3.fromRGB(60, 42, 28)
	weeklyBoard.Parent = LobbyFolder

	-- Marco decorativo
	local weeklyFrame = Instance.new("Part")
	weeklyFrame.Name = "WeeklyFrame"
	weeklyFrame.Size = Vector3.new(13.5, 15.5, 0.3)
	weeklyFrame.Position = LOBBY_POSITION + Vector3.new(-scoreX, 8, LOBBY.SCORE_Z)
	weeklyFrame.Orientation = Vector3.new(0, 0, 0)
	weeklyFrame.Anchored = true
	weeklyFrame.Material = Enum.Material.Slate
	weeklyFrame.Color = Color3.fromRGB(35, 28, 22)
	weeklyFrame.Parent = LobbyFolder

	-- GUI en el lado frontal (mirando hacia el spawn)
	local weeklyGuiFront = Instance.new("SurfaceGui")
	weeklyGuiFront.Name = "WeeklyGui"
	weeklyGuiFront.Face = Enum.NormalId.Front
	weeklyGuiFront.Parent = weeklyBoard
	CreateScoreboardUI(weeklyGuiFront, "🏆 WEEK'S BEST", Color3.fromRGB(200, 150, 255))

	-- GUI en el lado trasero (mirando hacia el portal)
	local weeklyGuiBack = Instance.new("SurfaceGui")
	weeklyGuiBack.Name = "WeeklyGuiBack"
	weeklyGuiBack.Face = Enum.NormalId.Back
	weeklyGuiBack.Parent = weeklyBoard
	CreateScoreboardUI(weeklyGuiBack, "🏆 WEEK'S BEST", Color3.fromRGB(200, 150, 255))

	local weeklyLight = Instance.new("PointLight")
	weeklyLight.Color = Color3.fromRGB(255, 180, 80)
	weeklyLight.Brightness = 1
	weeklyLight.Range = 15
	weeklyLight.Parent = weeklyBoard

	print("📜 Scoreboards creados")
end

function CreateScoreboardUI(surfaceGui, title, accentColor)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(50, 35, 25)  -- Color madera oscura
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = surfaceGui

	-- Borde decorativo
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(120, 90, 50)
	border.Thickness = 4
	border.Parent = mainFrame

	-- Título con estilo medieval
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.12, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.02, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = accentColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.Fantasy
	titleLabel.Parent = mainFrame

	-- Línea decorativa bajo el título
	local titleLine = Instance.new("Frame")
	titleLine.Name = "TitleLine"
	titleLine.Size = UDim2.new(0.8, 0, 0.01, 0)
	titleLine.Position = UDim2.new(0.1, 0, 0.14, 0)
	titleLine.BackgroundColor3 = accentColor
	titleLine.BorderSizePixel = 0
	titleLine.Parent = mainFrame

	-- Lista de scores
	local listFrame = Instance.new("Frame")
	listFrame.Name = "ScoreList"
	listFrame.Size = UDim2.new(0.9, 0, 0.82, 0)
	listFrame.Position = UDim2.new(0.05, 0, 0.16, 0)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0.01, 0)
	listLayout.Parent = listFrame

	-- Crear 10 slots vacíos
	for i = 1, 10 do
		local entry = Instance.new("Frame")
		entry.Name = "Entry" .. i
		entry.Size = UDim2.new(1, 0, 0.09, 0)
		entry.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
		entry.BackgroundTransparency = 0.5
		entry.LayoutOrder = i
		entry.Parent = listFrame

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "Rank"
		rankLabel.Size = UDim2.new(0.15, 0, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text = "#" .. i
		rankLabel.TextColor3 = i <= 3 and accentColor or Color3.fromRGB(150, 150, 150)
		rankLabel.TextScaled = true
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Parent = entry

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
		nameLabel.Position = UDim2.new(0.15, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "---"
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = entry

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0.3, 0, 1, 0)
		scoreLabel.Position = UDim2.new(0.7, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = "0%"
		scoreLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		scoreLabel.TextScaled = true
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = entry
	end
end

-- ============================================
-- SALA DE ESPERA (Separada del lobby) - MEJORADA
-- ============================================

local WAITING_ROOM_POSITION = Vector3.new(0, 10, 500)  -- Lejos del lobby, ELEVADO
local WAITING_ROOM_SIZE = 80  -- Sala más grande

local function CreateWaitingRoom()
	local WaitingRoomFolder = workspace:FindFirstChild("WaitingRoom") or Instance.new("Folder", workspace)
	WaitingRoomFolder.Name = "WaitingRoom"

	-- Limpiar
	for _, child in ipairs(WaitingRoomFolder:GetChildren()) do
		child:Destroy()
	end

	local halfSize = WAITING_ROOM_SIZE / 2

	-- ========== SUELO (estilo medieval como lobby) ==========
	local floorCollision = Instance.new("Part")
	floorCollision.Name = "FloorCollision"
	floorCollision.Size = Vector3.new(WAITING_ROOM_SIZE + 10, 1, WAITING_ROOM_SIZE + 10)
	floorCollision.Position = WAITING_ROOM_POSITION + Vector3.new(0, -0.5, 0)
	floorCollision.Anchored = true
	floorCollision.Transparency = 1
	floorCollision.Parent = WaitingRoomFolder

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(WAITING_ROOM_SIZE, 0.5, WAITING_ROOM_SIZE)
	floor.Position = WAITING_ROOM_POSITION + Vector3.new(0, 0.25, 0)
	floor.Anchored = true
	floor.CanCollide = false
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(45, 40, 38)
	floor.Parent = WaitingRoomFolder

	-- Círculos de spawn decorativos - CLARAMENTE por encima del suelo
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local radius = 25
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local circle = Instance.new("Part")
		circle.Name = "SpawnCircle" .. i
		circle.Shape = Enum.PartType.Cylinder
		circle.Size = Vector3.new(0.3, 6, 6)  -- Ligeramente más grueso
		circle.Position = WAITING_ROOM_POSITION + Vector3.new(x, 0.2, z)  -- Por encima del suelo
		circle.Orientation = Vector3.new(0, 0, 90)
		circle.Anchored = true
		circle.CanCollide = false
		circle.Material = Enum.Material.Neon
		circle.Color = Color3.fromRGB(50, 100, 200)
		circle.Transparency = 0.3
		circle.Parent = WaitingRoomFolder

		-- Número del jugador encima
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 80, 0, 80)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.Parent = circle

		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "NumLabel"
		numLabel.Size = UDim2.new(1, 0, 1, 0)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = tostring(i)
		numLabel.TextColor3 = Color3.fromRGB(100, 100, 100)  -- Empieza apagado
		numLabel.TextScaled = true
		numLabel.Font = Enum.Font.GothamBold
		numLabel.Parent = billboard
	end

	-- ========== PAREDES (estilo medieval) ==========
	local wallHeight = 25
	local wallColor = Color3.fromRGB(55, 50, 48)
	local wallData = {
		{pos = Vector3.new(0, wallHeight/2, halfSize + 1.5), size = Vector3.new(WAITING_ROOM_SIZE + 6, wallHeight, 3)},
		{pos = Vector3.new(0, wallHeight/2, -halfSize - 1.5), size = Vector3.new(WAITING_ROOM_SIZE + 6, wallHeight, 3)},
		{pos = Vector3.new(halfSize + 1.5, wallHeight/2, 0), size = Vector3.new(3, wallHeight, WAITING_ROOM_SIZE + 6)},
		{pos = Vector3.new(-halfSize - 1.5, wallHeight/2, 0), size = Vector3.new(3, wallHeight, WAITING_ROOM_SIZE + 6)},
	}

	for i, data in ipairs(wallData) do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Size = data.size
		wall.Position = WAITING_ROOM_POSITION + data.pos
		wall.Anchored = true
		wall.Material = Enum.Material.Brick
		wall.Color = wallColor
		wall.Parent = WaitingRoomFolder
	end

	-- ========== TECHO (estilo medieval) ==========
	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Size = Vector3.new(WAITING_ROOM_SIZE + 6, 2, WAITING_ROOM_SIZE + 6)
	ceiling.Position = WAITING_ROOM_POSITION + Vector3.new(0, wallHeight + 1, 0)
	ceiling.Anchored = true
	ceiling.Material = Enum.Material.Wood
	ceiling.Color = Color3.fromRGB(40, 28, 18)
	ceiling.Parent = WaitingRoomFolder

	-- Luz cálida
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Brightness = 1.5
	light.Range = 50
	light.Parent = ceiling

	-- ========== PANEL PRINCIPAL - TEMPORIZADOR GRANDE (estilo medieval) ==========
	local timerPanel = Instance.new("Part")
	timerPanel.Name = "TimerPanel"
	timerPanel.Size = Vector3.new(30, 15, 1)
	timerPanel.Position = WAITING_ROOM_POSITION + Vector3.new(0, 14, -halfSize + 2)
	timerPanel.Orientation = Vector3.new(0, 180, 0)
	timerPanel.Anchored = true
	timerPanel.Material = Enum.Material.Wood
	timerPanel.Color = Color3.fromRGB(60, 42, 28)
	timerPanel.Parent = WaitingRoomFolder

	-- Marco del panel
	local timerFrame = Instance.new("Part")
	timerFrame.Name = "TimerPanelFrame"
	timerFrame.Size = Vector3.new(32, 17, 0.5)
	timerFrame.Position = WAITING_ROOM_POSITION + Vector3.new(0, 14, -halfSize + 1.5)
	timerFrame.Orientation = Vector3.new(0, 180, 0)
	timerFrame.Anchored = true
	timerFrame.Material = Enum.Material.Slate
	timerFrame.Color = Color3.fromRGB(35, 28, 22)
	timerFrame.Parent = WaitingRoomFolder

	local timerGui = Instance.new("SurfaceGui")
	timerGui.Name = "TimerGui"
	timerGui.Parent = timerPanel

	local timerFrame = Instance.new("Frame")
	timerFrame.Name = "TimerFrame"
	timerFrame.Size = UDim2.new(1, 0, 1, 0)
	timerFrame.BackgroundTransparency = 1
	timerFrame.Parent = timerGui

	-- Temporizador GRANDE
	local bigTimerLabel = Instance.new("TextLabel")
	bigTimerLabel.Name = "BigTimerLabel"
	bigTimerLabel.Size = UDim2.new(1, 0, 0.6, 0)
	bigTimerLabel.Position = UDim2.new(0, 0, 0, 0)
	bigTimerLabel.BackgroundTransparency = 1
	bigTimerLabel.Text = "60"
	bigTimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bigTimerLabel.TextScaled = true
	bigTimerLabel.Font = Enum.Font.GothamBlack
	bigTimerLabel.Parent = timerFrame

	-- Contador de jugadores
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, 0, 0.25, 0)
	countLabel.Position = UDim2.new(0, 0, 0.6, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "👥 0 / 8 Players"
	countLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	countLabel.TextScaled = true
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Parent = timerFrame

	-- Status bilingüe
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.15, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.85, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Waiting for players... / Esperando jugadores..."
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = timerFrame

	-- ========== PANEL LATERAL IZQUIERDO - INSTRUCCIONES (estilo medieval) ==========
	local infoPanel = Instance.new("Part")
	infoPanel.Name = "InfoPanel"
	infoPanel.Size = Vector3.new(35, 20, 1)
	infoPanel.Position = WAITING_ROOM_POSITION + Vector3.new(-halfSize + 2, 12, 0)
	infoPanel.Orientation = Vector3.new(0, -90, 0)
	infoPanel.Anchored = true
	infoPanel.Material = Enum.Material.Wood
	infoPanel.Color = Color3.fromRGB(60, 42, 28)
	infoPanel.Parent = WaitingRoomFolder

	-- Marco del panel
	local infoPanelFrame = Instance.new("Part")
	infoPanelFrame.Name = "InfoPanelFrame"
	infoPanelFrame.Size = Vector3.new(37, 22, 0.5)
	infoPanelFrame.Position = WAITING_ROOM_POSITION + Vector3.new(-halfSize + 1.5, 12, 0)
	infoPanelFrame.Orientation = Vector3.new(0, -90, 0)
	infoPanelFrame.Anchored = true
	infoPanelFrame.Material = Enum.Material.Slate
	infoPanelFrame.Color = Color3.fromRGB(35, 28, 22)
	infoPanelFrame.Parent = WaitingRoomFolder

	local infoGui = Instance.new("SurfaceGui")
	infoGui.Name = "InfoGui"
	infoGui.Parent = infoPanel

	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(1, 0, 1, 0)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = infoGui

	-- Título grande
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.18, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.02, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🎮 HOW TO PLAY / CÓMO JUGAR"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = infoFrame

	local instructions = {
		{en = "Draw lines outside your zone", es = "Dibuja líneas fuera de tu zona"},
		{en = "Return to your zone to claim territory", es = "Vuelve a tu zona para reclamar territorio"},
		{en = "The bigger the area, the more points!", es = "¡Cuanto más grande el área, más puntos!"},
		{en = "Avoid balls and enemy lines", es = "Evita las bolas y líneas enemigas"},
		{en = "Last player standing wins!", es = "¡El último jugador en pie gana!"},
	}

	for i, inst in ipairs(instructions) do
		local yPos = 0.22 + (i-1) * 0.15

		-- Línea en inglés
		local enLine = Instance.new("TextLabel")
		enLine.Size = UDim2.new(0.95, 0, 0.07, 0)
		enLine.Position = UDim2.new(0.025, 0, yPos, 0)
		enLine.BackgroundTransparency = 1
		enLine.Text = "• " .. inst.en
		enLine.TextColor3 = Color3.fromRGB(100, 200, 255)
		enLine.TextScaled = true
		enLine.Font = Enum.Font.GothamBold
		enLine.TextXAlignment = Enum.TextXAlignment.Left
		enLine.Parent = infoFrame

		-- Línea en español
		local esLine = Instance.new("TextLabel")
		esLine.Size = UDim2.new(0.95, 0, 0.06, 0)
		esLine.Position = UDim2.new(0.025, 0, yPos + 0.07, 0)
		esLine.BackgroundTransparency = 1
		esLine.Text = "  " .. inst.es
		esLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		esLine.TextScaled = true
		esLine.Font = Enum.Font.Gotham
		esLine.TextXAlignment = Enum.TextXAlignment.Left
		esLine.Parent = infoFrame
	end

	-- ========== PANEL LATERAL DERECHO - CONTADOR TIEMPO RESTANTE ==========
	local countdownPanel = Instance.new("Part")
	countdownPanel.Name = "CountdownPanel"
	countdownPanel.Size = Vector3.new(25, 18, 1)
	countdownPanel.Position = WAITING_ROOM_POSITION + Vector3.new(halfSize - 2, 12, 0)
	countdownPanel.Orientation = Vector3.new(0, 90, 0)  -- Girado 180 grados para mirar hacia dentro
	countdownPanel.Anchored = true
	countdownPanel.Material = Enum.Material.Neon
	countdownPanel.Color = Color3.fromRGB(20, 40, 30)
	countdownPanel.Transparency = 0.2
	countdownPanel.Parent = WaitingRoomFolder

	local countdownGui = Instance.new("SurfaceGui")
	countdownGui.Name = "CountdownGui"
	countdownGui.Parent = countdownPanel

	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(1, 0, 1, 0)
	countdownFrame.BackgroundTransparency = 1
	countdownFrame.Parent = countdownGui

	-- Título
	local cdTitle = Instance.new("TextLabel")
	cdTitle.Name = "Title"
	cdTitle.Size = UDim2.new(1, 0, 0.2, 0)
	cdTitle.Position = UDim2.new(0, 0, 0.05, 0)
	cdTitle.BackgroundTransparency = 1
	cdTitle.Text = "⏱️ TIME TO START"
	cdTitle.TextColor3 = Color3.fromRGB(100, 255, 150)
	cdTitle.TextScaled = true
	cdTitle.Font = Enum.Font.GothamBold
	cdTitle.Parent = countdownFrame

	-- Número grande del countdown
	local cdNumber = Instance.new("TextLabel")
	cdNumber.Name = "CountdownNumber"
	cdNumber.Size = UDim2.new(1, 0, 0.45, 0)
	cdNumber.Position = UDim2.new(0, 0, 0.25, 0)
	cdNumber.BackgroundTransparency = 1
	cdNumber.Text = "--"
	cdNumber.TextColor3 = Color3.fromRGB(255, 255, 255)
	cdNumber.TextScaled = true
	cdNumber.Font = Enum.Font.GothamBlack
	cdNumber.Parent = countdownFrame

	-- Texto inferior
	local cdSubtitle = Instance.new("TextLabel")
	cdSubtitle.Name = "Subtitle"
	cdSubtitle.Size = UDim2.new(1, 0, 0.15, 0)
	cdSubtitle.Position = UDim2.new(0, 0, 0.72, 0)
	cdSubtitle.BackgroundTransparency = 1
	cdSubtitle.Text = "SECONDS / SEGUNDOS"
	cdSubtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
	cdSubtitle.TextScaled = true
	cdSubtitle.Font = Enum.Font.Gotham
	cdSubtitle.Parent = countdownFrame

	-- Estado
	local cdStatus = Instance.new("TextLabel")
	cdStatus.Name = "Status"
	cdStatus.Size = UDim2.new(1, 0, 0.12, 0)
	cdStatus.Position = UDim2.new(0, 0, 0.86, 0)
	cdStatus.BackgroundTransparency = 1
	cdStatus.Text = "Waiting... / Esperando..."
	cdStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
	cdStatus.TextScaled = true
	cdStatus.Font = Enum.Font.Gotham
	cdStatus.Parent = countdownFrame

	-- ========== LUZ CENTRAL ==========
	local lightPart = Instance.new("Part")
	lightPart.Name = "CentralLight"
	lightPart.Size = Vector3.new(4, 4, 4)
	lightPart.Position = WAITING_ROOM_POSITION + Vector3.new(0, 20, 0)
	lightPart.Shape = Enum.PartType.Ball
	lightPart.Anchored = true
	lightPart.Material = Enum.Material.Neon
	lightPart.Color = Color3.fromRGB(150, 200, 255)
	lightPart.Transparency = 0.5
	lightPart.Parent = WaitingRoomFolder

	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(150, 200, 255)
	pointLight.Brightness = 3
	pointLight.Range = 60
	pointLight.Parent = lightPart

	print("✅ Sala de espera MEJORADA creada")

	return WaitingRoomFolder
end

-- ============================================
-- LÓGICA DE SALA DE ESPERA
-- ============================================

local function UpdateWaitingRoomDisplay()
	local WaitingRoomFolder = workspace:FindFirstChild("WaitingRoom")
	if not WaitingRoomFolder then return end

	local timerPanel = WaitingRoomFolder:FindFirstChild("TimerPanel")
	if not timerPanel then return end

	local timerGui = timerPanel:FindFirstChild("TimerGui")
	if not timerGui then return end

	local timerFrame = timerGui:FindFirstChild("TimerFrame")
	if not timerFrame then return end

	local bigTimerLabel = timerFrame:FindFirstChild("BigTimerLabel")
	local countLabel = timerFrame:FindFirstChild("CountLabel")
	local statusLabel = timerFrame:FindFirstChild("StatusLabel")

	-- Actualizar temporizador grande
	if bigTimerLabel then
		if WaitingRoomActive and WaitingRoomTimer > 0 then
			bigTimerLabel.Text = tostring(math.ceil(WaitingRoomTimer))

			-- Color según tiempo restante
			if WaitingRoomTimer <= 10 then
				bigTimerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			elseif WaitingRoomTimer <= 30 then
				bigTimerLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			else
				bigTimerLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
			end
		else
			bigTimerLabel.Text = "--"
			bigTimerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end

	-- Actualizar contador de jugadores
	if countLabel then
		countLabel.Text = "👥 " .. #WaitingPlayers .. " / " .. MAX_WAITING_PLAYERS .. " Players"

		if #WaitingPlayers >= MAX_WAITING_PLAYERS then
			countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif #WaitingPlayers >= 4 then
			countLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		else
			countLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		end
	end

	-- Actualizar estado bilingüe
	if statusLabel then
		if #WaitingPlayers >= MAX_WAITING_PLAYERS then
			statusLabel.Text = "Starting now! / ¡Comenzando ahora!"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif WaitingRoomActive and WaitingRoomTimer > 0 then
			if WaitingRoomTimer <= 10 then
				statusLabel.Text = "Get ready! / ¡Prepárate!"
				statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			else
				statusLabel.Text = "Match starts soon... / La partida comienza pronto..."
				statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			end
		else
			statusLabel.Text = "Waiting for players... / Esperando jugadores..."
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end

	-- Actualizar círculos de spawn y números (iluminar los ocupados)
	for i = 1, 8 do
		local circle = WaitingRoomFolder:FindFirstChild("SpawnCircle" .. i)
		if circle then
			-- Buscar el número (TextLabel) dentro del BillboardGui
			local billboard = circle:FindFirstChildOfClass("BillboardGui")
			local numLabel = billboard and billboard:FindFirstChild("NumLabel")
			
			if i <= #WaitingPlayers then
				-- Círculo y número iluminados (jugador presente)
				circle.Color = Color3.fromRGB(100, 255, 100)
				circle.Transparency = 0.2
				if numLabel then
					numLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				end
			else
				-- Círculo y número apagados (esperando jugador)
				circle.Color = Color3.fromRGB(50, 100, 200)
				circle.Transparency = 0.6
				if numLabel then
					numLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
				end
			end
		end
	end

	-- ========== ACTUALIZAR PANEL DE COUNTDOWN LATERAL ==========
	local countdownPanel = WaitingRoomFolder:FindFirstChild("CountdownPanel")
	if countdownPanel then
		local countdownGui = countdownPanel:FindFirstChild("CountdownGui")
		if countdownGui then
			local countdownFrame = countdownGui:FindFirstChild("CountdownFrame")
			if countdownFrame then
				local cdNumber = countdownFrame:FindFirstChild("CountdownNumber")
				local cdStatus = countdownFrame:FindFirstChild("Status")
				local cdTitle = countdownFrame:FindFirstChild("Title")

				if cdNumber then
					if WaitingRoomActive and WaitingRoomTimer > 0 then
						cdNumber.Text = tostring(math.ceil(WaitingRoomTimer))

						-- Color según tiempo
						if WaitingRoomTimer <= 10 then
							cdNumber.TextColor3 = Color3.fromRGB(255, 80, 80)
						elseif WaitingRoomTimer <= 30 then
							cdNumber.TextColor3 = Color3.fromRGB(255, 200, 80)
						else
							cdNumber.TextColor3 = Color3.fromRGB(100, 255, 150)
						end
					else
						cdNumber.Text = "--"
						cdNumber.TextColor3 = Color3.fromRGB(100, 100, 100)
					end
				end

				if cdStatus then
					if #WaitingPlayers >= MAX_WAITING_PLAYERS then
						cdStatus.Text = "🎮 STARTING NOW! / ¡COMENZANDO!"
						cdStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
					elseif WaitingRoomActive and WaitingRoomTimer <= 10 then
						cdStatus.Text = "⚡ GET READY! / ¡PREPÁRATE!"
						cdStatus.TextColor3 = Color3.fromRGB(255, 200, 100)
					elseif WaitingRoomActive then
						cdStatus.Text = "Match starting soon... / Partida pronto..."
						cdStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
					else
						cdStatus.Text = "Waiting for player 1... / Esperando jugador 1..."
						cdStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
					end
				end

				if cdTitle then
					if #WaitingPlayers >= MAX_WAITING_PLAYERS then
						cdTitle.Text = "🎮 READY!"
						cdTitle.TextColor3 = Color3.fromRGB(100, 255, 100)
					else
						cdTitle.Text = "⏱️ TIME TO START"
						cdTitle.TextColor3 = Color3.fromRGB(100, 255, 150)
					end
				end
			end
		end
	end
end

local function TeleportToWaitingRoom(player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local randomX = math.random(-10, 10)
	local randomZ = math.random(-10, 10)
	hrp.CFrame = CFrame.new(WAITING_ROOM_POSITION + Vector3.new(randomX, 5, randomZ))
end

local function TeleportToLobby(player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Teletransporta al spawn (jugador mira hacia Z negativo = hacia el portal)
	hrp.CFrame = CFrame.new(LOBBY_POSITION + Vector3.new(0, 3, LOBBY.SPAWN_Z))
end

local function AddToWaitingRoom(player)
	for _, p in ipairs(WaitingPlayers) do
		if p == player then return end
	end

	table.insert(WaitingPlayers, player)
	TeleportToWaitingRoom(player)

	print("🚪", player.Name, "entró a la sala de espera (", #WaitingPlayers, "/", MAX_WAITING_PLAYERS, ")")

	if #WaitingPlayers == 1 then
		WaitingRoomTimer = WAITING_ROOM_TIMEOUT
		WaitingRoomActive = true
	end

	UpdateWaitingRoomDisplay()

	if #WaitingPlayers >= MAX_WAITING_PLAYERS then
		StartMatchFromWaitingRoom()
	end
end

local function RemoveFromWaitingRoom(player)
	for i, p in ipairs(WaitingPlayers) do
		if p == player then
			table.remove(WaitingPlayers, i)
			break
		end
	end

	if #WaitingPlayers == 0 then
		WaitingRoomActive = false
		WaitingRoomTimer = 0
	end

	UpdateWaitingRoomDisplay()
end

local function StartMatchFromWaitingRoom()
	if #WaitingPlayers == 0 then return end

	print("🎮 Iniciando partida con", #WaitingPlayers, "jugadores")

	local playersForMatch = {}
	for _, player in ipairs(WaitingPlayers) do
		table.insert(playersForMatch, player)
	end

	local botsNeeded = MAX_WAITING_PLAYERS - #playersForMatch
	local match = MatchManager.CreateNormalMatch(playersForMatch, botsNeeded)

	WaitingPlayers = {}
	WaitingRoomActive = false
	WaitingRoomTimer = 0
	UpdateWaitingRoomDisplay()

	local createMatch = ServerScriptService:FindFirstChild("CreateMatchController")
	if createMatch then
		createMatch:Invoke(match)
	end
end

-- Timer
spawn(function()
	while true do
		wait(1)
		if WaitingRoomActive and #WaitingPlayers > 0 then
			WaitingRoomTimer = WaitingRoomTimer - 1
			UpdateWaitingRoomDisplay()
			if WaitingRoomTimer <= 0 then
				StartMatchFromWaitingRoom()
			end
		end
	end
end)

-- ============================================
-- VISIBILIDAD PORTAL DEBUG
-- ============================================

local function UpdateDebugPortalVisibility()
	local debugPortal = LobbyFolder:FindFirstChild("DebugPortal")
	local debugFrame = LobbyFolder:FindFirstChild("DebugPortalFrame")
	if not debugPortal then return end

	local hasDebugUser = false
	for _, player in ipairs(Players:GetPlayers()) do
		if IsDebugUser(player) then
			hasDebugUser = true
			break
		end
	end

	debugPortal.Transparency = hasDebugUser and 0.3 or 1
	if debugFrame then
		debugFrame.Transparency = hasDebugUser and 0 or 1
	end

	local billboard = debugPortal:FindFirstChild("DebugBillboard")
	if billboard then
		billboard.Enabled = hasDebugUser
	end
end

-- ============================================
-- DETECCIÓN DE PORTALES
-- ============================================

local function SetupPortalTouched(portal, portalType)
	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local currentTime = tick()
		if PlayerCooldowns[player] and (currentTime - PlayerCooldowns[player]) < PORTAL_COOLDOWN then
			return
		end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end

		PlayerCooldowns[player] = currentTime

		if portalType == "NORMAL" then
			AddToWaitingRoom(player)
		elseif portalType == "DEBUG" then
			if not IsDebugUser(player) then return end

			print("🐛", player.Name, "entró a partida debug")
			local match = MatchManager.CreateDebugMatch(player)

			local createMatch = ServerScriptService:FindFirstChild("CreateMatchController")
			if createMatch then
				createMatch:Invoke(match)
			end
		end
	end)
end

-- ============================================
-- EVENTOS
-- ============================================

Players.PlayerRemoving:Connect(function(player)
	RemoveFromWaitingRoom(player)
	PlayerCooldowns[player] = nil
	UpdateDebugPortalVisibility()
end)

Players.PlayerAdded:Connect(function(player)
	UpdateDebugPortalVisibility()
	-- El jugador aparecerá automáticamente en el SpawnLocation (LobbySpawn)
	-- No necesitamos teletransportarlo manualmente
end)

-- ============================================
-- FUNCIÓN PARA ENVIAR JUGADORES AL LOBBY
-- ============================================

local SendToLobby = Instance.new("BindableFunction")
SendToLobby.Name = "SendToLobby"
SendToLobby.Parent = ServerScriptService

SendToLobby.OnInvoke = function(player)
	TeleportToLobby(player)
	return true
end

-- ============================================
-- ACTUALIZAR SCOREBOARDS
-- ============================================

local function UpdateScoreboardPanel(panelName, scores)
	local panel = LobbyFolder:FindFirstChild(panelName)
	if not panel then return end

	-- Actualizar ambas GUIs (frontal y trasera)
	local guisToUpdate = {}
	local guiFront = panel:FindFirstChild("DailyGui") or panel:FindFirstChild("WeeklyGui")
	local guiBack = panel:FindFirstChild("DailyGuiBack") or panel:FindFirstChild("WeeklyGuiBack")
	
	if guiFront then table.insert(guisToUpdate, guiFront) end
	if guiBack then table.insert(guisToUpdate, guiBack) end

	for _, gui in ipairs(guisToUpdate) do
		local mainFrame = gui:FindFirstChild("MainFrame")
		if mainFrame then
			local scoreList = mainFrame:FindFirstChild("ScoreList")
			if scoreList then
				for i = 1, 10 do
					local entry = scoreList:FindFirstChild("Entry" .. i)
					if entry then
						local nameLabel = entry:FindFirstChild("PlayerName")
						local scoreLabel = entry:FindFirstChild("Score")

						if scores[i] then
							if nameLabel then
								nameLabel.Text = scores[i].Name
							end
							if scoreLabel then
								scoreLabel.Text = string.format("%.1f%%", scores[i].Score)
							end
						else
							if nameLabel then nameLabel.Text = "---" end
							if scoreLabel then scoreLabel.Text = "0%" end
						end
					end
				end
			end
		end
	end
end

local function RefreshAllScoreboards()
	-- Obtener scores del DataManager
	local dailyScores = DataManager:GetDailyTopScores(10)
	local weeklyScores = DataManager:GetWeeklyTopScores(10)

	-- Actualizar paneles
	UpdateScoreboardPanel("DailyScoreBoard", dailyScores)
	UpdateScoreboardPanel("WeeklyScoreBoard", weeklyScores)

	print("📊 Scoreboards actualizados - Diario:", #dailyScores, "entries, Semanal:", #weeklyScores, "entries")
end

-- Actualizar scoreboards cada 10 segundos
task.spawn(function()
	while true do
		RefreshAllScoreboards()
		wait(10)
	end
end)

-- ============================================
-- INICIALIZACIÓN
-- ============================================

CreateLobby()
CreatePortals()
CreateScoreboards()
CreateWaitingRoom()

-- Configurar portales
local normalPortal = LobbyFolder:WaitForChild("NormalPortal")
local debugPortal = LobbyFolder:WaitForChild("DebugPortal")

SetupPortalTouched(normalPortal, "NORMAL")
SetupPortalTouched(debugPortal, "DEBUG")

UpdateDebugPortalVisibility()

-- Primera actualización de scoreboards
RefreshAllScoreboards()

print("🏠 Sistema de Lobby completo inicializado")

