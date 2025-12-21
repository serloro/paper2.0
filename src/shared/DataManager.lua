--[[
    DataManager.lua
    Gestión de datos de jugadores y rankings
    
    SERVICIOS UTILIZADOS:
    - DataStoreService: Datos persistentes del jugador (estadísticas, victorias)
    - MemoryStoreService: Rankings temporales con reset automático
      * Diario: TTL de 24 horas (86400 segundos)
      * Semanal: TTL de 7 días (604800 segundos)
    
    Los rankings se resetean AUTOMÁTICAMENTE cuando expira el TTL.
]]

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players") 

local DataManager = {}

-- ============================================
-- DATASTORES (Datos persistentes del jugador)
-- ============================================
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v4")

-- ============================================
-- MEMORY STORES (Rankings temporales con TTL)
-- ============================================
local DailyRankingMap = MemoryStoreService:GetSortedMap("DailyRanking_v1")
local WeeklyRankingMap = MemoryStoreService:GetSortedMap("WeeklyRanking_v1")

-- TTL (Time To Live) en segundos
local DAILY_TTL = 86400      -- 24 horas
local WEEKLY_TTL = 604800    -- 7 días

-- ============================================
-- CACHE LOCAL
-- ============================================
DataManager.PlayerData = {}

-- Cache local de rankings (para mostrar sin consultar constantemente)
DataManager.CachedDailyRanking = {}
DataManager.CachedWeeklyRanking = {}
DataManager.LastRankingUpdate = 0
DataManager.RANKING_CACHE_TIME = 10  -- Actualizar cache cada 10 segundos

-- ============================================
-- DATOS POR DEFECTO DEL JUGADOR
-- ============================================
local function getDefaultData()
	return {
		TotalWins = 0,
		TotalGames = 0,
		TotalKills = 0,
		BestPercentage = 0,
		TotalPercentage = 0,  -- Suma de todos los porcentajes (para promedios)
		LastPlayed = os.time(),
		JoinDate = os.time()
	}
end

-- ============================================
-- GESTIÓN DE DATOS DEL JUGADOR (DataStore)
-- ============================================

-- Cargar datos de un jugador
function DataManager:LoadPlayerData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. userId)
	end)

	if success and data then
		self.PlayerData[userId] = data
		print("📊 Datos cargados para", player.Name)
	else
		self.PlayerData[userId] = getDefaultData()
		print("📊 Nuevos datos creados para", player.Name)
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

	if success then
		print("💾 Datos guardados para", player.Name)
	else
		warn("❌ Error guardando datos de " .. player.Name .. ": " .. tostring(err))
	end
end

-- Limpiar datos al salir
function DataManager:PlayerRemoving(player)
	self:SavePlayerData(player)
	self.PlayerData[player.UserId] = nil
end

-- ============================================
-- REGISTRO DE PARTIDAS Y SCORES
-- ============================================

-- Registrar score de una partida
function DataManager:RecordGameScore(player, percentage, isWinner)
	if not player then return end

	local userId = player.UserId
	local data = self.PlayerData[userId]

	if not data then
		data = getDefaultData()
		self.PlayerData[userId] = data
	end

	-- Actualizar estadísticas del jugador
	data.TotalGames = (data.TotalGames or 0) + 1
	data.TotalPercentage = (data.TotalPercentage or 0) + percentage
	data.LastPlayed = os.time()

	-- Actualizar mejor porcentaje personal
	if percentage > (data.BestPercentage or 0) then
		data.BestPercentage = percentage
		print("🏆 ¡Nuevo récord personal para", player.Name, ":", string.format("%.1f%%", percentage))
	end

	-- Guardar datos del jugador
	self:SavePlayerData(player)

	-- Actualizar rankings en MemoryStore
	self:UpdateRankings(player, percentage)

	print("📊 Score registrado:", player.Name, "=", string.format("%.1f%%", percentage))
end

-- Registrar una victoria
function DataManager:RecordWin(player)
	if not player then return end

	local userId = player.UserId
	local data = self.PlayerData[userId]

	if data then
		data.TotalWins = (data.TotalWins or 0) + 1
		data.LastPlayed = os.time()
		print("🏆 Victoria registrada para", player.Name, "- Total:", data.TotalWins)
	end
end

-- ============================================
-- RANKINGS CON MEMORYSTORE (Reset automático)
-- ============================================

