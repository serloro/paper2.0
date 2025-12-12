--[[
    BotAI.lua
    Inteligencia artificial MEJORADA para bots con 3 comportamientos
    
    COMPORTAMIENTOS:
    - SLOW (Lento): Zonas pequeñas, movimientos cautelosos, evita riesgos
    - MEDIUM (Medio): Zonas medianas, comportamiento equilibrado
    - AGGRESSIVE (Agresivo): Zonas grandes, movimientos rápidos, asume riesgos
    
    MEJORAS:
    - Detección de peligros (bolas, líneas enemigas)
    - Planificación de rutas más inteligente
    - Evita zonas de otros jugadores
    - Comportamiento táctico
]]
print("BotAI.lua loaded")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local BotAI = {}
BotAI.__index = BotAI

-- Estados de IA
local AIState = {
	IDLE = "Idle",
	PLANNING = "Planning",
	TRACING = "Tracing",
	RETURNING = "Returning",
	FLEEING = "Fleeing",
	HUNTING = "Hunting"  -- NUEVO: Buscando cortar líneas enemigas
}

-- Tipos de comportamiento
local BehaviorType = {
	SLOW = "Slow",
	MEDIUM = "Medium",
	AGGRESSIVE = "Aggressive"
}

-- Configuración por comportamiento MEJORADA
local BehaviorConfig = {
	[BehaviorType.SLOW] = {
		Speed = 12,  -- Un poco más rápido
		MinTraceLength = 10,
		MaxTraceLength = 20,
		IdleTimeMin = 1.5,
		IdleTimeMax = 3,
		DangerAvoidance = 0.9,  -- Alta probabilidad de huir
		HuntChance = 0.1,  -- Baja probabilidad de cazar
		Color = Color3.fromRGB(100, 200, 100),
		BodyColor = Color3.fromRGB(80, 160, 80),
		Name = "🐢"
	},
	[BehaviorType.MEDIUM] = {
		Speed = 16,  -- Más rápido
		MinTraceLength = 18,
		MaxTraceLength = 35,
		IdleTimeMin = 0.8,
		IdleTimeMax = 2,
		DangerAvoidance = 0.6,  -- Moderada probabilidad de huir
		HuntChance = 0.3,  -- Moderada probabilidad de cazar
		Color = Color3.fromRGB(200, 200, 100),
		BodyColor = Color3.fromRGB(180, 180, 80),
		Name = "🏃"
	},
	[BehaviorType.AGGRESSIVE] = {
		Speed = 20,  -- Muy rápido
		MinTraceLength = 30,
		MaxTraceLength = 55,
		IdleTimeMin = 0.3,
		IdleTimeMax = 1,
		DangerAvoidance = 0.3,  -- Baja probabilidad de huir
		HuntChance = 0.6,  -- Alta probabilidad de cazar
		Color = Color3.fromRGB(255, 100, 100),
		BodyColor = Color3.fromRGB(200, 60, 60),
		Name = "🔥"
	}
}

