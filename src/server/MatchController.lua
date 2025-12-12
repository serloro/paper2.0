--[[
    MatchController.lua
    Controlador principal de partidas
    
    Métodos de UI para jugadores:
    - InitializePlayerUI(player): Inicializa UI cuando entra a partida
    - FinalizePlayerUI(player): Finaliza UI cuando sale de partida
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Cargar módulos
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local MatchManager = require(ReplicatedStorage:WaitForChild("MatchManager"))
local TerritoryManager = require(ReplicatedStorage:WaitForChild("TerritoryManager"))
local BallPhysics = require(ReplicatedStorage:WaitForChild("BallPhysics"))
local DataManager = require(ReplicatedStorage:WaitForChild("DataManager"))
local BotAI = require(ReplicatedStorage:WaitForChild("BotAI"))

local MatchController = {}
MatchController.__index = MatchController

-- Referencias
local MatchesFolder = workspace:FindFirstChild("Matches") or Instance.new("Folder", workspace)
MatchesFolder.Name = "Matches"

-- Almacenar controladores de partidas activas
local ActiveMatchControllers = {} -- {[matchId] = controller}

-- Contador de mapas para posicionarlos en diferentes lugares
local MapPositionCounter = 0

-- Crear controlador para una partida
function MatchController.new(match)
	local self = setmetatable({}, MatchController)

	self.Match = match
	self.MatchFolder = nil
	self.TerritoryManager = nil
	self.Balls = {}
	self.PlayerCharacters = {} -- {[player] = character}
	self.PlayerStates = {} -- {[player] = {isTracing, lastSafePosition, etc}}
	self.SpawnPositions = {}
	self.BotAIs = {} -- {[bot] = BotAI instance}

	-- Temporizador de partida
	self.MatchDuration = Config.MATCH_DURATION or 60
	self.TimeRemaining = self.MatchDuration
	self.MatchStarted = false
	self.MatchEnded = false
	self.IsRunning = false

	-- Posición base del mapa (lejos del lobby, cada partida en lugar diferente)
	MapPositionCounter = MapPositionCounter + 1
	local mapOffset = 1000 + (MapPositionCounter * 500)  -- Cada mapa a 500 studs de distancia
	self.MapBasePosition = Vector3.new(mapOffset, 0, 0)

	-- Crear carpeta de la partida
	self:CreateMatchFolder()

	-- Crear mapa
	self:CreateMap()

	-- Inicializar TerritoryManager con la posición base del mapa
	self.TerritoryManager = TerritoryManager.new(self.MatchFolder, self.MapBasePosition)

	-- Registrar controlador
	ActiveMatchControllers[match.MatchId] = self

	return self
end

-- Crear carpeta de la partida
function MatchController:CreateMatchFolder()
	local folder = Instance.new("Folder")
	folder.Name = "Match_" .. self.Match.MatchId
	folder.Parent = MatchesFolder

	self.MatchFolder = folder
end

-- Definición de mapas
local MAP_THEMES = {
	{
		Name = "Industrial",
		FloorColor = Color3.fromRGB(80, 80, 80),
		FloorMaterial = Enum.Material.Concrete,
		WallColor = Color3.fromRGB(60, 60, 70),
		WallMaterial = Enum.Material.Metal,
		Ambient = Color3.fromRGB(150, 150, 160),
		Decorations = "industrial"
	},
	{
		Name = "Neon City",
		FloorColor = Color3.fromRGB(20, 20, 30),
		FloorMaterial = Enum.Material.SmoothPlastic,
		WallColor = Color3.fromRGB(50, 0, 80),
		WallMaterial = Enum.Material.Neon,
		Ambient = Color3.fromRGB(100, 50, 150),
		Decorations = "neon"
	},
	{
		Name = "Bosque",
		FloorColor = Color3.fromRGB(60, 100, 50),
		FloorMaterial = Enum.Material.Grass,
		WallColor = Color3.fromRGB(80, 60, 40),
		WallMaterial = Enum.Material.Wood,
		Ambient = Color3.fromRGB(120, 180, 100),
		Decorations = "forest"
	},
	{
		Name = "Desierto",
		FloorColor = Color3.fromRGB(200, 170, 120),
		FloorMaterial = Enum.Material.Sand,
		WallColor = Color3.fromRGB(180, 140, 90),
		WallMaterial = Enum.Material.Sandstone,
		Ambient = Color3.fromRGB(255, 220, 150),
		Decorations = "desert"
	},
	{
		Name = "Ártico",
		FloorColor = Color3.fromRGB(220, 230, 255),
		FloorMaterial = Enum.Material.Ice,
		WallColor = Color3.fromRGB(180, 200, 230),
		WallMaterial = Enum.Material.Glacier,
		Ambient = Color3.fromRGB(200, 220, 255),
		Decorations = "ice"
	},
	{
		Name = "Volcán",
		FloorColor = Color3.fromRGB(40, 30, 30),
		FloorMaterial = Enum.Material.Basalt,
		WallColor = Color3.fromRGB(80, 30, 20),
		WallMaterial = Enum.Material.CrackedLava,
		Ambient = Color3.fromRGB(255, 100, 50),
		Decorations = "lava"
	}
}

-- Crear el mapa de juego
function MatchController:CreateMap()
	local mapSize = Config.MAP_SIZE
	local basePos = self.MapBasePosition

	-- Seleccionar tema aleatorio
	local themeIndex = math.random(1, #MAP_THEMES)
	local theme = MAP_THEMES[themeIndex]
	self.MapTheme = theme

	print("🗺️ Mapa seleccionado:", theme.Name, "en posición", basePos)

	-- Suelo base
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(mapSize, 1, mapSize)
	floor.Position = basePos + Vector3.new(0, 0, 0)
	floor.Anchored = true
	floor.Material = theme.FloorMaterial
	floor.Color = theme.FloorColor
	floor.Parent = self.MatchFolder

	-- Paredes delimitadoras
	local wallHeight = 20
	local wallThickness = 2

	-- Pared Norte
	local wallNorth = Instance.new("Part")
	wallNorth.Name = "WallNorth"
	wallNorth.Size = Vector3.new(mapSize + wallThickness * 2, wallHeight, wallThickness)
	wallNorth.Position = basePos + Vector3.new(0, wallHeight/2, -mapSize/2 - wallThickness/2)
	wallNorth.Anchored = true
	wallNorth.Material = theme.WallMaterial
	wallNorth.Color = theme.WallColor
	wallNorth.Parent = self.MatchFolder

	-- Pared Sur
	local wallSouth = wallNorth:Clone()
	wallSouth.Name = "WallSouth"
	wallSouth.Position = basePos + Vector3.new(0, wallHeight/2, mapSize/2 + wallThickness/2)
	wallSouth.Parent = self.MatchFolder

	-- Pared Este
	local wallEast = Instance.new("Part")
	wallEast.Name = "WallEast"
	wallEast.Size = Vector3.new(wallThickness, wallHeight, mapSize)
	wallEast.Position = basePos + Vector3.new(mapSize/2 + wallThickness/2, wallHeight/2, 0)
	wallEast.Anchored = true
	wallEast.Material = theme.WallMaterial
	wallEast.Color = theme.WallColor
	wallEast.Parent = self.MatchFolder

	-- Pared Oeste
	local wallWest = wallEast:Clone()
	wallWest.Name = "WallWest"
	wallWest.Position = basePos + Vector3.new(-mapSize/2 - wallThickness/2, wallHeight/2, 0)
	wallWest.Parent = self.MatchFolder

	-- Añadir decoraciones según el tema
	self:AddMapDecorations(theme)

	-- Calcular posiciones de spawn en círculo
	local numPlayers = Config.MAX_PLAYERS_PER_MATCH
	local spawnRadius = mapSize * 0.35

	for i = 1, numPlayers do
		local angle = (i - 1) * (2 * math.pi / numPlayers)
		local x = math.cos(angle) * spawnRadius
		local z = math.sin(angle) * spawnRadius

		table.insert(self.SpawnPositions, basePos + Vector3.new(x, 5, z))
	end
end

-- Añadir decoraciones según el tema
function MatchController:AddMapDecorations(theme)
	local mapSize = Config.MAP_SIZE
	local basePos = self.MapBasePosition

	if theme.Decorations == "neon" then
		-- Luces neón en las esquinas
		local positions = {
			basePos + Vector3.new(mapSize/3, 10, mapSize/3),
			basePos + Vector3.new(-mapSize/3, 10, mapSize/3),
			basePos + Vector3.new(mapSize/3, 10, -mapSize/3),
			basePos + Vector3.new(-mapSize/3, 10, -mapSize/3),
		}
		local colors = {
			Color3.fromRGB(255, 0, 100),
			Color3.fromRGB(0, 255, 200),
			Color3.fromRGB(100, 0, 255),
			Color3.fromRGB(255, 200, 0),
		}
		for i, pos in ipairs(positions) do
			local light = Instance.new("Part")
			light.Name = "NeonLight" .. i
			light.Size = Vector3.new(3, 15, 3)
			light.Position = pos
			light.Anchored = true
			light.CanCollide = false
			light.Material = Enum.Material.Neon
			light.Color = colors[i]
			light.Parent = self.MatchFolder

			local pointLight = Instance.new("PointLight")
			pointLight.Color = colors[i]
			pointLight.Brightness = 2
			pointLight.Range = 40
			pointLight.Parent = light
		end

	elseif theme.Decorations == "forest" then
		-- Árboles decorativos (columnas verdes en las esquinas)
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local x = math.cos(angle) * (mapSize * 0.45)
			local z = math.sin(angle) * (mapSize * 0.45)

			local tree = Instance.new("Part")
			tree.Name = "Tree" .. i
			tree.Size = Vector3.new(4, 20, 4)
			tree.Position = basePos + Vector3.new(x, 10, z)
			tree.Anchored = true
			tree.CanCollide = true
			tree.Material = Enum.Material.Wood
			tree.Color = Color3.fromRGB(100, 70, 40)
			tree.Parent = self.MatchFolder

			local leaves = Instance.new("Part")
			leaves.Name = "Leaves" .. i
			leaves.Size = Vector3.new(10, 10, 10)
			leaves.Position = basePos + Vector3.new(x, 22, z)
			leaves.Anchored = true
			leaves.CanCollide = false
			leaves.Material = Enum.Material.Grass
			leaves.Color = Color3.fromRGB(50, 150, 50)
			leaves.Shape = Enum.PartType.Ball
			leaves.Parent = self.MatchFolder
		end

	elseif theme.Decorations == "lava" then
		-- Charcos de lava decorativos
		for i = 1, 6 do
			local x = math.random(-mapSize/3, mapSize/3)
			local z = math.random(-mapSize/3, mapSize/3)

			local lavaPool = Instance.new("Part")
			lavaPool.Name = "LavaPool" .. i
			lavaPool.Size = Vector3.new(math.random(5, 15), 0.5, math.random(5, 15))
			lavaPool.Position = basePos + Vector3.new(x, 0.8, z)
			lavaPool.Anchored = true
			lavaPool.CanCollide = false
			lavaPool.Material = Enum.Material.Neon
			lavaPool.Color = Color3.fromRGB(255, math.random(50, 150), 0)
			lavaPool.Parent = self.MatchFolder

			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 100, 0)
			light.Brightness = 1
			light.Range = 15
			light.Parent = lavaPool
		end

	elseif theme.Decorations == "ice" then
		-- Cristales de hielo
		for i = 1, 10 do
			local angle = math.random() * math.pi * 2
			local dist = math.random(mapSize/4, mapSize/2.5)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist

			local crystal = Instance.new("Part")
			crystal.Name = "IceCrystal" .. i
			crystal.Size = Vector3.new(3, math.random(8, 15), 3)
			crystal.Position = basePos + Vector3.new(x, crystal.Size.Y/2, z)
			crystal.Anchored = true
			crystal.CanCollide = true
			crystal.Material = Enum.Material.Glass
			crystal.Color = Color3.fromRGB(180, 220, 255)
			crystal.Transparency = 0.3
			crystal.Parent = self.MatchFolder
		end

	elseif theme.Decorations == "desert" then
		-- Rocas del desierto
		for i = 1, 8 do
			local angle = math.random() * math.pi * 2
			local dist = math.random(mapSize/4, mapSize/2.5)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist

			local rock = Instance.new("Part")
			rock.Name = "Rock" .. i
			rock.Size = Vector3.new(math.random(5, 12), math.random(3, 8), math.random(5, 12))
			rock.Position = basePos + Vector3.new(x, rock.Size.Y/2, z)
			rock.Anchored = true
			rock.CanCollide = true
			rock.Material = Enum.Material.Rock
			rock.Color = Color3.fromRGB(180, 150, 100)
			rock.Parent = self.MatchFolder
		end
	end
end

-- Inicializar círculos iniciales y spawns de jugadores
function MatchController:InitializePlayers()
	local allPlayers = {}

	-- Añadir jugadores reales
	for _, player in ipairs(self.Match.Players) do
		table.insert(allPlayers, {player = player, isBot = false})
	end

	-- Añadir bots
	for _, bot in ipairs(self.Match.Bots) do
		table.insert(allPlayers, {player = bot, isBot = true})
	end

	-- Asignar posiciones y colores
	for i, playerData in ipairs(allPlayers) do
		local player = playerData.player
		local isBot = playerData.isBot
		local color = Config.PLAYER_COLORS[i]
		local spawnPos = self.SpawnPositions[i]

		-- Crear círculo inicial
		self.TerritoryManager:InitializePlayerCircle(player, spawnPos - Vector3.new(0, 4.5, 0), color)

		-- Si es jugador real, spawnear personaje
		if not isBot then
			self:SpawnPlayer(player, spawnPos, color)
		end

		-- Inicializar estado del jugador
		self.PlayerStates[player] = {
			IsTracing = false,
			LastSafePosition = spawnPos,
			Color = color,
			IsBot = isBot
		}

		-- Si es bot, crear IA, cuerpo visible y establecer posición
		if isBot then
			local botAI = BotAI.new(player, self.TerritoryManager, self.MatchFolder)
			local groundPos = spawnPos - Vector3.new(0, 4, 0)
			botAI:SetHomePosition(groundPos)
			player.Position = groundPos

			-- Crear cuerpo visible del bot
			botAI:CreateBody(color)

			self.BotAIs[player] = botAI
		end
	end
end

-- Spawnear jugador en el mapa
function MatchController:SpawnPlayer(player, position, color)
	if not player or not player.Parent then return end

	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		humanoidRootPart.CFrame = CFrame.new(position)
	end

	-- Colorear el personaje
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = color
		end
	end

	self.PlayerCharacters[player] = character

	-- Detectar movimiento del jugador
	self:SetupPlayerMovement(player, character)
end

-- Configurar detección de movimiento y trazado
function MatchController:SetupPlayerMovement(player, character)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local lastPosition = humanoidRootPart.Position
	local updateInterval = 0.1
	local timeSinceUpdate = 0

	-- Conexión de heartbeat para este jugador
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
		if not character.Parent or not humanoidRootPart.Parent then
			connection:Disconnect()
			return
		end

		if self.Match.State ~= GameState.MatchState.PLAYING then return end

		timeSinceUpdate = timeSinceUpdate + deltaTime

		if timeSinceUpdate >= updateInterval then
			local currentPosition = humanoidRootPart.Position
			self:UpdatePlayerPosition(player, lastPosition, currentPosition)
			lastPosition = currentPosition
			timeSinceUpdate = 0
		end
	end)
end

-- Actualizar posición del jugador y gestionar trazado
function MatchController:UpdatePlayerPosition(player, lastPos, currentPos)
	local state = self.PlayerStates[player]
	if not state then return end

	local isInSafe = self.TerritoryManager:IsInSafeZone(player, currentPos)

	if isInSafe then
		-- Está en zona segura
		if state.IsTracing then
			-- Estaba trazando y volvió a zona segura -> intentar cerrar línea
			if self.TerritoryManager:CanCloseLine(player, currentPos) then
				local success, area, playersInside = self.TerritoryManager:CloseLine(player)
				if success then
					local percentage = self.TerritoryManager:GetTerritoryPercentage(player)
					print("✅", player.Name, "cerró un área de", math.floor(area), "unidades -", string.format("%.1f%%", percentage), "total")
					state.IsTracing = false

					-- Enviar porcentaje actualizado al jugador
					if not state.IsBot then
						self:SendPercentageToPlayer(player)
					end

					-- Eliminar jugadores/líneas que estaban dentro del área
					if playersInside and #playersInside > 0 then
						for _, data in ipairs(playersInside) do
							local victim = data.player
							local victimState = self.PlayerStates[victim]

							if victimState and victimState.IsTracing then
								print("💀", player.Name, "atrapó a", victim.Name, "dentro de su territorio!")

								-- Crear efecto de muerte en la posición
								if data.position then
									self.TerritoryManager:CreateDeathEffect(data.position, victimState.Color)
								end

								self:EliminatePlayer(victim, player)
							end
						end
					end

					-- También verificar jugadores físicamente dentro
					self:CheckPlayersInsideNewTerritory(player)
				end
			end
		end
		state.LastSafePosition = currentPos
	else
		-- Está en zona neutral o territorio de otro

		-- VERIFICAR SI ESTÁ PISANDO TERRITORIO DE OTRO JUGADOR
		local enemyOwner = self.TerritoryManager:GetTerritoryOwnerAt(currentPos)
		if enemyOwner and enemyOwner ~= player then
			-- ¡Pisó territorio de otro jugador! MUERE
			print("💀", player.Name, "pisó el territorio de", enemyOwner.Name, "- ELIMINADO")
			self.TerritoryManager:CreateDeathEffect(currentPos, state.Color)
			self:EliminatePlayer(player, enemyOwner)
			return
		end

		if not state.IsTracing then
			-- Iniciar trazado
			self.TerritoryManager:StartLine(player, currentPos)
			state.IsTracing = true
			print("✏️", player.Name, "comenzó a trazar")
		else
			-- Continuar trazado
			self.TerritoryManager:AddLinePoint(player, currentPos)
		end

		-- Comprobar colisiones con bolas (esto sí mata)
		self:CheckBallCollisions(player, currentPos)
	end
end

-- Verificar si hay jugadores/líneas/zonas dentro del nuevo territorio CERRADO
-- Esta es la forma de matar a alguien al cerrar una zona
function MatchController:CheckPlayersInsideNewTerritory(territoryOwner)
	local playersToKill = {}  -- Recopilar primero para evitar problemas de iteración

	for otherPlayer, state in pairs(self.PlayerStates) do
		if otherPlayer ~= territoryOwner and not state.Eliminated then
			local shouldDie = false
			local deathPos = nil
			local deathReason = ""

			-- Obtener posición actual del otro jugador
			local playerPosition = nil
			if state.IsBot then
				local botAI = self.BotAIs[otherPlayer]
				if botAI then
					playerPosition = botAI:GetPosition()
				end
				if not playerPosition then
					playerPosition = state.LastSafePosition
				end
			else
				local character = self.PlayerCharacters[otherPlayer]
				if character then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if hrp then
						playerPosition = hrp.Position
					end
				end
			end

			-- Obtener el territorio del otro jugador
			local otherTerritory = self.TerritoryManager.PlayerTerritories[otherPlayer]

			-- ========== CASO 1: Su CAMINO ACTIVO está dentro de mi nueva zona ==========
			if otherTerritory and otherTerritory.LinePoints and #otherTerritory.LinePoints > 0 then
				for _, point in ipairs(otherTerritory.LinePoints) do
					if self.TerritoryManager:IsPositionInPlayerTerritory(point, territoryOwner) then
						shouldDie = true
						deathPos = point
						deathReason = "camino activo englobado"
						break
					end
				end
			end

			-- ========== CASO 2: El jugador FÍSICO está dentro de mi zona (aunque no esté trazando) ==========
			if not shouldDie and playerPosition then
				if self.TerritoryManager:IsPositionInPlayerTerritory(playerPosition, territoryOwner) then
					shouldDie = true
					deathPos = playerPosition
					deathReason = "jugador dentro de zona cerrada"
				end
			end

			-- ========== CASO 3: Su ZONA SEGURA fue englobada ==========
			if not shouldDie and otherTerritory then
				local caughtCell = self.TerritoryManager:CheckTerritoryOverlap(otherPlayer, territoryOwner)
				if caughtCell then
					shouldDie = true
					deathPos = caughtCell
					deathReason = "zona segura englobada"
				end
			end

			-- ========== GUARDAR PARA MATAR ==========
			if shouldDie then
				table.insert(playersToKill, {
					player = otherPlayer,
					state = state,
					pos = deathPos,
					reason = deathReason
				})
			end
		end
	end

	-- ========== EJECUTAR MUERTES ==========
	for _, data in ipairs(playersToKill) do
		print("💀", territoryOwner.Name, "mató a", data.player.Name, "- Razón:", data.reason)
		if data.pos then
			self.TerritoryManager:CreateDeathEffect(data.pos, data.state.Color)
		end
		self:EliminatePlayer(data.player, territoryOwner)
	end
end

-- Comprobar si el jugador cortó la línea de otro
function MatchController:CheckLineCollisions(player, position)
	-- Posición 2D del jugador (ignorar altura)
	local playerPos2D = Vector3.new(position.X, 0, position.Z)

	-- Buscar todas las líneas activas en el mapa
	for _, part in ipairs(self.MatchFolder:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("IsActiveLine") then
			local ownerName = part:GetAttribute("OwnerName")

			-- No puede cortar su propia línea
			if ownerName == player.Name then continue end

			-- Posición 2D de la línea
			local linePos2D = Vector3.new(part.Position.X, 0, part.Position.Z)

			-- Comprobar distancia en 2D
			local distance = (playerPos2D - linePos2D).Magnitude
			local threshold = math.max(part.Size.X, part.Size.Z) / 2 + 1.5

			if distance <= threshold then
				-- ¡Cortó la línea de otro jugador!
				-- Buscar al dueño de la línea
				local victim = nil
				for p, _ in pairs(self.PlayerStates) do
					if p.Name == ownerName then
						victim = p
						break
					end
				end

				if victim then
					print("💥", player.Name, "cortó la línea de", ownerName)
					self:EliminatePlayer(victim, player)
				end
			end
		end
	end
end

-- Comprobar colisiones con bolas
-- SOLO mata si el jugador está FUERA de su zona segura (trazando)
function MatchController:CheckBallCollisions(player, position)
	local state = self.PlayerStates[player]
	if not state then return end

	-- Solo las bolas matan si estás TRAZANDO (fuera de zona segura)
	if not state.IsTracing then
		return -- En zona segura, las bolas no te matan
	end

	for _, ball in ipairs(self.Balls) do
		if ball:CheckPlayerCollision(position) then
			print("⚫", player.Name, "hit by spike ball while tracing")
			self:EliminatePlayer(player, nil)
			return
		end
	end
end

-- Eliminar un jugador
function MatchController:EliminatePlayer(player, killer)
	local state = self.PlayerStates[player]
	if not state then return end

	-- Evitar eliminar al mismo jugador dos veces
	if state.Eliminated then return end
	state.Eliminated = true

	-- Obtener posición para el efecto
	local deathPosition = state.LastSafePosition

	-- Cancelar línea activa
	if state.IsTracing then
		self.TerritoryManager:CancelActiveLine(player)
		state.IsTracing = false
	end

	-- Crear efecto de muerte
	if deathPosition then
		self.TerritoryManager:CreateDeathEffect(deathPosition, state.Color or Color3.fromRGB(255, 50, 50))
	end

	-- Si es bot, eliminar su cuerpo visible y territorio
	if state.IsBot then
		local botAI = self.BotAIs[player]
		if botAI then
			-- Crear efecto de muerte en posición del bot
			local botPos = botAI:GetPosition()
			if botPos then
				self.TerritoryManager:CreateDeathEffect(botPos, state.Color or Color3.fromRGB(255, 50, 50))
			end

			-- Eliminar cuerpo del bot
			if botAI.Cleanup then
				botAI:Cleanup()
			end
			self.BotAIs[player] = nil
		end

		-- Eliminar territorio del bot con efecto
		self.TerritoryManager:RemovePlayerTerritory(player, state.Color)
	else
		-- Si no es bot, "matar" el personaje con efecto
		local character = self.PlayerCharacters[player]
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and not deathPosition then
				self.TerritoryManager:CreateDeathEffect(hrp.Position, state.Color or Color3.fromRGB(255, 50, 50))
			end

			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end
	end

	-- Eliminar del match (con protección de error)
	if self.Match and self.Match.EliminatePlayer then
		self.Match:EliminatePlayer(player)
	elseif self.Match and self.Match.AlivePlayers then
		-- Eliminar manualmente si el método no existe
		for i, p in ipairs(self.Match.AlivePlayers) do
			if p == player then
				table.remove(self.Match.AlivePlayers, i)
				break
			end
		end
	end

	-- Mensaje de eliminación
	local killerName = killer and killer.Name or nil
	if killer then
		print("☠️", player.Name, "fue eliminado por", killer.Name)
	else
		print("☠️", player.Name, "ha sido eliminado")
	end

	print("👥 Jugadores vivos después de eliminación:", self:CountAlivePlayers())

	-- Notificar a TODOS los jugadores sobre la eliminación (incluyendo al eliminado)
	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if RemotesFolder then
		local playerEliminated = RemotesFolder:FindFirstChild("PlayerEliminated")
		if playerEliminated then
			for _, p in ipairs(self.Match.Players) do
				if p and p.Parent then
					playerEliminated:FireClient(p, player.Name, killerName)
				end
			end
		end
	end

	-- Actualizar contador de vivos
	self:BroadcastAliveCount()

	-- Si es jugador real (no bot), guardar score y enviarlo al lobby
	if not state.IsBot and player and player.Parent then
		-- Guardar score antes de sacarlo
		local percentage = self.TerritoryManager:GetTerritoryPercentage(player)
		self:SavePlayerScore(player, percentage, false)

		-- Esperar 3 segundos para mostrar mensaje, luego FINALIZAR y enviar al lobby
		task.delay(3, function()
			if player and player.Parent then
				-- FINALIZAR UI del jugador
				self:FinalizePlayerUI(player)

				-- Enviar al lobby
				task.delay(0.5, function()
					if player and player.Parent then
						local sendToLobby = ServerScriptService:FindFirstChild("SendToLobby")
						if sendToLobby then
							sendToLobby:Invoke(player)
						end
					end
				end)
			end
		end)
	end
end

-- Guardar score del jugador en las tablas
function MatchController:SavePlayerScore(player, percentage, isWinner)
	if not player or player.Parent == nil then return end

	-- Guardar en DataManager
	local scoreData = {
		PlayerName = player.Name,
		PlayerId = player.UserId,
		Percentage = percentage,
		IsWinner = isWinner,
		Timestamp = os.time()
	}

	-- Intentar guardar en DataManager
	pcall(function()
		DataManager:RecordGameScore(player, percentage, isWinner)
	end)

	print("📊 Score guardado para", player.Name, ":", string.format("%.1f%%", percentage), isWinner and "(GANADOR)" or "")
end

-- Crear bolas
function MatchController:CreateBalls()
	local mapSize = Config.MAP_SIZE
	local basePos = self.MapBasePosition

	for i = 1, Config.NUM_BALLS do
		-- Posición DENTRO del mapa (sumando MapBasePosition)
		local randomPos = basePos + Vector3.new(
			math.random(-mapSize/3, mapSize/3),
			3, -- Altura sobre el suelo
			math.random(-mapSize/3, mapSize/3)
		)

		local ball = BallPhysics.new(self.MatchFolder, randomPos, basePos, mapSize)
		table.insert(self.Balls, ball)
	end

	print("⚫ Creadas", Config.NUM_BALLS, "bolas con pinchos en mapa", basePos)
end

-- Actualizar física de las bolas
function MatchController:UpdateBalls(deltaTime)
	local boundaries = Vector3.new(Config.MAP_SIZE, 100, Config.MAP_SIZE)

	for _, ball in ipairs(self.Balls) do
		ball:Update(deltaTime, boundaries)
	end
end

-- Iniciar la partida
function MatchController:Start()
	print("🎮 Iniciando partida", self.Match.MatchId)

	-- Inicializar jugadores
	self:InitializePlayers()

	-- Crear bolas
	self:CreateBalls()

	-- Marcar inicio
	self.MatchStarted = true
	self.IsRunning = true
	self.MatchEnded = false
	self.TimeRemaining = self.MatchDuration

	-- Mostrar UI a todos los jugadores
	self:ShowUIToAllPlayers()

	-- Enviar tiempo inicial a todos los jugadores
	self:BroadcastTime()
	self:BroadcastAllPercentages()
	self:BroadcastAliveCount()

	print("✅ Partida iniciada con", #self.Match.Players, "jugadores y", #self.Match.Bots, "bots")
	print("⏱️ Duración de partida:", self.MatchDuration, "segundos")
	print("⏱️ Tiempo restante inicial:", self.TimeRemaining, "segundos")
end

-- ========================================
-- INICIALIZAR UI DE UN JUGADOR
-- Llamar cuando el jugador ENTRA a la partida
-- ========================================
function MatchController:InitializePlayerUI(player)
	if not player or not player.Parent then 
		print("🎮 [Server] InitializePlayerUI - player inválido")
		return 
	end

	local state = self.PlayerStates[player]
	if state and state.IsBot then return end

	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then 
		print("🎮 [Server] InitializePlayerUI - RemoteEvents NO encontrado")
		return 
	end

	local aliveCount = self:CountAlivePlayers()
	print("🎮 [Server] InitializePlayerUI para", player.Name)
	print("🎮 [Server] - Timer:", self.MatchDuration)
	print("🎮 [Server] - Jugadores vivos:", aliveCount)

	-- Enviar InitializeGame
	local initializeGame = RemotesFolder:FindFirstChild("InitializeGame")
	if initializeGame then
		initializeGame:FireClient(player, {
			timer = self.MatchDuration,
			players = aliveCount
		})
		print("🎮 [Server] ✅ InitializeGame enviado a", player.Name)
	else
		print("🎮 [Server] ❌ InitializeGame NO encontrado")
	end

	-- También enviar ShowGameUI por compatibilidad
	local showGameUI = RemotesFolder:FindFirstChild("ShowGameUI")
	if showGameUI then
		showGameUI:FireClient(player)
		print("🎮 [Server] ✅ ShowGameUI enviado a", player.Name)
	end
end

-- ========================================
-- FINALIZAR UI DE UN JUGADOR
-- Llamar cuando el jugador SALE de la partida (eliminado o tiempo)
-- ========================================
function MatchController:FinalizePlayerUI(player)
	if not player or not player.Parent then return end

	local state = self.PlayerStates[player]
	if state and state.IsBot then return end

	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then return end

	print("🎮 [Server] FinalizePlayerUI para", player.Name)

	-- Enviar FinalizeGame
	local finalizeGame = RemotesFolder:FindFirstChild("FinalizeGame")
	if finalizeGame then
		finalizeGame:FireClient(player)
		print("🎮 [Server] ✅ FinalizeGame enviado a", player.Name)
	end

	-- También enviar HideGameUI por compatibilidad
	local hideGameUI = RemotesFolder:FindFirstChild("HideGameUI")
	if hideGameUI then
		hideGameUI:FireClient(player)
		print("🎮 [Server] ✅ HideGameUI enviado a", player.Name)
	end
end

-- Inicializar UI de TODOS los jugadores
function MatchController:ShowUIToAllPlayers()
	print("📺 Inicializando UI para todos los jugadores...")
	for _, player in ipairs(self.Match.Players) do
		self:InitializePlayerUI(player)
	end
end

-- Finalizar UI de TODOS los jugadores
function MatchController:HideUIToAllPlayers()
	print("📺 Finalizando UI para todos los jugadores...")
	for _, player in ipairs(self.Match.Players) do
		self:FinalizePlayerUI(player)
	end
end

-- Contar jugadores vivos (incluyendo bots)
function MatchController:CountAlivePlayers()
	local count = 0
	for playerOrBot, state in pairs(self.PlayerStates) do
		if state and not state.Eliminated then
			count = count + 1
		end
	end
	return count
end

-- Broadcast contador de vivos a TODOS los jugadores reales
function MatchController:BroadcastAliveCount()
	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then return end

	local updateAliveCount = RemotesFolder:FindFirstChild("UpdateAliveCount")
	if not updateAliveCount then return end

	local aliveCount = self:CountAlivePlayers()
	print("👥 [Server] BroadcastAliveCount:", aliveCount, "jugadores/bots vivos")

	-- Enviar a TODOS los jugadores reales (aunque estén eliminados, para que vean el contador)
	for _, player in ipairs(self.Match.Players) do
		local state = self.PlayerStates[player]
		if player and player.Parent and state and not state.IsBot then
			updateAliveCount:FireClient(player, aliveCount)
			print("👥 [Server] Enviado aliveCount", aliveCount, "a", player.Name)
		end
	end
end

-- Enviar tiempo restante a todos los jugadores VIVOS (no eliminados)
function MatchController:BroadcastTime()
	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then return end

	local updateTimer = RemotesFolder:FindFirstChild("UpdateTimer")
	if updateTimer then
		for _, player in ipairs(self.Match.Players) do
			local state = self.PlayerStates[player]
			-- Solo enviar a jugadores vivos (no eliminados)
			if player and player.Parent and state and not state.Eliminated then
				updateTimer:FireClient(player, math.ceil(self.TimeRemaining))
			end
		end
	end
end

-- Enviar porcentaje a un jugador específico
function MatchController:SendPercentageToPlayer(player)
	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then return end

	local updateAreaPercentage = RemotesFolder:FindFirstChild("UpdateAreaPercentage")
	if updateAreaPercentage and player and player.Parent then
		local percentage = self.TerritoryManager:GetTerritoryPercentage(player)
		updateAreaPercentage:FireClient(player, percentage)
	end
end

-- Enviar porcentajes a todos los jugadores
function MatchController:BroadcastAllPercentages()
	for _, player in ipairs(self.Match.Players) do
		self:SendPercentageToPlayer(player)
	end
end

-- Actualizar la partida
function MatchController:Update(deltaTime)
	-- VERIFICACIONES ESTRICTAS: detener INMEDIATAMENTE si no debemos ejecutar
	if not self.IsRunning then return end
	if self.MatchEnded then return end
	if not self.MatchStarted then return end
	if self.Match.State == GameState.MatchState.ENDED then return end

	-- Actualizar temporizador
	self.TimeRemaining = self.TimeRemaining - deltaTime

	-- Enviar tiempo cada segundo aproximadamente
	local prevSecond = math.ceil(self.TimeRemaining + deltaTime)
	local currSecond = math.ceil(self.TimeRemaining)
	if prevSecond ~= currSecond then
		self:BroadcastTime()
	end

	-- ¿Se acabó el tiempo?
	if self.TimeRemaining <= 0 then
		self:EndMatchByTime()
		return
	end

	-- Actualizar bolas
	self:UpdateBalls(deltaTime)

	-- Actualizar bots (si los hay)
	self:UpdateBots(deltaTime)

	-- Comprobar si solo queda un jugador (victoria por eliminación)
	self:CheckLastPlayerStanding()
end

-- Terminar partida por tiempo
function MatchController:EndMatchByTime()
	print("⏱️ ¡Tiempo terminado!")

	-- Encontrar al jugador con más porcentaje
	local winner = nil
	local maxPercentage = -1

	for player, state in pairs(self.PlayerStates) do
		if not state.Eliminated then
			local percentage = self.TerritoryManager:GetTerritoryPercentage(player)
			print("📊", player.Name, ":", string.format("%.1f%%", percentage))

			if percentage > maxPercentage then
				maxPercentage = percentage
				winner = player
			end
		end
	end

	if winner then
		print("🏆 ¡Ganador por territorio:", winner.Name, "con", string.format("%.1f%%", maxPercentage), "!")
		self.Match.Winner = winner
	end

	self.Match.State = GameState.MatchState.ENDED
	self:EndMatch()
end

-- Verificar si solo queda un jugador
function MatchController:CheckLastPlayerStanding()
	local alivePlayers = {}

	for player, state in pairs(self.PlayerStates) do
		if not state.Eliminated then
			table.insert(alivePlayers, player)
		end
	end

	if #alivePlayers == 1 then
		local winner = alivePlayers[1]
		print("🏆 ¡", winner.Name, "es el último en pie!")
		self.Match.Winner = winner
		self.Match.State = GameState.MatchState.ENDED
		self:EndMatch()
	elseif #alivePlayers == 0 then
		print("💀 ¡Todos eliminados! Empate")
		self.Match.State = GameState.MatchState.ENDED
		self:EndMatch()
	end
end

-- Actualizar IA de bots
function MatchController:UpdateBots(deltaTime)
	for bot, botAI in pairs(self.BotAIs) do
		if self.PlayerStates[bot] then
			botAI:Update(deltaTime)

			-- Actualizar posición del bot en la lógica del juego
			local state = self.PlayerStates[bot]
			local currentPos = botAI:GetPosition()

			-- Aplicar la misma lógica que los jugadores humanos
			local isInSafe = self.TerritoryManager:IsInSafeZone(bot, currentPos)

			if isInSafe then
				if state.IsTracing then
					if self.TerritoryManager:CanCloseLine(bot, currentPos) then
						local success, area = self.TerritoryManager:CloseLine(bot)
						if success then
							local percentage = self.TerritoryManager:GetTerritoryPercentage(bot)
							print("🤖✅", bot.Name, "cerró un área de", math.floor(area), "unidades -", string.format("%.1f%%", percentage))
							state.IsTracing = false
						end
					end
				end
				state.LastSafePosition = currentPos
			else
				-- VERIFICAR SI EL BOT ESTÁ PISANDO TERRITORIO DE OTRO
				local enemyOwner = self.TerritoryManager:GetTerritoryOwnerAt(currentPos)
				if enemyOwner and enemyOwner ~= bot then
					-- ¡Pisó territorio de otro! MUERE
					print("🤖💀", bot.Name, "pisó el territorio de", enemyOwner.Name, "- ELIMINADO")
					self.TerritoryManager:CreateDeathEffect(currentPos, state.Color)
					self:EliminatePlayer(bot, enemyOwner)
				else
					if not state.IsTracing then
						self.TerritoryManager:StartLine(bot, currentPos)
						state.IsTracing = true
					else
						self.TerritoryManager:AddLinePoint(bot, currentPos)
					end

					-- Comprobar colisiones con bolas
					self:CheckBallCollisions(bot, currentPos)
				end
			end
		end
	end
end

-- Finalizar partida
function MatchController:EndMatch()
	if self.MatchEnded then return end
	self.MatchEnded = true

	-- DETENER EL GAME LOOP INMEDIATAMENTE
	self.IsRunning = false

	print("🏆 Partida", self.Match.MatchId, "finalizada - DETENIENDO TODO")

	-- Calcular rankings por porcentaje de territorio
	local rankings = {}
	local totalPlayers = 0

	for player, state in pairs(self.PlayerStates) do
		local percentage = self.TerritoryManager:GetTerritoryPercentage(player)
		table.insert(rankings, {
			player = player,
			state = state,
			percentage = percentage,
			eliminated = state.Eliminated or false
		})
		totalPlayers = totalPlayers + 1
	end

	-- Ordenar: primero los no eliminados por porcentaje, luego los eliminados
	table.sort(rankings, function(a, b)
		if a.eliminated ~= b.eliminated then
			return not a.eliminated  -- No eliminados primero
		end
		return a.percentage > b.percentage  -- Mayor porcentaje primero
	end)

	-- Asignar posiciones
	for i, data in ipairs(rankings) do
		data.position = i
	end

	-- Determinar ganador (posición 1)
	local winner = rankings[1] and rankings[1].player or nil
	local winnerName = winner and winner.Name or "Nadie"
	local winnerIsBot = winner and self.PlayerStates[winner] and self.PlayerStates[winner].IsBot

	-- Imprimir rankings
	print("📊 Rankings finales:")
	for i, data in ipairs(rankings) do
		local status = data.eliminated and "❌" or "✅"
		print("  #" .. i, status, data.player.Name, "-", string.format("%.1f%%", data.percentage))
	end

	-- Guardar scores de TODOS los jugadores REALES (incluyendo eliminados)
	for _, data in ipairs(rankings) do
		local player = data.player
		local state = data.state
		if player and player.Parent and state and not state.IsBot then
			self:SavePlayerScore(player, data.percentage, data.position == 1)

			if data.position == 1 and not data.eliminated then
				DataManager:RecordWin(player)
				print("👑 Ganador:", player.Name, "con", string.format("%.1f%%", data.percentage))
			end
		end
	end

	-- Notificar resultado a TODOS los jugadores
	local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if RemotesFolder then
		local matchEnded = RemotesFolder:FindFirstChild("MatchEnded")
		if matchEnded then
			for _, data in ipairs(rankings) do
				local player = data.player
				local state = data.state
				if player and player.Parent and state and not state.IsBot then
					local isWinner = (data.position == 1) and not data.eliminated
					matchEnded:FireClient(player, winnerName, isWinner, data.position, totalPlayers)
				end
			end
		end
	end

	-- Esperar 5 segundos para mostrar resultado
	wait(5)

	-- FINALIZAR UI de TODOS los jugadores y enviar al lobby
	print("📺 Finalizando UI de todos los jugadores...")
	for _, player in ipairs(self.Match.Players) do
		local state = self.PlayerStates[player]
		if player and player.Parent and state and not state.IsBot then
			-- Finalizar UI
			self:FinalizePlayerUI(player)

			-- Enviar al lobby (solo si no fue ya enviado por eliminación)
			if not state.Eliminated then
				local sendToLobby = ServerScriptService:FindFirstChild("SendToLobby")
				if sendToLobby then
					sendToLobby:Invoke(player)
				end
			end
		end
	end

	-- Limpiar recursos
	wait(2)
	self:Cleanup()
end

-- Limpiar recursos de la partida
function MatchController:Cleanup()
	-- Limpiar bots
	for _, botAI in pairs(self.BotAIs) do
		if botAI.Cleanup then
			botAI:Cleanup()
		end
	end
	self.BotAIs = {}

	-- Limpiar bolas
	for _, ball in ipairs(self.Balls) do
		ball:Destroy()
	end

	-- Limpiar territorio
	if self.TerritoryManager then
		self.TerritoryManager:Cleanup()
	end

	-- Eliminar carpeta
	if self.MatchFolder then
		self.MatchFolder:Destroy()
	end

	-- Desregistrar
	ActiveMatchControllers[self.Match.MatchId] = nil

	print("🗑️ Partida", self.Match.MatchId, "limpiada")
end

-- Loop principal
game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
	for _, controller in pairs(ActiveMatchControllers) do
		controller:Update(deltaTime)
	end
end)

-- Event para crear nueva partida desde otros scripts
local CreateMatchEvent = Instance.new("BindableFunction")
CreateMatchEvent.Name = "CreateMatchController"
CreateMatchEvent.Parent = ServerScriptService

CreateMatchEvent.OnInvoke = function(match)
	local controller = MatchController.new(match)
	controller:Start()
	return controller
end

print("🎯 MatchController inicializado")

return MatchController

