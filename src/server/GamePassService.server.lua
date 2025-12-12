--[[
    GamePassService.server.lua
    Sistema de GamePasses para monetización
    
    IMPORTANTE: Debes crear los GamePasses en el dashboard de Roblox:
    1. Ve a tu juego en roblox.com/create
    2. Click en "Associated Items" > "Passes"
    3. Crea 3 GamePasses y copia sus IDs aquí
    
    ITEMS:
    1. VIP Pass (💎) - Velocidad +20%, zona inicial +50%
    2. Trail Effect (✨) - Estela de partículas al caminar
    3. Golden Skin (🌟) - Color dorado exclusivo con brillo
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================
-- IDS DE GAMEPASSES (CAMBIAR POR LOS REALES)
-- ========================================
local GAMEPASS_IDS = {
	VIP = 0,           -- Reemplazar con ID real
	TRAIL = 0,         -- Reemplazar con ID real  
	GOLDEN_SKIN = 0,   -- Reemplazar con ID real
}

-- Precios sugeridos (solo referencia, se configura en el dashboard)
local SUGGESTED_PRICES = {
	VIP = 199,         -- 199 Robux
	TRAIL = 99,        -- 99 Robux
	GOLDEN_SKIN = 149, -- 149 Robux
}

-- ========================================
-- CACHE DE JUGADORES CON GAMEPASSES
-- ========================================
local PlayerGamePasses = {}

-- ========================================
-- VERIFICAR SI JUGADOR TIENE GAMEPASS
-- ========================================
local function HasGamePass(player, passType)
	if not player then return false end

	local userId = player.UserId
	local passId = GAMEPASS_IDS[passType]

	-- Si el ID es 0, no está configurado (modo desarrollo)
	if passId == 0 then
		-- Para pruebas, usuarios debug tienen todos los passes
		local debugUsers = {"serloro", "serloro3"}
		for _, name in ipairs(debugUsers) do
			if player.Name:lower():find(name:lower()) then
				return true
			end
		end
		return false
	end

	-- Verificar cache
	if PlayerGamePasses[userId] and PlayerGamePasses[userId][passType] ~= nil then
		return PlayerGamePasses[userId][passType]
	end

	-- Verificar con MarketplaceService
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end)

	if success then
		if not PlayerGamePasses[userId] then
			PlayerGamePasses[userId] = {}
		end
		PlayerGamePasses[userId][passType] = hasPass
		return hasPass
	end

	return false
end

-- ========================================
-- APLICAR BENEFICIOS VIP
-- ========================================
local function ApplyVIPBenefits(player)
	if not HasGamePass(player, "VIP") then return end

	-- Añadir atributo VIP
	player:SetAttribute("IsVIP", true)
	player:SetAttribute("SpeedBonus", 1.2)        -- 20% más rápido
	player:SetAttribute("StartZoneBonus", 1.5)    -- 50% zona inicial más grande

	print("💎 VIP activado para", player.Name)
end

-- ========================================
-- APLICAR TRAIL EFFECT
-- ========================================
local function ApplyTrailEffect(player)
	if not HasGamePass(player, "TRAIL") then return end

	player:SetAttribute("HasTrail", true)

	-- Crear trail cuando el personaje aparece
	local function CreateTrail(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if not hrp then return end

		-- Verificar si ya tiene trail
		if hrp:FindFirstChild("TrailAttachment0") then return end

		-- Crear attachments
		local attachment0 = Instance.new("Attachment")
		attachment0.Name = "TrailAttachment0"
		attachment0.Position = Vector3.new(0, 0, 0.5)
		attachment0.Parent = hrp

		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "TrailAttachment1"
		attachment1.Position = Vector3.new(0, 0, -0.5)
		attachment1.Parent = hrp

		-- Crear trail
		local trail = Instance.new("Trail")
		trail.Name = "VIPTrail"
		trail.Attachment0 = attachment0
		trail.Attachment1 = attachment1
		trail.Lifetime = 0.8
		trail.MinLength = 0.1
		trail.FaceCamera = true
		trail.LightEmission = 0.5
		trail.LightInfluence = 0.3
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 1)
		})
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 100))
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 0)
		})
		trail.Parent = hrp

		-- Añadir partículas
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "TrailParticles"
		particles.Rate = 20
		particles.Speed = NumberRange.new(1, 3)
		particles.Lifetime = NumberRange.new(0.5, 1)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0)
		})
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1)
		})
		particles.Color = ColorSequence.new(Color3.fromRGB(200, 150, 255))
		particles.LightEmission = 0.8
		particles.Parent = hrp
	end

	-- Aplicar al personaje actual
	if player.Character then
		CreateTrail(player.Character)
	end

	-- Aplicar cuando respawnee
	player.CharacterAdded:Connect(function(character)
		task.delay(0.5, function()
			CreateTrail(character)
		end)
	end)

	print("✨ Trail activado para", player.Name)
end