-- Crear nueva instancia de IA
function BotAI.new(bot, territoryManager, matchFolder)
	local self = setmetatable({}, BotAI)

	self.Bot = bot
	self.TerritoryManager = territoryManager
	self.MatchFolder = matchFolder
	self.State = AIState.IDLE
	self.Position = bot.Position or Vector3.new(0, 1, 0)
	self.TargetPosition = nil
	self.HomePosition = bot.Position or Vector3.new(0, 1, 0)

	-- Elegir comportamiento aleatorio
	local behaviors = {BehaviorType.SLOW, BehaviorType.MEDIUM, BehaviorType.AGGRESSIVE}
	self.Behavior = behaviors[math.random(1, #behaviors)]
	self.Config = BehaviorConfig[self.Behavior]

	self.Speed = self.Config.Speed

	-- Timers
	self.ThinkTimer = 0
	self.ThinkDelay = 0.2 + math.random() * 0.2  -- Piensa más rápido
	self.IdleTimer = 0
	self.MaxIdleTime = self.Config.IdleTimeMin + math.random() * (self.Config.IdleTimeMax - self.Config.IdleTimeMin)

	-- Trazado
	self.TracePoints = {}
	self.MaxTraceLength = self.Config.MinTraceLength + math.random(0, self.Config.MaxTraceLength - self.Config.MinTraceLength)
	self.TraceDistance = 0

	-- Waypoints para figuras complejas
	self.Waypoints = {}
	self.CurrentWaypointIndex = 1

	-- NUEVO: Detección de peligros
	self.LastDangerCheck = 0
	self.DangerCheckInterval = 0.3
	self.KnownEnemyLines = {}
	self.KnownBalls = {}

	-- NUEVO: Objetivos de caza
	self.HuntTarget = nil
	self.HuntTimeout = 0

	-- Cuerpo visual
	self.BodyModel = nil

	print("🤖", bot.Name, "creado con comportamiento:", self.Behavior, self.Config.Name)

	return self
end

-- Crear cuerpo visual del bot
function BotAI:CreateBody(color)
	if self.BodyModel then return end

	local model = Instance.new("Model")
	model.Name = self.Bot.Name .. "_Body"

	-- Torso principal
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2.5, 1)
	torso.Position = self.Position + Vector3.new(0, 2.25, 0)
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = color or self.Config.BodyColor
	torso.Parent = model

	-- Cabeza
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Position = self.Position + Vector3.new(0, 4, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(255, 220, 180)
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	-- Ojos
	local eyeL = Instance.new("Part")
	eyeL.Name = "EyeL"
	eyeL.Size = Vector3.new(0.3, 0.3, 0.1)
	eyeL.Position = self.Position + Vector3.new(-0.3, 4.1, 0.7)
	eyeL.Anchored = true
	eyeL.CanCollide = false
	eyeL.Material = Enum.Material.Neon
	eyeL.Color = Color3.fromRGB(0, 0, 0)
	eyeL.Parent = model

	local eyeR = eyeL:Clone()
	eyeR.Name = "EyeR"
	eyeR.Position = self.Position + Vector3.new(0.3, 4.1, 0.7)
	eyeR.Parent = model

	-- Piernas
	local legL = Instance.new("Part")
	legL.Name = "LegL"
	legL.Size = Vector3.new(0.8, 2, 0.8)
	legL.Position = self.Position + Vector3.new(-0.5, 0.5, 0)
	legL.Anchored = true
	legL.CanCollide = false
	legL.Material = Enum.Material.SmoothPlastic
	legL.Color = Color3.fromRGB(50, 50, 80)
	legL.Parent = model

	local legR = legL:Clone()
	legR.Name = "LegR"
	legR.Position = self.Position + Vector3.new(0.5, 0.5, 0)
	legR.Parent = model

	-- Brazos
	local armL = Instance.new("Part")
	armL.Name = "ArmL"
	armL.Size = Vector3.new(0.6, 2, 0.6)
	armL.Position = self.Position + Vector3.new(-1.3, 2.5, 0)
	armL.Anchored = true
	armL.CanCollide = false
	armL.Material = Enum.Material.SmoothPlastic
	armL.Color = color or self.Config.BodyColor
	armL.Parent = model

	local armR = armL:Clone()
	armR.Name = "ArmR"
	armR.Position = self.Position + Vector3.new(1.3, 2.5, 0)
	armR.Parent = model

	-- Indicador de comportamiento sobre la cabeza
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 60, 0, 35)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = self.Config.Name .. " " .. self.Bot.Name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	model.PrimaryPart = torso
	model.Parent = self.MatchFolder

	self.BodyModel = model
end

-- Actualizar posición del cuerpo visual
function BotAI:UpdateBodyPosition()
	if not self.BodyModel then return end

	local pos = self.Position
	local direction = Vector3.new(0, 0, 1)

	if self.TargetPosition then
		direction = (self.TargetPosition - pos)
		if direction.Magnitude > 0.1 then
			direction = direction.Unit
		else
			direction = Vector3.new(0, 0, 1)
		end
	end

	local lookCFrame = CFrame.lookAt(pos, pos + Vector3.new(direction.X, 0, direction.Z))

	local torso = self.BodyModel:FindFirstChild("Torso")
	if torso then torso.CFrame = lookCFrame * CFrame.new(0, 2.25, 0) end

	local head = self.BodyModel:FindFirstChild("Head")
	if head then head.CFrame = lookCFrame * CFrame.new(0, 4, 0) end

	local eyeL = self.BodyModel:FindFirstChild("EyeL")
	if eyeL then eyeL.CFrame = lookCFrame * CFrame.new(-0.3, 4.1, 0.7) end

	local eyeR = self.BodyModel:FindFirstChild("EyeR")
	if eyeR then eyeR.CFrame = lookCFrame * CFrame.new(0.3, 4.1, 0.7) end

	-- Animación de caminar más rápida cuando corre
	local speedMult = self.Speed / 14
	local walkSpeed = 8 * speedMult

	local legL = self.BodyModel:FindFirstChild("LegL")
	if legL then
		local walkOffset = math.sin(tick() * walkSpeed) * 0.4
		legL.CFrame = lookCFrame * CFrame.new(-0.5, 0.5, walkOffset)
	end

	local legR = self.BodyModel:FindFirstChild("LegR")
	if legR then
		local walkOffset = math.sin(tick() * walkSpeed + math.pi) * 0.4
		legR.CFrame = lookCFrame * CFrame.new(0.5, 0.5, walkOffset)
	end

	local armL = self.BodyModel:FindFirstChild("ArmL")
	if armL then
		local armSwing = math.sin(tick() * walkSpeed + math.pi) * 0.5
		armL.CFrame = lookCFrame * CFrame.new(-1.3, 2.5, armSwing)
	end

	local armR = self.BodyModel:FindFirstChild("ArmR")
	if armR then
		local armSwing = math.sin(tick() * walkSpeed) * 0.5
		armR.CFrame = lookCFrame * CFrame.new(1.3, 2.5, armSwing)
	end
end

-- Actualizar posición inicial
function BotAI:SetHomePosition(position)
	self.HomePosition = position
	self.Position = position
	self:UpdateBodyPosition()
end

-- Detectar peligros cercanos (bolas, líneas, territorio enemigo)
function BotAI:DetectDangers()
	local dangers = {}

	if not self.MatchFolder then return dangers end

	-- Buscar líneas activas de otros jugadores
	for _, part in ipairs(self.MatchFolder:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("IsActiveLine") then
			local ownerName = part:GetAttribute("OwnerName")
			if ownerName and ownerName ~= self.Bot.Name then
				local dist = (part.Position - self.Position).Magnitude
				if dist < 15 then
					table.insert(dangers, {
						type = "line",
						position = part.Position,
						distance = dist,
						owner = ownerName
					})
				end
			end
		end

		-- Detectar bolas con pinchos
		if part:IsA("BasePart") and (part.Name == "Ball" or part.Parent and part.Parent.Name == "SpikeBall") then
			local dist = (part.Position - self.Position).Magnitude
			if dist < 20 then
				table.insert(dangers, {
					type = "ball",
					position = part.Position,
					distance = dist
				})
			end
		end
	end

	-- NUEVO: Detectar territorio enemigo en la dirección de movimiento
	if self.TargetPosition and self.TerritoryManager then
		local direction = (self.TargetPosition - self.Position).Unit
		local checkDistance = 3 -- Verificar 3 studs adelante
		local futurePos = self.Position + direction * checkDistance

		local enemyOwner = self.TerritoryManager:GetTerritoryOwnerAt(futurePos)
		if enemyOwner and enemyOwner ~= self.Bot then
			table.insert(dangers, {
				type = "territory",
				position = futurePos,
				distance = checkDistance,
				owner = enemyOwner.Name
			})
		end
	end

	return dangers
end

-- Verificar si la posición objetivo es segura
function BotAI:IsPositionSafe(position)
	if not self.TerritoryManager then return true end

	local owner = self.TerritoryManager:GetTerritoryOwnerAt(position)
	if owner and owner ~= self.Bot then
		return false -- Territorio enemigo
	end
	return true
end

-- NUEVO: Buscar líneas enemigas para cortar
function BotAI:FindEnemyLineToCut()
	if not self.MatchFolder then return nil end

	local bestTarget = nil
	local bestScore = 0

	for _, part in ipairs(self.MatchFolder:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("IsActiveLine") then
			local ownerName = part:GetAttribute("OwnerName")
			if ownerName and ownerName ~= self.Bot.Name then
				local dist = (part.Position - self.Position).Magnitude

				-- Score basado en distancia (más cerca = mejor)
				local score = 100 - dist

				if score > bestScore and dist < 50 then
					bestScore = score
					bestTarget = {
						position = part.Position,
						owner = ownerName,
						distance = dist
					}
				end
			end
		end
	end

	return bestTarget
end

-- Actualizar IA
function BotAI:Update(deltaTime)
	self.ThinkTimer = self.ThinkTimer + deltaTime
	self.LastDangerCheck = self.LastDangerCheck + deltaTime

	-- Check de peligros periódico
	if self.LastDangerCheck >= self.DangerCheckInterval then
		self:CheckForDangers()
		self.LastDangerCheck = 0
	end

	if self.ThinkTimer >= self.ThinkDelay then
		self:Think()
		self.ThinkTimer = 0
	end

	self:ExecuteState(deltaTime)
	self:UpdateBodyPosition()
end

-- Verificar y reaccionar a peligros
function BotAI:CheckForDangers()
	if self.State == AIState.FLEEING then return end

	local dangers = self:DetectDangers()

	for _, danger in ipairs(dangers) do
		local shouldFlee = false

		if danger.type == "ball" and danger.distance < 12 then
			-- Huir de bolas con pinchos
			shouldFlee = math.random() < self.Config.DangerAvoidance

		elseif danger.type == "line" and danger.distance < 8 then
			-- Huir de líneas muy cercanas si estamos trazando
			if self.State == AIState.TRACING then
				shouldFlee = math.random() < self.Config.DangerAvoidance
			end

		elseif danger.type == "territory" then
			-- SIEMPRE evitar territorio enemigo (100% probabilidad)
			shouldFlee = true
		end

		if shouldFlee then
			self:Flee(danger.position)
			return
		end
	end
end

-- Buscar una dirección segura (sin territorio enemigo)
function BotAI:FindSafeDirection()
	local directions = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 1).Unit,
		Vector3.new(-1, 0, 1).Unit,
		Vector3.new(1, 0, -1).Unit,
		Vector3.new(-1, 0, -1).Unit,
	}

	local safeDirections = {}

	for _, dir in ipairs(directions) do
		local testPos = self.Position + dir * 5
		if self:IsPositionSafe(testPos) then
			table.insert(safeDirections, dir)
		end
	end

	if #safeDirections > 0 then
		return safeDirections[math.random(1, #safeDirections)]
	end

	-- Si no hay direcciones seguras, ir hacia casa
	return (self.HomePosition - self.Position).Unit
end

-- Proceso de pensamiento según comportamiento
function BotAI:Think()
	local isInSafe = self.TerritoryManager:IsInSafeZone(self.Bot, self.Position)

	if self.State == AIState.IDLE then
		self.IdleTimer = self.IdleTimer + self.ThinkDelay

		if self.IdleTimer >= self.MaxIdleTime then
			-- NUEVO: Decidir si cazar o trazar
			if math.random() < self.Config.HuntChance then
				local target = self:FindEnemyLineToCut()
				if target then
					self.HuntTarget = target
					self.HuntTimeout = 5  -- 5 segundos máximo cazando
					self.State = AIState.HUNTING
					self.TargetPosition = target.position
					return
				end
			end

			self.State = AIState.PLANNING
			self.IdleTimer = 0
		end

	elseif self.State == AIState.PLANNING then
		if isInSafe then
			self:PlanTrace()
		else
			self:PlanReturn()
		end

	elseif self.State == AIState.TRACING then
		if self.TraceDistance >= self.MaxTraceLength then
			self:PlanReturn()
		end

	elseif self.State == AIState.RETURNING then
		if isInSafe then
			self.State = AIState.IDLE
			self.TracePoints = {}
			self.TraceDistance = 0
			self.MaxTraceLength = self.Config.MinTraceLength + 
				math.random(0, self.Config.MaxTraceLength - self.Config.MinTraceLength)
			self.MaxIdleTime = self.Config.IdleTimeMin + 
				math.random() * (self.Config.IdleTimeMax - self.Config.IdleTimeMin)
		end

	elseif self.State == AIState.HUNTING then
		self.HuntTimeout = self.HuntTimeout - self.ThinkDelay
		if self.HuntTimeout <= 0 then
			-- Timeout, volver a casa
			self.HuntTarget = nil
			self:PlanReturn()
		elseif isInSafe then
			-- Llegamos a zona segura durante caza, recalcular
			self.HuntTarget = nil
			self.State = AIState.IDLE
		end

	elseif self.State == AIState.FLEEING then
		-- Después de huir, volver a casa
		if isInSafe then
			self.State = AIState.IDLE
		end
	end
end

-- Planificar trazado según comportamiento - FORMAS ESPECÍFICAS
function BotAI:PlanTrace()
	local mapSize = Config.MAP_SIZE
	local currentPos = self.Position
	local basePos = self.TerritoryManager.MapBasePosition or Vector3.new(0, 0, 0)

	-- Guardar puntos de waypoints para formas complejas
	self.Waypoints = {}
	local targetPos

	if self.Behavior == BehaviorType.SLOW then
		-- SLOW: Círculos pequeños y cuadrados pequeños (seguro y cauteloso)
		local patterns = {
			-- Cuadrado pequeño (4 puntos)
			function()
				local size = math.random(8, 12)
				local dir = math.random(1, 4)
				local offsets = {
					{Vector3.new(size, 0, 0), Vector3.new(size, 0, size), Vector3.new(0, 0, size)},
					{Vector3.new(-size, 0, 0), Vector3.new(-size, 0, size), Vector3.new(0, 0, size)},
					{Vector3.new(size, 0, 0), Vector3.new(size, 0, -size), Vector3.new(0, 0, -size)},
					{Vector3.new(-size, 0, 0), Vector3.new(-size, 0, -size), Vector3.new(0, 0, -size)},
				}
				self.Waypoints = {}
				for _, offset in ipairs(offsets[dir]) do
					table.insert(self.Waypoints, currentPos + offset)
				end
				return self.Waypoints[1]
			end,
			-- Semi-círculo pequeño
			function()
				local radius = math.random(8, 12)
				local startAngle = math.random() * math.pi * 2
				self.Waypoints = {}
				for i = 1, 4 do
					local angle = startAngle + (i / 4) * math.pi
					table.insert(self.Waypoints, currentPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
				end
				return self.Waypoints[1]
			end,
			-- Triángulo pequeño
			function()
				local size = math.random(8, 12)
				local angle = math.random() * math.pi * 2
				self.Waypoints = {
					currentPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * size,
					currentPos + Vector3.new(math.cos(angle + 2.1), 0, math.sin(angle + 2.1)) * size,
				}
				return self.Waypoints[1]
			end
		}
		targetPos = patterns[math.random(1, #patterns)]()

	elseif self.Behavior == BehaviorType.MEDIUM then
		-- MEDIUM: Formas de L, rectángulos, semi-círculos medianos
		local patterns = {
			-- Forma de L
			function()
				local len1 = math.random(15, 25)
				local len2 = math.random(12, 18)
				local dir = math.random(1, 4)
				local waypoints = {
					{Vector3.new(len1, 0, 0), Vector3.new(len1, 0, len2)},
					{Vector3.new(-len1, 0, 0), Vector3.new(-len1, 0, len2)},
					{Vector3.new(0, 0, len1), Vector3.new(len2, 0, len1)},
					{Vector3.new(0, 0, -len1), Vector3.new(len2, 0, -len1)},
				}
				self.Waypoints = {}
				for _, offset in ipairs(waypoints[dir]) do
					table.insert(self.Waypoints, currentPos + offset)
				end
				return self.Waypoints[1]
			end,
			-- Rectángulo mediano
			function()
				local width = math.random(12, 20)
				local height = math.random(18, 28)
				self.Waypoints = {
					currentPos + Vector3.new(width, 0, 0),
					currentPos + Vector3.new(width, 0, height),
					currentPos + Vector3.new(0, 0, height),
				}
				return self.Waypoints[1]
			end,
			-- Arco hacia el centro
			function()
				local toCenter = (basePos - currentPos)
				local dist = math.min(toCenter.Magnitude * 0.6, 30)
				if dist > 10 then
					local perpendicular = Vector3.new(-toCenter.Z, 0, toCenter.X).Unit
					self.Waypoints = {
						currentPos + toCenter.Unit * dist * 0.5 + perpendicular * 10,
						currentPos + toCenter.Unit * dist,
					}
					return self.Waypoints[1]
				else
					local angle = math.random() * math.pi * 2
					return currentPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 25
				end
			end
		}
		targetPos = patterns[math.random(1, #patterns)]()

	elseif self.Behavior == BehaviorType.AGGRESSIVE then
		-- AGGRESSIVE: Círculos grandes, conquistas largas hacia el centro
		local patterns = {
			-- Círculo grande (conquistar mucho territorio)
			function()
				local radius = math.random(25, 40)
				local startAngle = math.random() * math.pi * 2
				self.Waypoints = {}
				for i = 1, 6 do
					local angle = startAngle + (i / 6) * math.pi * 1.5
					table.insert(self.Waypoints, currentPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
				end
				return self.Waypoints[1]
			end,
			-- Conquista hacia el centro (línea larga + retorno)
			function()
				local toCenter = (basePos - currentPos)
				local dist = math.min(toCenter.Magnitude * 0.8, 45)
				if dist > 15 then
					self.Waypoints = {
						currentPos + toCenter.Unit * dist,
					}
					return self.Waypoints[1]
				else
					-- Ya cerca del centro, expandir en círculo
					local angle = math.random() * math.pi * 2
					local radius = math.random(30, 45)
					self.Waypoints = {}
					for i = 1, 4 do
						local a = angle + (i / 4) * math.pi * 1.5
						table.insert(self.Waypoints, currentPos + Vector3.new(math.cos(a), 0, math.sin(a)) * radius)
					end
					return self.Waypoints[1]
				end
			end,
			-- Zigzag agresivo (cubre mucho terreno)
			function()
				local length = math.random(35, 50)
				local width = math.random(15, 25)
				local dir = math.random(1, 2) == 1 and 1 or -1
				self.Waypoints = {
					currentPos + Vector3.new(length * 0.3, 0, width * dir),
					currentPos + Vector3.new(length * 0.6, 0, 0),
					currentPos + Vector3.new(length, 0, width * dir),
				}
				return self.Waypoints[1]
			end
		}
		targetPos = patterns[math.random(1, #patterns)]()
	end

	-- Limitar dentro del mapa
	local halfMap = mapSize / 2 - 10
	targetPos = Vector3.new(
		math.clamp(targetPos.X, basePos.X - halfMap, basePos.X + halfMap),
		self.Position.Y,
		math.clamp(targetPos.Z, basePos.Z - halfMap, basePos.Z + halfMap)
	)

	-- También limitar waypoints
	for i, wp in ipairs(self.Waypoints) do
		self.Waypoints[i] = Vector3.new(
			math.clamp(wp.X, basePos.X - halfMap, basePos.X + halfMap),
			self.Position.Y,
			math.clamp(wp.Z, basePos.Z - halfMap, basePos.Z + halfMap)
		)
	end

	-- VERIFICAR que el destino no sea territorio enemigo
	if not self:IsPositionSafe(targetPos) then
		local safeDir = self:FindSafeDirection()
		local safeDistance = math.random(self.Config.MinTraceLength, self.Config.MaxTraceLength)
		targetPos = self.Position + safeDir * safeDistance
		self.Waypoints = {} -- Cancelar waypoints si hay peligro

		targetPos = Vector3.new(
			math.clamp(targetPos.X, basePos.X - halfMap, basePos.X + halfMap),
			self.Position.Y,
			math.clamp(targetPos.Z, basePos.Z - halfMap, basePos.Z + halfMap)
		)
	end

	self.TargetPosition = targetPos
	self.CurrentWaypointIndex = 1
	self.State = AIState.TRACING
	self.TracePoints = {self.Position}
	self.TraceDistance = 0
end

-- Planificar retorno
function BotAI:PlanReturn()
	self.TargetPosition = self.HomePosition
	self.State = AIState.RETURNING
end

-- Ejecutar acción según estado
function BotAI:ExecuteState(deltaTime)
	if self.State == AIState.IDLE then
		-- Pequeños movimientos aleatorios
		if math.random() < 0.03 then
			local smallMove = Vector3.new(
				(math.random() - 0.5) * 0.3,
				0,
				(math.random() - 0.5) * 0.3
			)
			self.Position = self.Position + smallMove
		end

	elseif self.State == AIState.TRACING or self.State == AIState.RETURNING or 
		self.State == AIState.FLEEING or self.State == AIState.HUNTING then
		if self.TargetPosition then
			self:MoveTowards(self.TargetPosition, deltaTime)
		end
	end
end

-- Detectar bolas cercanas y calcular dirección de evasión
function BotAI:GetBallAvoidanceVector()
	if not self.MatchFolder then return nil end

	local avoidance = Vector3.new(0, 0, 0)
	local foundDanger = false

	for _, part in ipairs(self.MatchFolder:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Ball" or (part.Parent and part.Parent.Name == "SpikeBall")) then
			local ballPos = part.Position
			local toBall = ballPos - self.Position
			local dist = toBall.Magnitude

			-- Solo evitar bolas cercanas (< 15 studs)
			if dist < 15 and dist > 0.1 then
				-- Vector de evasión inversamente proporcional a la distancia
				local awayFromBall = -toBall.Unit * (15 - dist) / 15
				avoidance = avoidance + awayFromBall
				foundDanger = true
			end
		end
	end

	if foundDanger and avoidance.Magnitude > 0.1 then
		return avoidance.Unit
	end
	return nil
end

-- Moverse hacia un punto MEJORADO con evasión de bolas y waypoints
function BotAI:MoveTowards(targetPos, deltaTime)
	local currentPos = self.Position
	local direction = (targetPos - currentPos)
	local distance = direction.Magnitude

	-- Verificar si llegamos al waypoint actual (si estamos trazando con waypoints)
	if distance < 2 then
		if self.State == AIState.TRACING and self.Waypoints and #self.Waypoints > 0 then
			-- Pasar al siguiente waypoint
			self.CurrentWaypointIndex = (self.CurrentWaypointIndex or 1) + 1
			if self.CurrentWaypointIndex <= #self.Waypoints then
				self.TargetPosition = self.Waypoints[self.CurrentWaypointIndex]
				return -- Continuar con el siguiente waypoint
			else
				-- Terminamos todos los waypoints, volver a casa
				self.Waypoints = {}
				self:PlanReturn()
				return
			end
		elseif self.State == AIState.TRACING then
			self:PlanReturn()
		elseif self.State == AIState.RETURNING then
			self.State = AIState.IDLE
		elseif self.State == AIState.FLEEING then
			self.State = AIState.RETURNING
			self:PlanReturn()
		elseif self.State == AIState.HUNTING then
			self.HuntTarget = nil
			self:PlanReturn()
		end
		return
	end

	direction = direction.Unit

	-- EVASIÓN DE BOLAS: Mezclar dirección objetivo con evasión
	if self.State == AIState.TRACING then
		local ballAvoidance = self:GetBallAvoidanceVector()
		if ballAvoidance then
			-- Mezclar dirección objetivo con evasión (60% objetivo, 40% evasión)
			-- Bots más cautelosos evitan más
			local avoidWeight = 0.4
			if self.Behavior == BehaviorType.SLOW then
				avoidWeight = 0.7  -- Muy cauteloso
			elseif self.Behavior == BehaviorType.MEDIUM then
				avoidWeight = 0.5
			else -- AGGRESSIVE
				avoidWeight = 0.3  -- Menos cauteloso
			end

			direction = (direction * (1 - avoidWeight) + ballAvoidance * avoidWeight).Unit
		end
	end

	-- Velocidad variable según estado
	local currentSpeed = self.Speed
	if self.State == AIState.FLEEING then
		currentSpeed = self.Speed * 1.3
	elseif self.State == AIState.HUNTING then
		currentSpeed = self.Speed * 1.2
	end

	local moveDistance = math.min(currentSpeed * deltaTime, distance)
	local newPos = currentPos + direction * moveDistance
	newPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)

	-- VERIFICAR si la nueva posición es segura (no territorio enemigo)
	if not self:IsPositionSafe(newPos) then
		-- Si vamos a pisar territorio enemigo, cambiar dirección
		local safeDir = self:FindSafeDirection()
		if safeDir then
			newPos = currentPos + safeDir * moveDistance
			newPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)

			-- Si aún no es seguro, quedarse quieto
			if not self:IsPositionSafe(newPos) then
				self:PlanReturn() -- Volver a casa
				return
			end
		else
			self:PlanReturn()
			return
		end
	end

	self.Position = newPos

	if self.State == AIState.TRACING then
		self.TraceDistance = self.TraceDistance + moveDistance
		table.insert(self.TracePoints, newPos)
	end
end

-- Huir MEJORADO
function BotAI:Flee(dangerPosition)
	local direction = (self.Position - dangerPosition)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	end
	direction = direction.Unit

	-- Huir hacia zona segura si es posible
	local fleeDistance = 25
	local fleeTarget = self.Position + direction * fleeDistance

	-- Intentar huir hacia casa
	local toHome = (self.HomePosition - self.Position)
	if toHome.Magnitude > 5 then
		fleeTarget = self.Position + (direction + toHome.Unit * 0.5).Unit * fleeDistance
	end

	self.TargetPosition = fleeTarget
	self.State = AIState.FLEEING
	self.TracePoints = {}  -- Cancelar trazo actual
	self.TraceDistance = 0
end

-- Obtener posición
function BotAI:GetPosition()
	return self.Position
end

-- Obtener estado
function BotAI:GetState()
	return self.State
end

-- Obtener comportamiento
function BotAI:GetBehavior()
	return self.Behavior
end

-- Limpiar
function BotAI:Cleanup()
	if self.BodyModel then
		self.BodyModel:Destroy()
		self.BodyModel = nil
	end
end

return BotAI
