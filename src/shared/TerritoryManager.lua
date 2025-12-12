--[[
    TerritoryManager.lua
    Sistema de territorio tipo Gal Panic con GRID
    
    - El mapa se divide en celdas pequeñas (como pixels)
    - Cuando cierras un área, se pintan todas las celdas dentro
    - La forma sigue EXACTAMENTE la línea que trazaste
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TerritoryManager = {}
TerritoryManager.__index = TerritoryManager

local GROUND_Y = 0.5
local LINE_Y = 0.55
local CELL_SIZE = 2  -- Tamaño de cada celda del grid (más pequeño = más detalle)

function TerritoryManager.new(matchFolder, mapBasePosition)
	local self = setmetatable({}, TerritoryManager)
	self.MatchFolder = matchFolder
	self.PlayerTerritories = {}
	self.MapSize = Config.MAP_SIZE
	self.MapBasePosition = mapBasePosition or Vector3.new(0, 0, 0)

	-- Grid del mapa: cada celda guarda quién la posee
	self.Grid = {}
	self.GridParts = {}  -- Partes visuales del grid
	self.GridSize = math.ceil(self.MapSize / CELL_SIZE)

	-- Inicializar grid vacío
	for x = 1, self.GridSize do
		self.Grid[x] = {}
		self.GridParts[x] = {}
		for z = 1, self.GridSize do
			self.Grid[x][z] = nil  -- nil = no reclamado
			self.GridParts[x][z] = nil
		end
	end

	return self
end

-- Convertir posición del mundo a coordenadas del grid
function TerritoryManager:WorldToGrid(position)
	local halfMap = self.MapSize / 2
	local baseX = self.MapBasePosition.X
	local baseZ = self.MapBasePosition.Z

	local x = math.floor((position.X - baseX + halfMap) / CELL_SIZE) + 1
	local z = math.floor((position.Z - baseZ + halfMap) / CELL_SIZE) + 1
	x = math.clamp(x, 1, self.GridSize)
	z = math.clamp(z, 1, self.GridSize)
	return x, z
end

-- Convertir coordenadas del grid a posición del mundo
function TerritoryManager:GridToWorld(gridX, gridZ)
	local halfMap = self.MapSize / 2
	local baseX = self.MapBasePosition.X
	local baseZ = self.MapBasePosition.Z

	local x = (gridX - 1) * CELL_SIZE - halfMap + CELL_SIZE / 2 + baseX
	local z = (gridZ - 1) * CELL_SIZE - halfMap + CELL_SIZE / 2 + baseZ
	return Vector3.new(x, GROUND_Y, z)
end

-- ============================================
-- INICIALIZACIÓN DEL JUGADOR
-- ============================================

function TerritoryManager:InitializePlayerCircle(player, position, color)
	-- Pintar círculo inicial en el grid
	local centerX, centerZ = self:WorldToGrid(position)
	local radius = math.ceil(Config.PLAYER_CIRCLE_RADIUS / CELL_SIZE)

	local cellsOwned = 0

	for dx = -radius, radius do
		for dz = -radius, radius do
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= radius then
				local gx = centerX + dx
				local gz = centerZ + dz
				if gx >= 1 and gx <= self.GridSize and gz >= 1 and gz <= self.GridSize then
					self:ClaimCell(gx, gz, player, color)
					cellsOwned = cellsOwned + 1
				end
			end
		end
	end

	self.PlayerTerritories[player] = {
		Color = color,
		CellsOwned = cellsOwned,
		ActiveLine = nil,
		LineParts = {},
		LinePoints = {},  -- Puntos exactos de la línea
		LineGridCells = {},  -- Celdas por donde pasó la línea
		StartPoint = nil
	}

	print("🎨", player.Name, "inició con", cellsOwned, "celdas")

	return true
end

-- Reclamar una celda del grid
function TerritoryManager:ClaimCell(gridX, gridZ, player, color)
	if gridX < 1 or gridX > self.GridSize or gridZ < 1 or gridZ > self.GridSize then
		return false
	end

	-- Si ya es del jugador, no hacer nada
	if self.Grid[gridX][gridZ] == player then
		return false
	end

	-- Quitar de otro jugador si es necesario
	local previousOwner = self.Grid[gridX][gridZ]
	if previousOwner and self.PlayerTerritories[previousOwner] then
		self.PlayerTerritories[previousOwner].CellsOwned = 
			self.PlayerTerritories[previousOwner].CellsOwned - 1
	end

	-- Asignar al nuevo jugador
	self.Grid[gridX][gridZ] = player

	-- Crear o actualizar parte visual
	self:UpdateCellVisual(gridX, gridZ, color)

	return true
end

-- Actualizar visual de una celda
function TerritoryManager:UpdateCellVisual(gridX, gridZ, color)
	local existingPart = self.GridParts[gridX] and self.GridParts[gridX][gridZ]

	if existingPart then
		-- Actualizar color con animación
		TweenService:Create(existingPart, TweenInfo.new(0.2), {Color = color}):Play()
	else
		-- Crear nueva parte
		local worldPos = self:GridToWorld(gridX, gridZ)

		local part = Instance.new("Part")
		part.Name = "Cell_" .. gridX .. "_" .. gridZ
		part.Size = Vector3.new(CELL_SIZE - 0.1, 0.15, CELL_SIZE - 0.1)
		part.Position = worldPos + Vector3.new(0, 0.1, 0)
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = self.MatchFolder

		-- Animación de aparición
		part.Transparency = 1
		TweenService:Create(part, TweenInfo.new(0.15), {Transparency = 0.1}):Play()

		if not self.GridParts[gridX] then
			self.GridParts[gridX] = {}
		end
		self.GridParts[gridX][gridZ] = part
	end
end

-- ============================================
-- SISTEMA DE LÍNEAS
-- ============================================

function TerritoryManager:StartLine(player, startPosition)
	local territory = self.PlayerTerritories[player]
	if not territory then return false end
	if territory.ActiveLine then return false end

	territory.ActiveLine = true
	territory.LinePoints = {Vector3.new(startPosition.X, LINE_Y, startPosition.Z)}
	territory.LineParts = {}
	territory.LineGridCells = {}
	territory.StartPoint = startPosition

	-- Marcar celda inicial de la línea
	local gx, gz = self:WorldToGrid(startPosition)
	table.insert(territory.LineGridCells, {x = gx, z = gz})

	return true
end

function TerritoryManager:AddLinePoint(player, position)
	local territory = self.PlayerTerritories[player]
	if not territory or not territory.ActiveLine then return end

	local points = territory.LinePoints
	local lastPoint = points[#points]
	local newPoint = Vector3.new(position.X, LINE_Y, position.Z)

	-- Distancia mínima entre puntos
	local distance = ((newPoint - lastPoint) * Vector3.new(1, 0, 1)).Magnitude
	if distance < 0.5 then return end

	table.insert(points, newPoint)

	-- Crear segmento visual de la línea
	self:CreateLineSegment(player, lastPoint, newPoint, territory.Color)

	-- Registrar celdas por donde pasa la línea
	self:RegisterLineCells(territory, lastPoint, newPoint)
end

function TerritoryManager:RegisterLineCells(territory, point1, point2)
	-- Usar algoritmo de Bresenham para obtener todas las celdas entre dos puntos
	local x1, z1 = self:WorldToGrid(point1)
	local x2, z2 = self:WorldToGrid(point2)

	local dx = math.abs(x2 - x1)
	local dz = math.abs(z2 - z1)
	local sx = x1 < x2 and 1 or -1
	local sz = z1 < z2 and 1 or -1
	local err = dx - dz

	local x, z = x1, z1

	while true do
		-- Añadir celda si no está ya
		local found = false
		for _, cell in ipairs(territory.LineGridCells) do
			if cell.x == x and cell.z == z then
				found = true
				break
			end
		end
		if not found then
			table.insert(territory.LineGridCells, {x = x, z = z})
		end

		if x == x2 and z == z2 then break end

		local e2 = 2 * err
		if e2 > -dz then
			err = err - dz
			x = x + sx
		end
		if e2 < dx then
			err = err + dx
			z = z + sz
		end
	end
end

function TerritoryManager:CreateLineSegment(player, point1, point2, color)
	local territory = self.PlayerTerritories[player]
	if not territory then return end

	local midPoint = (point1 + point2) / 2
	local distance = (point2 - point1).Magnitude

	if distance < 0.1 then return end

	local linePart = Instance.new("Part")
	linePart.Name = "Trail_" .. player.Name
	linePart.Size = Vector3.new(0.5, 0.12, distance + 0.1)
	linePart.Anchored = true
	linePart.CanCollide = false
	linePart.Material = Enum.Material.Neon
	linePart.Color = color
	linePart.Transparency = 0
	linePart.CFrame = CFrame.lookAt(midPoint, point2)
	linePart:SetAttribute("IsActiveLine", true)
	linePart:SetAttribute("OwnerName", player.Name)
	linePart.Parent = self.MatchFolder

	table.insert(territory.LineParts, linePart)
end

-- ============================================
-- CERRAR TERRITORIO
-- ============================================

function TerritoryManager:CanCloseLine(player, currentPosition)
	local territory = self.PlayerTerritories[player]
	if not territory or not territory.ActiveLine then return false end
	if #territory.LinePoints < 3 then return false end

	-- Verificar si está sobre territorio propio
	local gx, gz = self:WorldToGrid(currentPosition)
	return self.Grid[gx] and self.Grid[gx][gz] == player
end

function TerritoryManager:CloseLine(player)
	local territory = self.PlayerTerritories[player]
	if not territory or not territory.ActiveLine then return false, 0, {} end

	local linePoints = territory.LinePoints
	if #linePoints < 3 then
		self:CancelActiveLine(player)
		return false, 0, {}
	end

	-- Añadir punto final de la línea
	local lastPoint = linePoints[#linePoints]
	local gx, gz = self:WorldToGrid(lastPoint)
	table.insert(territory.LineGridCells, {x = gx, z = gz})

	-- Construir polígono de la línea para flood fill
	local polygon = {}
	for _, p in ipairs(linePoints) do
		table.insert(polygon, {x = p.X, z = p.Z})
	end

	-- Rellenar el área encerrada usando flood fill
	local cellsFilled = self:FloodFillArea(player, territory, polygon)

	-- Efecto visual
	if cellsFilled > 0 then
		self:CreateCloseEffect(linePoints, territory.Color)
	end

	-- Buscar jugadores dentro del área
	local playersInside = self:FindPlayersInArea(polygon, player)

	-- Eliminar líneas visuales
	for _, part in ipairs(territory.LineParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end

	-- Actualizar estadísticas
	territory.CellsOwned = territory.CellsOwned + cellsFilled
	local area = cellsFilled * CELL_SIZE * CELL_SIZE

	-- Limpiar estado
	territory.ActiveLine = nil
	territory.LinePoints = {}
	territory.LineParts = {}
	territory.LineGridCells = {}
	territory.StartPoint = nil

	print("✅", player.Name, "capturó", cellsFilled, "celdas (", math.floor(area), "unidades²)")

	return true, area, playersInside
end

-- Flood fill desde el EXTERIOR para encontrar el interior sin huecos
-- MEJORADO: Usa set para visitados y maneja zonas grandes correctamente
function TerritoryManager:FloodFillArea(player, territory, polygon)
	local color = territory.Color
	local cellsFilled = 0

	-- Encontrar bounding box del polígono
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, p in ipairs(polygon) do
		minX = math.min(minX, p.x)
		maxX = math.max(maxX, p.x)
		minZ = math.min(minZ, p.z)
		maxZ = math.max(maxZ, p.z)
	end

	-- Convertir a coordenadas de grid con margen
	local gMinX, gMinZ = self:WorldToGrid(Vector3.new(minX, 0, minZ))
	local gMaxX, gMaxZ = self:WorldToGrid(Vector3.new(maxX, 0, maxZ))

	-- Expandir para tener margen exterior (más grande para zonas grandes)
	local margin = 3
	gMinX = math.max(1, gMinX - margin)
	gMinZ = math.max(1, gMinZ - margin)
	gMaxX = math.min(self.GridSize, gMaxX + margin)
	gMaxZ = math.min(self.GridSize, gMaxZ + margin)

	-- Crear mapa temporal para el área de trabajo
	local workArea = {}
	local EMPTY = 0
	local BORDER = 1
	local EXTERIOR = 2
	local OWNED = 3

	for x = gMinX, gMaxX do
		workArea[x] = {}
		for z = gMinZ, gMaxZ do
			-- Marcar celdas ya del jugador como OWNED
			if self.Grid[x] and self.Grid[x][z] == player then
				workArea[x][z] = OWNED
			else
				workArea[x][z] = EMPTY
			end
		end
	end

	-- Marcar las celdas de la línea como BORDER (incluir todos los puntos)
	for _, cell in ipairs(territory.LineGridCells) do
		if cell.x >= gMinX and cell.x <= gMaxX and cell.z >= gMinZ and cell.z <= gMaxZ then
			if workArea[cell.x] and workArea[cell.x][cell.z] ~= OWNED then
				workArea[cell.x][cell.z] = BORDER
			end
		end
	end

	-- También marcar puntos intermedios de la línea (para evitar huecos en líneas diagonales)
	for i = 1, #territory.LinePoints - 1 do
		local p1 = territory.LinePoints[i]
		local p2 = territory.LinePoints[i + 1]
		local g1x, g1z = self:WorldToGrid(p1)
		local g2x, g2z = self:WorldToGrid(p2)

		-- Bresenham-like para llenar entre puntos
		local dx = math.abs(g2x - g1x)
		local dz = math.abs(g2z - g1z)
		local steps = math.max(dx, dz)

		if steps > 0 then
			for s = 0, steps do
				local t = s / steps
				local gx = math.floor(g1x + (g2x - g1x) * t + 0.5)
				local gz = math.floor(g1z + (g2z - g1z) * t + 0.5)

				if gx >= gMinX and gx <= gMaxX and gz >= gMinZ and gz <= gMaxZ then
					if workArea[gx] and workArea[gx][gz] ~= OWNED then
						workArea[gx][gz] = BORDER
					end
				end
			end
		end
	end

	-- Flood fill desde TODOS los bordes del área de trabajo
	-- Usar un set para visitados en lugar de modificar queue
	local visited = {}
	local function key(x, z) return x * 10000 + z end

	local queue = {}
	local head, tail = 1, 0

	-- Añadir todos los bordes del área de trabajo como puntos de inicio
	for x = gMinX, gMaxX do
		if workArea[x][gMinZ] == EMPTY then
			tail = tail + 1
			queue[tail] = {x, gMinZ}
			visited[key(x, gMinZ)] = true
		end
		if workArea[x][gMaxZ] == EMPTY then
			tail = tail + 1
			queue[tail] = {x, gMaxZ}
			visited[key(x, gMaxZ)] = true
		end
	end
	for z = gMinZ + 1, gMaxZ - 1 do
		if workArea[gMinX][z] == EMPTY then
			tail = tail + 1
			queue[tail] = {gMinX, z}
			visited[key(gMinX, z)] = true
		end
		if workArea[gMaxX][z] == EMPTY then
			tail = tail + 1
			queue[tail] = {gMaxX, z}
			visited[key(gMaxX, z)] = true
		end
	end

	-- BFS para marcar el exterior (más eficiente)
	local dx = {1, -1, 0, 0}
	local dz = {0, 0, 1, -1}

	while head <= tail do
		local current = queue[head]
		head = head + 1
		local x, z = current[1], current[2]

		workArea[x][z] = EXTERIOR

		-- Añadir vecinos
		for i = 1, 4 do
			local nx, nz = x + dx[i], z + dz[i]

			if nx >= gMinX and nx <= gMaxX and nz >= gMinZ and nz <= gMaxZ then
				local k = key(nx, nz)
				if not visited[k] and workArea[nx] and workArea[nx][nz] == EMPTY then
					visited[k] = true
					tail = tail + 1
					queue[tail] = {nx, nz}
				end
			end
		end
	end

	-- Todo lo que NO es EXTERIOR, OWNED ni BORDER inicial que ahora es exterior -> reclamar
	for x = gMinX, gMaxX do
		for z = gMinZ, gMaxZ do
			local state = workArea[x][z]
			-- Si es EMPTY (no alcanzado por exterior) o BORDER, es parte del interior
			if state == EMPTY or state == BORDER then
				if self.Grid[x] and self.Grid[x][z] ~= player then
					if self:ClaimCell(x, z, player, color) then
						cellsFilled = cellsFilled + 1
					end
				end
			end
		end
	end

	return cellsFilled
end

-- Ray casting para determinar si un punto está dentro del polígono
function TerritoryManager:IsPointInPolygon(point, polygon)
	if #polygon < 3 then return false end

	local inside = false
	local n = #polygon
	local j = n

	for i = 1, n do
		local xi, zi = polygon[i].x, polygon[i].z
		local xj, zj = polygon[j].x, polygon[j].z

		if ((zi > point.z) ~= (zj > point.z)) and
			(point.x < (xj - xi) * (point.z - zi) / (zj - zi) + xi) then
			inside = not inside
		end

		j = i
	end

	return inside
end

-- ============================================
-- DETECCIÓN DE ZONA SEGURA
-- ============================================

function TerritoryManager:IsInSafeZone(player, position)
	local gx, gz = self:WorldToGrid(position)
	if gx < 1 or gx > self.GridSize or gz < 1 or gz > self.GridSize then
		return false
	end
	return self.Grid[gx] and self.Grid[gx][gz] == player
end

-- ============================================
-- EFECTOS VISUALES
-- ============================================

function TerritoryManager:CreateCloseEffect(points, color)
	if not points or #points == 0 then return end

	print("✨ Creando efecto fireworks de cierre de zona")

	-- Calcular centro
	local centerX, centerZ = 0, 0
	for _, p in ipairs(points) do
		centerX = centerX + p.X
		centerZ = centerZ + p.Z
	end
	centerX = centerX / #points
	centerZ = centerZ / #points

	local center = Vector3.new(centerX, GROUND_Y + 2, centerZ)

	-- ========== FIREWORKS - Partículas que suben y explotan ==========
	local numFireworks = 5

	for f = 1, numFireworks do
		-- Posición aleatoria dentro de la zona
		local offsetX = (math.random() - 0.5) * 10
		local offsetZ = (math.random() - 0.5) * 10
		local startPos = center + Vector3.new(offsetX, 0, offsetZ)
		local peakHeight = 8 + math.random() * 6

		-- Cohete que sube
		local rocket = Instance.new("Part")
		rocket.Name = "Firework"
		rocket.Size = Vector3.new(0.3, 0.3, 0.3)
		rocket.Position = startPos
		rocket.Anchored = true
		rocket.CanCollide = false
		rocket.Material = Enum.Material.Neon
		rocket.Color = color
		rocket.Shape = Enum.PartType.Ball
		rocket.Transparency = 0.3
		rocket.Parent = self.MatchFolder

		-- Trail del cohete
		local trail = Instance.new("Part")
		trail.Name = "Trail"
		trail.Size = Vector3.new(0.15, 0.5, 0.15)
		trail.Position = startPos
		trail.Anchored = true
		trail.CanCollide = false
		trail.Material = Enum.Material.Neon
		trail.Color = Color3.fromRGB(255, 200, 100)
		trail.Transparency = 0.5
		trail.Parent = self.MatchFolder

		-- Animar cohete subiendo
		local peakPos = startPos + Vector3.new(0, peakHeight, 0)
		local riseTime = 0.3 + math.random() * 0.2
		local delay = (f - 1) * 0.1

		task.delay(delay, function()
			if not rocket or not rocket.Parent then return end

			local riseTween = TweenService:Create(rocket, TweenInfo.new(riseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = peakPos
			})
			riseTween:Play()

			TweenService:Create(trail, TweenInfo.new(riseTime), {
				Position = peakPos - Vector3.new(0, 1, 0),
				Transparency = 1
			}):Play()

			-- Explotar al llegar arriba
			riseTween.Completed:Connect(function()
				if not rocket or not rocket.Parent then return end

				rocket:Destroy()

				-- Explosión de partículas
				local numParticles = 12 + math.random(0, 6)
				local colors = {
					color,
					Color3.fromRGB(255, 255, 255),
					Color3.fromRGB(255, 200, 100),
				}

				for i = 1, numParticles do
					local particle = Instance.new("Part")
					particle.Size = Vector3.new(0.25, 0.25, 0.25)
					particle.Position = peakPos
					particle.Anchored = true
					particle.CanCollide = false
					particle.Material = Enum.Material.Neon
					particle.Color = colors[math.random(1, #colors)]
					particle.Shape = Enum.PartType.Ball
					particle.Transparency = 0
					particle.Parent = self.MatchFolder

					-- Dirección aleatoria esférica
					local theta = math.random() * math.pi * 2
					local phi = math.random() * math.pi
					local radius = 4 + math.random() * 4
					local targetPos = peakPos + Vector3.new(
						math.sin(phi) * math.cos(theta) * radius,
						math.cos(phi) * radius * 0.5 - 2,  -- Caen un poco
						math.sin(phi) * math.sin(theta) * radius
					)

					local duration = 0.5 + math.random() * 0.3
					TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = targetPos,
						Transparency = 1,
						Size = Vector3.new(0.05, 0.05, 0.05)
					}):Play()

					Debris:AddItem(particle, duration + 0.1)
				end
			end)
		end)

		Debris:AddItem(rocket, 2)
		Debris:AddItem(trail, 2)
	end

	-- ========== PEQUEÑO BRILLO EN EL SUELO (sutil) ==========
	local glow = Instance.new("Part")
	glow.Name = "GroundGlow"
	glow.Size = Vector3.new(8, 0.1, 8)
	glow.Position = center
	glow.Anchored = true
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Transparency = 0.7
	glow.Parent = self.MatchFolder

	TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(20, 0.1, 20),
		Transparency = 1
	}):Play()

	Debris:AddItem(glow, 1)
end

function TerritoryManager:CreateDeathEffect(position, color)
	local center = Vector3.new(position.X, position.Y + 3, position.Z)

	local explosion = Instance.new("Part")
	explosion.Name = "DeathExplosion"
	explosion.Size = Vector3.new(2, 2, 2)
	explosion.Position = center
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 50, 50)
	explosion.Shape = Enum.PartType.Ball
	explosion.Parent = self.MatchFolder

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 50)
	light.Brightness = 6
	light.Range = 35
	light.Parent = explosion

	TweenService:Create(explosion, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(18, 18, 18), Transparency = 1
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 0}):Play()

	-- Partículas de muerte
	for i = 1, 14 do
		local particle = Instance.new("Part")
		particle.Size = Vector3.new(0.6, 0.6, 0.6)
		particle.Position = center
		particle.Anchored = true
		particle.CanCollide = false
		particle.Material = Enum.Material.Neon
		particle.Color = Color3.fromRGB(255, math.random(30, 120), 30)
		particle.Shape = Enum.PartType.Ball
		particle.Parent = self.MatchFolder

		local angle = (i / 14) * math.pi * 2
		local targetPos = center + Vector3.new(
			math.cos(angle) * 10,
			math.random(-3, 6),
			math.sin(angle) * 10
		)

		TweenService:Create(particle, TweenInfo.new(0.45), {
			Position = targetPos, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1)
		}):Play()

		Debris:AddItem(particle, 0.5)
	end

	Debris:AddItem(explosion, 0.6)