-- ========================================
-- APLICAR GOLDEN SKIN
-- ========================================
local function ApplyGoldenSkin(player)
	if not HasGamePass(player, "GOLDEN_SKIN") then return end

	player:SetAttribute("HasGoldenSkin", true)

	local function ApplySkin(character)
		task.delay(0.5, function()
			-- Aplicar color dorado a todas las partes del cuerpo
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = Color3.fromRGB(255, 200, 50)
					part.Material = Enum.Material.Foil

					-- Añadir brillo
					if not part:FindFirstChild("GoldenGlow") then
						local glow = Instance.new("PointLight")
						glow.Name = "GoldenGlow"
						glow.Color = Color3.fromRGB(255, 215, 0)
						glow.Brightness = 0.5
						glow.Range = 5
						glow.Parent = part
					end
				end
			end

			-- Añadir corona/efecto en la cabeza
			local head = character:FindFirstChild("Head")
			if head and not head:FindFirstChild("GoldenCrown") then
				local crown = Instance.new("Part")
				crown.Name = "GoldenCrown"
				crown.Size = Vector3.new(1.5, 0.3, 1.5)
				crown.Color = Color3.fromRGB(255, 215, 0)
				crown.Material = Enum.Material.Neon
				crown.CanCollide = false
				crown.Massless = true
				crown.Parent = head

				local weld = Instance.new("Weld")
				weld.Part0 = head
				weld.Part1 = crown
				weld.C0 = CFrame.new(0, 0.8, 0)
				weld.Parent = crown

				-- Partículas doradas
				local sparkles = Instance.new("ParticleEmitter")
				sparkles.Name = "GoldenSparkles"
				sparkles.Rate = 10
				sparkles.Speed = NumberRange.new(1, 2)
				sparkles.Lifetime = NumberRange.new(0.5, 1)
				sparkles.Size = NumberSequence.new(0.3)
				sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
				sparkles.LightEmission = 1
				sparkles.Parent = crown
			end
		end)
	end

	-- Aplicar al personaje actual
	if player.Character then
		ApplySkin(player.Character)
	end

	-- Aplicar cuando respawnee
	player.CharacterAdded:Connect(function(character)
		ApplySkin(character)
	end)

	print("🌟 Golden Skin activado para", player.Name)
end

-- ========================================
-- VERIFICAR Y APLICAR TODOS LOS PASSES
-- ========================================
local function CheckAndApplyPasses(player)
	ApplyVIPBenefits(player)
	ApplyTrailEffect(player)
	ApplyGoldenSkin(player)
end

-- ========================================
-- EVENTO DE COMPRA
-- ========================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end

	-- Limpiar cache
	if PlayerGamePasses[player.UserId] then
		PlayerGamePasses[player.UserId] = nil
	end

	-- Re-verificar passes
	CheckAndApplyPasses(player)

	print("💰 " .. player.Name .. " compró un GamePass!")
end)

-- ========================================
-- CUANDO UN JUGADOR ENTRA
-- ========================================
Players.PlayerAdded:Connect(function(player)
	task.delay(1, function()
		CheckAndApplyPasses(player)
	end)
end)

-- Aplicar a jugadores ya conectados
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		CheckAndApplyPasses(player)
	end)
end

-- ========================================
-- CREAR REMOTE PARA ABRIR COMPRA
-- ========================================
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "RemoteEvents"
	RemotesFolder.Parent = ReplicatedStorage
end

local purchaseEvent = Instance.new("RemoteEvent")
purchaseEvent.Name = "PurchaseGamePass"
purchaseEvent.Parent = RemotesFolder

purchaseEvent.OnServerEvent:Connect(function(player, passType)
	local passId = GAMEPASS_IDS[passType]
	if passId and passId > 0 then
		MarketplaceService:PromptGamePassPurchase(player, passId)
	else
		-- Modo desarrollo - simular compra
		print("🛒 [DEV MODE] " .. player.Name .. " intentó comprar " .. passType)
		-- En modo desarrollo, dar el item temporalmente
		if passType == "VIP" then
			player:SetAttribute("IsVIP", true)
			ApplyVIPBenefits(player)
		elseif passType == "TRAIL" then
			player:SetAttribute("HasTrail", true)
			ApplyTrailEffect(player)
		elseif passType == "GOLDEN_SKIN" then
			player:SetAttribute("HasGoldenSkin", true)
			ApplyGoldenSkin(player)
		end
	end
end)

-- Exponer funciones
_G.GamePassService = {
	HasGamePass = HasGamePass,
	CheckAndApplyPasses = CheckAndApplyPasses,
	GAMEPASS_IDS = GAMEPASS_IDS,
	SUGGESTED_PRICES = SUGGESTED_PRICES,
}

print("💰 GamePassService inicializado")
print("📋 IDs de GamePass configurados:")
print("   VIP:", GAMEPASS_IDS.VIP, "(", SUGGESTED_PRICES.VIP, "R$)")
print("   TRAIL:", GAMEPASS_IDS.TRAIL, "(", SUGGESTED_PRICES.TRAIL, "R$)")
print("   GOLDEN_SKIN:", GAMEPASS_IDS.GOLDEN_SKIN, "(", SUGGESTED_PRICES.GOLDEN_SKIN, "R$)")