-- Actualizar rankings en MemoryStore
function DataManager:UpdateRankings(player, percentage)
	if not player or percentage <= 0 then return end

	-- Crear key única: nombre_timestamp para permitir múltiples entradas
	local uniqueKey = player.Name .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
	
	-- Datos a guardar
	local entryData = {
		PlayerName = player.Name,
		UserId = player.UserId,
		Percentage = percentage,
		Timestamp = os.time()
	}

	-- Guardar en ranking DIARIO (expira en 24h)
	pcall(function()
		DailyRankingMap:SetAsync(uniqueKey, entryData, DAILY_TTL)
	end)

	-- Guardar en ranking SEMANAL (expira en 7 días)
	pcall(function()
		WeeklyRankingMap:SetAsync(uniqueKey, entryData, WEEKLY_TTL)
	end)

	-- Invalidar cache para forzar actualización
	self.LastRankingUpdate = 0
end

-- Obtener ranking desde MemoryStore
local function GetRankingFromMemoryStore(sortedMap, count)
	local ranking = {}
	
	local success, result = pcall(function()
		-- GetRangeAsync obtiene items ordenados
		-- Usamos exclusiveBound para paginar si es necesario
		local items = sortedMap:GetRangeAsync(Enum.SortDirection.Ascending, count * 3) -- Pedimos más para filtrar
		return items
	end)

	if success and result then
		-- Extraer datos y ordenar por porcentaje
		local entries = {}
		for _, item in ipairs(result) do
			if item.value and item.value.PlayerName then
				table.insert(entries, {
					Name = item.value.PlayerName,
					Score = item.value.Percentage or 0,
					Timestamp = item.value.Timestamp or 0
				})
			end
		end

		-- Ordenar por porcentaje descendente
		table.sort(entries, function(a, b)
			return a.Score > b.Score
		end)

		-- Tomar solo los top N (sin duplicados de nombre, mostrar mejor score)
		local seenPlayers = {}
		for _, entry in ipairs(entries) do
			if not seenPlayers[entry.Name] and #ranking < count then
				seenPlayers[entry.Name] = true
				table.insert(ranking, entry)
			end
		end
	end

	return ranking
end

-- Obtener top scores diarios
function DataManager:GetDailyTopScores(count)
	count = count or 10

	-- Usar cache si es reciente
	local now = os.time()
	if now - self.LastRankingUpdate < self.RANKING_CACHE_TIME and #self.CachedDailyRanking > 0 then
		local result = {}
		for i = 1, math.min(count, #self.CachedDailyRanking) do
			table.insert(result, self.CachedDailyRanking[i])
		end
		return result
	end

	-- Obtener desde MemoryStore
	local ranking = GetRankingFromMemoryStore(DailyRankingMap, count)
	
	if #ranking > 0 then
		self.CachedDailyRanking = ranking
		self.LastRankingUpdate = now
	end

	return ranking
end

-- Obtener top scores semanales
function DataManager:GetWeeklyTopScores(count)
	count = count or 10

	-- Usar cache si es reciente
	local now = os.time()
	if now - self.LastRankingUpdate < self.RANKING_CACHE_TIME and #self.CachedWeeklyRanking > 0 then
		local result = {}
		for i = 1, math.min(count, #self.CachedWeeklyRanking) do
			table.insert(result, self.CachedWeeklyRanking[i])
		end
		return result
	end

	-- Obtener desde MemoryStore
	local ranking = GetRankingFromMemoryStore(WeeklyRankingMap, count)
	
	if #ranking > 0 then
		self.CachedWeeklyRanking = ranking
		self.LastRankingUpdate = now
	end

	return ranking
end

-- ============================================
-- ESTADÍSTICAS DEL JUGADOR
-- ============================================

-- Obtener estadísticas de un jugador
function DataManager:GetPlayerStats(player)
	if not player then return nil end
	
	local data = self.PlayerData[player.UserId]
	if not data then return nil end

	local avgPercentage = 0
	if data.TotalGames > 0 then
		avgPercentage = data.TotalPercentage / data.TotalGames
	end

	return {
		TotalWins = data.TotalWins or 0,
		TotalGames = data.TotalGames or 0,
		BestPercentage = data.BestPercentage or 0,
		AveragePercentage = avgPercentage,
		WinRate = data.TotalGames > 0 and (data.TotalWins / data.TotalGames * 100) or 0
	}
end

-- ============================================
-- FUNCIONES DE UTILIDAD
-- ============================================

-- Forzar actualización de cache de rankings
function DataManager:RefreshRankingCache()
	self.LastRankingUpdate = 0
	self:GetDailyTopScores(10)
	self:GetWeeklyTopScores(10)
	print("📊 Cache de rankings actualizado")
end

-- Obtener datos crudos de un jugador (para debug)
function DataManager:GetRawPlayerData(player)
	if not player then return nil end
	return self.PlayerData[player.UserId]
end

-- ============================================
-- INFORMACIÓN DE DEBUG
-- ============================================

print("📊 DataManager v4 cargado")
print("   - Rankings diarios: TTL = 24 horas (reset automático)")
print("   - Rankings semanales: TTL = 7 días (reset automático)")
print("   - Datos de jugador: Persistentes (DataStore)")

return DataManager
