--[[
    BotAI.lua
    Inteligencia artificial AVANZADA para bots
    
    GRADOS DE AGRESIVIDAD (1-3):
    - Grado 1 (Cauteloso): Zonas pequeñas, muy atento a peligros
    - Grado 2 (Equilibrado): Zonas medianas, comportamiento balanceado
    - Grado 3 (Agresivo): Zonas grandes, arriesga mucho, muy activo
    
    MEJORAS v2.0:
    - Predicción de trayectoria de bolas
    - Siempre en movimiento (nunca parado)
    - Formas circulares para maximizar territorio
    - Nombres aleatorios realistas
    - Esquiva inteligente de bolas
]]

print("BotAI.lua v2.0 loaded")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local BotAI = {}
BotAI.__index = BotAI

-- Estados de IA
local AIState = {
	MOVING = "Moving",           -- Siempre moviéndose en zona segura
	TRACING = "Tracing",         -- Dibujando figura fuera de zona
	RETURNING = "Returning",     -- Volviendo a zona segura (urgente)
	EVADING = "Evading",         -- Esquivando bola activamente
}

-- Lista de 100 nombres aleatorios para bots
local BOT_NAMES = {
	"Alex", "Max", "Sam", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn", "Avery",
	"Blake", "Drew", "Sage", "Phoenix", "River", "Sky", "Storm", "Blaze", "Frost", "Shadow",
	"Nova", "Luna", "Star", "Ace", "King", "Duke", "Prince", "Knight", "Ninja", "Titan",
	"Zeus", "Thor", "Odin", "Loki", "Atlas", "Apollo", "Mars", "Neo", "Axel", "Rex",
	"Cody", "Jake", "Kyle", "Ryan", "Mike", "Nick", "Josh", "Luke", "Evan", "Cole",
	"Leo", "Kai", "Zack", "Troy", "Brad", "Chad", "Seth", "Dean", "Kurt", "Brock",
	"Dash", "Finn", "Jett", "Knox", "Milo", "Nash", "Owen", "Zane", "Cruz", "Gage",
	"Epic", "Pro", "Ultra", "Mega", "Super", "Hyper", "Turbo", "Nitro", "Alpha", "Beta",
	"Omega", "Delta", "Sigma", "Gamma", "Viper", "Cobra", "Hawk", "Wolf", "Bear", "Lion",
	"Tiger", "Eagle", "Shark", "Dragon", "Rocket", "Laser", "Plasma", "Cyber", "Pixel", "Neon"
}

-- Configuración por grado de agresividad (1-3)
local GradeConfig = {
	[1] = { -- Cauteloso
		Speed = 14,
		CircleRadius = {8, 15},      -- Radio de círculos pequeños
		IdleMovementRadius = 3,      -- Se mueve poco en zona segura
		TimeBetweenTraces = {2, 4},  -- Espera más entre trazos
		DangerReactionDistance = 25, -- Reacciona desde lejos
		BallPredictionTime = 1.5,    -- Predice bolas 1.5 segundos
		ReturnThreshold = 0.7,       -- Vuelve cuando hizo 70% del trazo
		Color = Color3.fromRGB(100, 200, 100),
		BodyColor = Color3.fromRGB(80, 160, 80),
		Icon = "🐢"
	},
	[2] = { -- Equilibrado
		Speed = 18,
		CircleRadius = {15, 28},
		IdleMovementRadius = 5,
		TimeBetweenTraces = {1, 2.5},
		DangerReactionDistance = 18,
		BallPredictionTime = 1.0,
		ReturnThreshold = 0.85,
		Color = Color3.fromRGB(200, 200, 100),
		BodyColor = Color3.fromRGB(180, 180, 80),
		Icon = "🏃"
	},
	[3] = { -- Agresivo
		Speed = 22,
		CircleRadius = {25, 45},
		IdleMovementRadius = 8,
		TimeBetweenTraces = {0.3, 1},
		DangerReactionDistance = 12,
		BallPredictionTime = 0.6,
		ReturnThreshold = 0.95,
		Color = Color3.fromRGB(255, 100, 100),
		BodyColor = Color3.fromRGB(200, 60, 60),
		Icon = "🔥"
	}
}

