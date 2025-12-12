--[[
    DataManager.lua
    Gestión de datos de jugadores (puntuaciones, estadísticas)
    
    Guarda:
    - TODAS las partidas (no solo la mejor)
    - Victorias totales
    - Estadísticas generales
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}

-- DataStores
local DailyScoresStore = DataStoreService:GetOrderedDataStore("DailyScores_v3")
local WeeklyScoresStore = DataStoreService:GetOrderedDataStore("WeeklyScores_v3")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v3")

-- Cache local de datos
DataManager.PlayerData = {}

-- Cache local de TODAS las partidas para mostrar en lobby
-- Cada entrada es {PlayerName, Percentage, Timestamp}
DataManager.DailyGames = {}
DataManager.WeeklyGames = {}

-- Estructura de datos por defecto
local function getDefaultData()
	return {
		TotalWins = 0,
		TotalGames = 0,
		TotalKills = 0,
		BestPercentage = 0,
		LastPlayed = os.time()
	}
end

-- Cargar datos de un jugador
function DataManager:LoadPlayerData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. userId)
	end)

	if success and data then
		self.PlayerData[userId] = data
	else
		self.PlayerData[userId] = getDefaultData()
	end

	return self.PlayerData[userId]
end

-- Guardar datos de un jugador
function DataManager:SavePlayerData(player)
	local userId = player.UserId
	local data = self.PlayerData[userId]

	if not data then return end

	local success, err = pcall(function()
		PlayerDataStore:SetAsync("Player_" .. userId, data)
	end)

	if not success then
		warn("Error guardando datos del jugador " .. player.Name .. ": " .. tostring(err))
	end
end

-- Registrar score de una partida (GUARDA TODAS LAS PARTIDAS)
function DataManager:RecordGameScore(player, percentage, isWinner)
	if not player then return end

	local userId = player.UserId
	local data = self.PlayerData[userId]

	if not data then
		data = getDefaultData()
		self.PlayerData[userId] = data
	end

	-- Actualizar estadísticas
	data.TotalGames = (data.TotalGames or 0) + 1
	data.LastPlayed = os.time()

	-- Actualizar mejor porcentaje
	if percentage > (data.BestPercentage or 0) then
		data.BestPercentage = percentage
	end

	-- Crear entrada para esta partida
	local gameEntry = {
		PlayerName = player.Name,
		Percentage = percentage,
		Timestamp = os.time(),
		IsWinner = isWinner
	}

	-- Añadir a las listas locales (no sobrescribir)
	table.insert(self.DailyGames, gameEntry)
	table.insert(self.WeeklyGames, gameEntry)

	-- Ordenar por porcentaje descendente
	table.sort(self.DailyGames, function(a, b) return a.Percentage > b.Percentage end)
	table.sort(self.WeeklyGames, function(a, b) return a.Percentage > b.Percentage end)

	-- Mantener solo los top 50 para no llenar memoria
	while #self.DailyGames > 50 do
		table.remove(self.DailyGames)
	end
	while #self.WeeklyGames > 50 do
		table.remove(self.WeeklyGames)
	end

	-- Intentar actualizar leaderboards en DataStore
	self:UpdateLeaderboards(player, percentage)

	print("📊 Score registrado:", player.Name, "=", string.format("%.1f%%", percentage), "(Total partidas en ranking:", #self.DailyGames, ")")
end

-- Registrar una victoria
function DataManager:RecordWin(player)
	if not player then return end

	local userId = player.UserId
	local data = self.PlayerData[userId]

	if data then
		data.TotalWins = (data.TotalWins or 0) + 1
		data.LastPlayed = os.time()
	end
end

-- Actualizar leaderboards en DataStore
function DataManager:UpdateLeaderboards(player, percentage)
	if not player then return end

	-- Crear key única para cada partida (nombre + timestamp)
	local uniqueKey = player.Name .. "_" .. tostring(os.time())
	local scoreInt = math.floor(percentage * 100)

	pcall(function()
		if scoreInt > 0 then
			DailyScoresStore:SetAsync(uniqueKey, scoreInt)
			WeeklyScoresStore:SetAsync(uniqueKey, scoreInt)
		end
	end)
end

-- Obtener top scores diarios (desde cache local)
function DataManager:GetDailyTopScores(count)
	count = count or 10

	local result = {}
	for i = 1, math.min(count, #self.DailyGames) do
		local entry = self.DailyGames[i]
		table.insert(result, {
			Name = entry.PlayerName,
			Score = entry.Percentage
		})
	end

	return result
end

-- Obtener top scores semanales (desde cache local)
function DataManager:GetWeeklyTopScores(count)
	count = count or 10

	local result = {}
	for i = 1, math.min(count, #self.WeeklyGames) do
		local entry = self.WeeklyGames[i]
		table.insert(result, {
			Name = entry.PlayerName,
			Score = entry.Percentage
		})
	end

	return result
end

-- Limpiar datos diarios (llamar al cambiar de día)
function DataManager:ClearDailyData()
	self.DailyGames = {}
	print("📊 Datos diarios limpiados")
end

-- Limpiar datos semanales (llamar al cambiar de semana)
function DataManager:ClearWeeklyData()
	self.WeeklyGames = {}
	print("📊 Datos semanales limpiados")
end

-- Limpiar datos al salir
function DataManager:PlayerRemoving(player)
	self:SavePlayerData(player)
	self.PlayerData[player.UserId] = nil
end

return DataManager