end

-- ============================================
-- DETECCIÓN DE JUGADORES EN ÁREA
-- ============================================

function TerritoryManager:FindPlayersInArea(polygon, excludePlayer)
	local playersInside = {}

	for player, territory in pairs(self.PlayerTerritories) do
		if player ~= excludePlayer then
			-- Verificar si la línea activa está dentro del área
			if territory.ActiveLine and territory.LinePoints then
				for _, point in ipairs(territory.LinePoints) do
					local p = {x = point.X, z = point.Z}
					if self:IsPointInPolygon(p, polygon) then
						table.insert(playersInside, {
							player = player,
							type = "line",
							position = point
						})
						break
					end
				end
			end
		end
	end

	return playersInside
end

function TerritoryManager:IsPositionInPlayerTerritory(position, player)
	return self:IsInSafeZone(player, position)
end

-- Obtener el dueño del territorio en una posición (o nil si no hay dueño)
function TerritoryManager:GetTerritoryOwnerAt(position)
	local gx, gz = self:WorldToGrid(position)
	if gx < 1 or gx > self.GridSize or gz < 1 or gz > self.GridSize then
		return nil
	end
	return self.Grid[gx] and self.Grid[gx][gz] or nil
end

-- Verificar si alguna celda del territorio de victimPlayer está dentro del territorio de killerPlayer
-- Retorna la posición de la primera celda encontrada, o nil si no hay overlap
function TerritoryManager:CheckTerritoryOverlap(victimPlayer, killerPlayer)
	-- Recorrer el grid buscando celdas del victim que estén dentro del killer
	for x = 1, self.GridSize do
		for z = 1, self.GridSize do
			if self.Grid[x] and self.Grid[x][z] == victimPlayer then
				-- Esta celda pertenece a la víctima, verificar si también está en el territorio del killer
				if self.Grid[x][z] == killerPlayer then
					-- No puede ser ambos, así que verificamos si está DENTRO (englobado)
					-- Convertir a posición mundial
					local worldPos = self:GridToWorld(x, z)
					return worldPos
				end
			end
		end
	end

	-- También verificar si el killer acaba de "comerse" parte del territorio del victim
	-- Esto ocurre cuando el territorio del victim fue sobrescrito por el killer
	local victimTerritory = self.PlayerTerritories[victimPlayer]
	if victimTerritory and victimTerritory.CellsOwned then
		-- Contar cuántas celdas tiene realmente el victim ahora
		local actualCells = 0
		for x = 1, self.GridSize do
			for z = 1, self.GridSize do
				if self.Grid[x] and self.Grid[x][z] == victimPlayer then
					actualCells = actualCells + 1
				end
			end
		end

		-- Si perdió celdas significativamente (más del 50%), fue englobado
		if victimTerritory.CellsOwned > 0 and actualCells < victimTerritory.CellsOwned * 0.5 then
			-- Actualizar conteo
			local lostCells = victimTerritory.CellsOwned - actualCells
			print("⚠️", victimPlayer.Name, "perdió", lostCells, "celdas")
			victimTerritory.CellsOwned = actualCells

			-- Si perdió TODO su territorio, retornar posición de muerte
			if actualCells == 0 then
				return victimTerritory.StartPosition or self:GridToWorld(self.GridSize / 2, self.GridSize / 2)
			end
		end
	end

	return nil