-- Generar nombre aleatorio único
local usedNames = {}
local function GenerateRandomName()
	local baseName = BOT_NAMES[math.random(1, #BOT_NAMES)]
	local number = math.random(1, 999)
	local fullName = baseName .. number
	
	-- Asegurar que sea único
	local attempts = 0
	while usedNames[fullName] and attempts < 50 do
		baseName = BOT_NAMES[math.random(1, #BOT_NAMES)]
		number = math.random(1, 999)
		fullName = baseName .. number
		attempts = attempts + 1
	end
	
	usedNames[fullName] = true
	return fullName
end

-- Crear nueva instancia de IA
function BotAI.new(bot, territoryManager, matchFolder)
	local self = setmetatable({}, BotAI)

	self.Bot = bot
	self.TerritoryManager = territoryManager
	self.MatchFolder = matchFolder
	self.State = AIState.MOVING
	self.Position = bot.Position or Vector3.new(0, 1, 0)
	self.TargetPosition = nil
	self.HomePosition = bot.Position or Vector3.new(0, 1, 0)

	-- Asignar grado aleatorio (1-3)
	self.Grade = math.random(1, 3)
	self.Config = GradeConfig[self.Grade]
	self.Speed = self.Config.Speed
	
	-- Nombre aleatorio
	self.DisplayName = GenerateRandomName()
	bot.Name = self.DisplayName -- Actualizar nombre del bot

	-- Timers
	self.ThinkTimer = 0
	self.ThinkDelay = 0.1  -- Piensa muy rápido
	self.TraceTimer = 0
	self.NextTraceTime = self.Config.TimeBetweenTraces[1] + 
		math.random() * (self.Config.TimeBetweenTraces[2] - self.Config.TimeBetweenTraces[1])

	-- Trazado
	self.TracePoints = {}
	self.TraceDistance = 0
	self.MaxTraceDistance = 0
	
	-- Waypoints para círculos
	self.Waypoints = {}
	self.CurrentWaypointIndex = 1
	
	-- Movimiento en zona segura
	self.SafeMovementTarget = nil
	self.SafeMovementTimer = 0

	-- Detección de peligros
	self.LastBallCheck = 0
	self.BallCheckInterval = 0.15  -- Chequea bolas muy frecuentemente
	self.DangerousBall = nil

	-- Cuerpo visual
	self.BodyModel = nil

	print("🤖", self.DisplayName, "creado - Grado", self.Grade, self.Config.Icon)

	return self
end

-- Crear cuerpo visual del bot
function BotAI:CreateBody(color)
	if self.BodyModel then return end

	local model = Instance.new("Model")
	model.Name = self.DisplayName .. "_Body"

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

	-- Indicador de nombre sobre la cabeza
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = self.Config.Icon .. " " .. self.DisplayName
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

	-- Animación de caminar (siempre activa)
	local speedMult = self.Speed / 14
	local walkSpeed = 10 * speedMult

	local legL = self.BodyModel:FindFirstChild("LegL")
	if legL then
		local walkOffset = math.sin(tick() * walkSpeed) * 0.5
		legL.CFrame = lookCFrame * CFrame.new(-0.5, 0.5, walkOffset)
	end

	local legR = self.BodyModel:FindFirstChild("LegR")
	if legR then
		local walkOffset = math.sin(tick() * walkSpeed + math.pi) * 0.5
		legR.CFrame = lookCFrame * CFrame.new(0.5, 0.5, walkOffset)
	end

	local armL = self.BodyModel:FindFirstChild("ArmL")
	if armL then
		local armSwing = math.sin(tick() * walkSpeed + math.pi) * 0.6
		armL.CFrame = lookCFrame * CFrame.new(-1.3, 2.5, armSwing)
	end

	local armR = self.BodyModel:FindFirstChild("ArmR")
	if armR then
		local armSwing = math.sin(tick() * walkSpeed) * 0.6
		armR.CFrame = lookCFrame * CFrame.new(1.3, 2.5, armSwing)
	end
end

-- Actualizar posición inicial
function BotAI:SetHomePosition(position)
	self.HomePosition = position
	self.Position = position
	self:UpdateBodyPosition()
end

-- PREDICCIÓN DE BOLAS: Calcular si una bola va hacia el bot
function BotAI:PredictBallCollision()
	if not self.MatchFolder then return nil end

	local dangerousBall = nil
	local closestTime = math.huge

	for _, part in ipairs(self.MatchFolder:GetDescendants()) do
		-- Detectar bolas (pueden ser Part con nombre Ball o dentro de SpikeBall)
		local isBall = part:IsA("BasePart") and (
			part.Name == "Ball" or 
			part.Name == "Core" or
			(part.Parent and part.Parent.Name == "SpikeBall")
		)
		
		if isBall then
			local ballPos = part.Position
			local ballVel = Vector3.new(0, 0, 0)
			
			-- Intentar obtener velocidad si tiene BodyVelocity o está en movimiento
			local bodyVel = part:FindFirstChildOfClass("BodyVelocity")
			if bodyVel then
				ballVel = bodyVel.Velocity
			else
				-- Intentar obtener de atributo o AssemblyLinearVelocity
				ballVel = part.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
			end
			
			-- Solo considerar bolas en movimiento
			if ballVel.Magnitude > 1 then
				local toBot = self.Position - ballPos
				local ballDir = ballVel.Unit
				
				-- Proyectar para ver si viene hacia nosotros
				local dotProduct = toBot:Dot(ballDir)
				
				if dotProduct > 0 then -- La bola viene hacia nosotros
					-- Calcular punto más cercano en la trayectoria
					local closestPoint = ballPos + ballDir * dotProduct
					local distToTrajectory = (self.Position - closestPoint).Magnitude
					
					-- Si pasará cerca de nosotros
					if distToTrajectory < 8 then  -- Radio de peligro
						local timeToReach = dotProduct / ballVel.Magnitude
						
						-- Solo preocuparse por bolas que llegarán pronto
						if timeToReach < self.Config.BallPredictionTime and timeToReach < closestTime then
							closestTime = timeToReach
							dangerousBall = {
								part = part,
								position = ballPos,
								velocity = ballVel,
								timeToImpact = timeToReach,
								impactPoint = closestPoint
							}
						end
					end
				end
			end
			
			-- También detectar bolas cercanas aunque no se muevan hacia nosotros
			local dist = (ballPos - self.Position).Magnitude
			if dist < self.Config.DangerReactionDistance then
				if not dangerousBall or dist < (dangerousBall.position - self.Position).Magnitude then
					dangerousBall = {
						part = part,
						position = ballPos,
						velocity = ballVel,
						timeToImpact = dist / math.max(ballVel.Magnitude, 10),
						impactPoint = self.Position
					}
				end
			end
		end
	end

	return dangerousBall
end

-- Verificar si estamos en zona segura
function BotAI:IsInSafeZone()
	if not self.TerritoryManager then return true end
	return self.TerritoryManager:IsInSafeZone(self.Bot, self.Position)
end

-- Calcular dirección de evasión óptima
function BotAI:CalculateEvadeDirection(ballInfo)
	local toBall = ballInfo.position - self.Position
	local perpendicular = Vector3.new(-toBall.Z, 0, toBall.X).Unit
	
	-- Elegir dirección que nos aleje de la bola Y nos acerque a casa
	local toHome = (self.HomePosition - self.Position)
	if toHome.Magnitude > 0.1 then
		toHome = toHome.Unit
	else
		toHome = Vector3.new(0, 0, 0)
	end
	
	-- Probar ambas direcciones perpendiculares
	local option1 = (perpendicular + toHome * 0.3).Unit
	local option2 = (-perpendicular + toHome * 0.3).Unit
	
	-- Elegir la que nos aleje más de la bola
	local dist1 = ((self.Position + option1 * 10) - ballInfo.position).Magnitude
	local dist2 = ((self.Position + option2 * 10) - ballInfo.position).Magnitude
	
	return dist1 > dist2 and option1 or option2
end

-- Planificar un círculo para capturar territorio
function BotAI:PlanCircleTrace()
	local mapSize = Config.MAP_SIZE
	local basePos = self.TerritoryManager and self.TerritoryManager.MapBasePosition or Vector3.new(0, 0, 0)
	local halfMap = mapSize / 2 - 15
	
	-- Radio según grado de agresividad
	local minR, maxR = self.Config.CircleRadius[1], self.Config.CircleRadius[2]
	local radius = minR + math.random() * (maxR - minR)
	
	-- Dirección aleatoria para el círculo
	local startAngle = math.random() * math.pi * 2
	
	-- Crear waypoints para un círculo (o semi-círculo para grado 1)
	self.Waypoints = {}
	local segments = self.Grade == 1 and 4 or (self.Grade == 2 and 6 or 8)
	local arcLength = self.Grade == 1 and math.pi or (self.Grade == 2 and math.pi * 1.3 or math.pi * 1.6)
	
	for i = 1, segments do
		local angle = startAngle + (i / segments) * arcLength
		local point = self.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		
		-- Limitar dentro del mapa
		point = Vector3.new(
			math.clamp(point.X, basePos.X - halfMap, basePos.X + halfMap),
			self.Position.Y,
			math.clamp(point.Z, basePos.Z - halfMap, basePos.Z + halfMap)
		)
		
		table.insert(self.Waypoints, point)
	end
	
	if #self.Waypoints > 0 then
		self.CurrentWaypointIndex = 1
		self.TargetPosition = self.Waypoints[1]
		self.State = AIState.TRACING
		self.TracePoints = {self.Position}
		self.TraceDistance = 0
		self.MaxTraceDistance = radius * arcLength  -- Longitud aproximada del arco
	end
end

-- Actualizar IA
function BotAI:Update(deltaTime)
	self.ThinkTimer = self.ThinkTimer + deltaTime
	self.LastBallCheck = self.LastBallCheck + deltaTime
	self.TraceTimer = self.TraceTimer + deltaTime
	self.SafeMovementTimer = self.SafeMovementTimer + deltaTime

	-- Chequeo frecuente de bolas peligrosas
	if self.LastBallCheck >= self.BallCheckInterval then
		self.DangerousBall = self:PredictBallCollision()
		self.LastBallCheck = 0
		
		-- Si hay bola peligrosa y estamos trazando, volver INMEDIATAMENTE
		if self.DangerousBall and self.State == AIState.TRACING then
			self.State = AIState.RETURNING
			self.TargetPosition = self.HomePosition
			self.Waypoints = {}
		end
	end

	if self.ThinkTimer >= self.ThinkDelay then
		self:Think()
		self.ThinkTimer = 0
	end

	self:ExecuteMovement(deltaTime)
	self:UpdateBodyPosition()
end

-- Proceso de pensamiento
function BotAI:Think()
	local isInSafe = self:IsInSafeZone()

	if self.State == AIState.MOVING then
		-- En zona segura, moverse aleatoriamente y esperar para trazar
		if self.TraceTimer >= self.NextTraceTime then
			-- Verificar que no hay bolas peligrosas antes de salir
			if not self.DangerousBall then
				self:PlanCircleTrace()
				self.TraceTimer = 0
				self.NextTraceTime = self.Config.TimeBetweenTraces[1] + 
					math.random() * (self.Config.TimeBetweenTraces[2] - self.Config.TimeBetweenTraces[1])
			end
		end
		
	elseif self.State == AIState.TRACING then
		-- Verificar si debemos volver (por distancia o peligro)
		local shouldReturn = false
		
		if self.MaxTraceDistance > 0 then
			local progress = self.TraceDistance / self.MaxTraceDistance
			if progress >= self.Config.ReturnThreshold then
				shouldReturn = true
			end
		end
		
		-- Terminamos los waypoints
		if self.CurrentWaypointIndex > #self.Waypoints then
			shouldReturn = true
		end
		
		if shouldReturn then
			self.State = AIState.RETURNING
			self.TargetPosition = self.HomePosition
			self.Waypoints = {}
		end
		
	elseif self.State == AIState.RETURNING then
		if isInSafe then
			self.State = AIState.MOVING
			self.TracePoints = {}
			self.TraceDistance = 0
			self.SafeMovementTarget = nil
		end
		
	elseif self.State == AIState.EVADING then
		-- Después de evadir, volver a casa
		if isInSafe then
			self.State = AIState.MOVING
		elseif not self.DangerousBall then
			self.State = AIState.RETURNING
			self.TargetPosition = self.HomePosition
		end
	end
end

-- Ejecutar movimiento (NUNCA estar parado)
function BotAI:ExecuteMovement(deltaTime)
	local currentSpeed = self.Speed
	
	-- Velocidad extra cuando hay peligro
	if self.DangerousBall then
		currentSpeed = self.Speed * 1.4
	end
	
	if self.State == AIState.MOVING then
		-- SIEMPRE moverse en zona segura (pequeños círculos)
		if not self.SafeMovementTarget or self.SafeMovementTimer > 1.5 or 
		   (self.SafeMovementTarget - self.Position).Magnitude < 1 then
			-- Nuevo objetivo de movimiento dentro de la zona segura
			local radius = self.Config.IdleMovementRadius
			local angle = math.random() * math.pi * 2
			self.SafeMovementTarget = self.HomePosition + Vector3.new(
				math.cos(angle) * radius,
				0,
				math.sin(angle) * radius
			)
			self.SafeMovementTimer = 0
		end
		
		self:MoveTowards(self.SafeMovementTarget, deltaTime, currentSpeed * 0.6)
		
	elseif self.State == AIState.TRACING then
		if self.TargetPosition then
			-- Si hay bola peligrosa, esquivar mientras trazamos
			if self.DangerousBall then
				local evadeDir = self:CalculateEvadeDirection(self.DangerousBall)
				local evadeTarget = self.Position + evadeDir * 10
				self:MoveTowards(evadeTarget, deltaTime, currentSpeed)
			else
				self:MoveTowards(self.TargetPosition, deltaTime, currentSpeed)
			end
			
			-- Verificar si llegamos al waypoint actual
			if (self.TargetPosition - self.Position).Magnitude < 2 then
				self.CurrentWaypointIndex = self.CurrentWaypointIndex + 1
				if self.CurrentWaypointIndex <= #self.Waypoints then
					self.TargetPosition = self.Waypoints[self.CurrentWaypointIndex]
				end
			end
		end
		
	elseif self.State == AIState.RETURNING then
		-- Volver a casa lo más rápido posible
		if self.DangerousBall then
			-- Esquivar mientras volvemos
			local evadeDir = self:CalculateEvadeDirection(self.DangerousBall)
			local toHome = (self.HomePosition - self.Position).Unit
			local combinedDir = (toHome * 0.6 + evadeDir * 0.4).Unit
			local target = self.Position + combinedDir * 10
			self:MoveTowards(target, deltaTime, currentSpeed * 1.2)
		else
			self:MoveTowards(self.HomePosition, deltaTime, currentSpeed * 1.1)
		end
		
	elseif self.State == AIState.EVADING then
		if self.DangerousBall then
			local evadeDir = self:CalculateEvadeDirection(self.DangerousBall)
			local target = self.Position + evadeDir * 15
			self:MoveTowards(target, deltaTime, currentSpeed * 1.3)
		else
			self:MoveTowards(self.HomePosition, deltaTime, currentSpeed)
		end
	end
end

-- Moverse hacia un punto
function BotAI:MoveTowards(targetPos, deltaTime, speed)
	local currentPos = self.Position
	local direction = (targetPos - currentPos)
	local distance = direction.Magnitude

	if distance < 0.5 then
		return
	end

	direction = direction.Unit
	local moveDistance = math.min(speed * deltaTime, distance)
	local newPos = currentPos + direction * moveDistance
	newPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)

	-- Limitar dentro del mapa
	local mapSize = Config.MAP_SIZE
	local basePos = self.TerritoryManager and self.TerritoryManager.MapBasePosition or Vector3.new(0, 0, 0)
	local halfMap = mapSize / 2 - 3
	
	newPos = Vector3.new(
		math.clamp(newPos.X, basePos.X - halfMap, basePos.X + halfMap),
		newPos.Y,
		math.clamp(newPos.Z, basePos.Z - halfMap, basePos.Z + halfMap)
	)

	self.Position = newPos
	self.TargetPosition = targetPos

	if self.State == AIState.TRACING then
		self.TraceDistance = self.TraceDistance + moveDistance
		table.insert(self.TracePoints, newPos)
	end
end

-- Obtener posición
function BotAI:GetPosition()
	return self.Position
end

-- Obtener estado
function BotAI:GetState()
	return self.State
end

-- Obtener grado
function BotAI:GetGrade()
	return self.Grade
end

-- Obtener comportamiento (compatibilidad)
function BotAI:GetBehavior()
	if self.Grade == 1 then return "Slow"
	elseif self.Grade == 2 then return "Medium"
	else return "Aggressive"
	end
end

-- Limpiar
function BotAI:Cleanup()
	if self.BodyModel then
		self.BodyModel:Destroy()
		self.BodyModel = nil
	end
	-- Liberar nombre usado
	if self.DisplayName then
		usedNames[self.DisplayName] = nil
	end
end

return BotAI