end

-- ============================================
-- UTILIDADES
-- ============================================

function TerritoryManager:CancelActiveLine(player)
	local territory = self.PlayerTerritories[player]
	if not territory then return end

	for _, part in ipairs(territory.LineParts or {}) do
		if part and part.Parent then
			part:Destroy()
		end
	end

	territory.ActiveLine = nil
	territory.LinePoints = {}
	territory.LineParts = {}
	territory.LineGridCells = {}
	territory.StartPoint = nil
end

function TerritoryManager:GetTerritoryPercentage(player)
	local territory = self.PlayerTerritories[player]
	if not territory then return 0 end
	local totalCells = self.GridSize * self.GridSize
	return (territory.CellsOwned / totalCells) * 100
end

-- Eliminar territorio de un jugador (cuando muere)
function TerritoryManager:RemovePlayerTerritory(player, color)
	local territory = self.PlayerTerritories[player]
	if not territory then return end

	-- Recopilar todas las celdas del jugador
	local cellsToRemove = {}
	for x = 1, self.GridSize do
		for z = 1, self.GridSize do
			if self.Grid[x] and self.Grid[x][z] == player then
				table.insert(cellsToRemove, {x = x, z = z})
			end
		end
	end

	-- Eliminar con efecto de desvanecimiento
	for i, cell in ipairs(cellsToRemove) do
		local part = self.GridParts[cell.x] and self.GridParts[cell.x][cell.z]
		if part and part.Parent then
			-- Efecto de desvanecimiento escalonado
			local delay = (i / #cellsToRemove) * 0.5  -- Distribuir en 0.5 segundos

			task.delay(delay, function()
				if part and part.Parent then
					-- Efecto de desvanecimiento
					local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local tween = TweenService:Create(part, tweenInfo, {
						Transparency = 1,
						Size = Vector3.new(part.Size.X * 0.5, part.Size.Y, part.Size.Z * 0.5)
					})
					tween:Play()

					tween.Completed:Connect(function()
						if part and part.Parent then
							part:Destroy()
						end
					end)
				end
			end)
		end

		-- Limpiar grid
		self.Grid[cell.x][cell.z] = nil
		self.GridParts[cell.x][cell.z] = nil
	end

	-- Limpiar líneas activas
	if territory.LineParts then
		for _, part in ipairs(territory.LineParts) do
			if part and part.Parent then
				part:Destroy()
			end
		end
	end

	-- Eliminar del registro
	self.PlayerTerritories[player] = nil

	print("🗑️ Territorio de", player.Name, "eliminado (", #cellsToRemove, "celdas)")
end

function TerritoryManager:Cleanup()
	for player, territory in pairs(self.PlayerTerritories) do
		for _, part in ipairs(territory.LineParts or {}) do
			if part and part.Parent then
				pcall(function() part:Destroy() end)
			end
		end
	end

	-- Limpiar grid visual
	for x = 1, self.GridSize do
		for z = 1, self.GridSize do
			local part = self.GridParts[x] and self.GridParts[x][z]
			if part and part.Parent then
				pcall(function() part:Destroy() end)
			end
		end
	end

	self.PlayerTerritories = {}
	self.Grid = {}
	self.GridParts = {}
end

return TerritoryManager
