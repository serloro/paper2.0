--[[
    MatchManager.lua
    Gestión de partidas, matchmaking y estado de juego
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("GameState"))

local MatchManager = {}
MatchManager.__index = MatchManager

-- Lista de partidas activas
MatchManager.ActiveMatches = {}
MatchManager.MatchmakingQueue = {} -- Cola de jugadores esperando partida normal
MatchManager.NextMatchId = 1

-- Crear nueva instancia de partida
function MatchManager.new(matchId, isDebugMode)
	local self = setmetatable({}, MatchManager)

	self.MatchId = matchId
	self.IsDebugMode = isDebugMode or false
	self.State = GameState.MatchState.WAITING
	self.Players = {}
	self.Bots = {}
	self.AlivePlayers = {}
	self.StartTime = 0
	self.CountdownTime = Config.MATCH_COUNTDOWN
	self.WaitTime = 0

	return self
end

-- Añadir jugador a la partida
function MatchManager:AddPlayer(player)
	if #self.Players >= Config.MAX_PLAYERS_PER_MATCH then
		return false
	end

	table.insert(self.Players, player)
	table.insert(self.AlivePlayers, player)

	return true
end

-- Crear bots para completar la partida
function MatchManager:CreateBots()
	local numBotsNeeded = Config.MAX_PLAYERS_PER_MATCH - #self.Players

	for i = 1, numBotsNeeded do
		local bot = {
			Name = "Bot_" .. i,
			IsBot = true,
			Color = Config.PLAYER_COLORS[(#self.Players + i)],
			Position = Vector3.new(0, 0, 0),
			CurrentZone = nil,
			IsTracing = false,
			TracePath = {}
		}

		table.insert(self.Bots, bot)
		table.insert(self.AlivePlayers, bot)
	end
end

-- Iniciar cuenta atrás
function MatchManager:StartCountdown()
	self.State = GameState.MatchState.COUNTDOWN
	self.CountdownTime = Config.MATCH_COUNTDOWN
end

-- Iniciar partida
function MatchManager:StartMatch()
	self.State = GameState.MatchState.PLAYING
	self.StartTime = tick()

	-- Si es modo debug, crear bots
	if self.IsDebugMode then
		self:CreateBots()
	end
end

-- Finalizar partida
function MatchManager:EndMatch(winner)
	self.State = GameState.MatchState.ENDED
	self.Winner = winner
end

-- Eliminar jugador
function MatchManager:EliminatePlayer(player)
	for i, alivePlayer in ipairs(self.AlivePlayers) do
		if alivePlayer == player then
			table.remove(self.AlivePlayers, i)
			break
		end
	end

	-- Comprobar si solo queda un jugador
	if #self.AlivePlayers <= 1 then
		local winner = self.AlivePlayers[1]
		self:EndMatch(winner)
	end
end

-- Actualizar estado de la partida
function MatchManager:Update(deltaTime)
	if self.State == GameState.MatchState.WAITING then
		self.WaitTime = self.WaitTime + deltaTime

		-- Comprobar si hay suficientes jugadores o se acabó el tiempo de espera
		local canStart = #self.Players >= Config.MIN_PLAYERS_TO_START or 
			(self.WaitTime >= Config.MATCHMAKING_TIMEOUT and #self.Players > 0)

		if canStart then
			self:StartCountdown()
		end

	elseif self.State == GameState.MatchState.COUNTDOWN then
		self.CountdownTime = self.CountdownTime - deltaTime

		if self.CountdownTime <= 0 then
			self:StartMatch()
		end
	end
end

-- Gestión del matchmaking global
function MatchManager.AddToMatchmaking(player)
	table.insert(MatchManager.MatchmakingQueue, player)

	-- Intentar crear partida si hay suficientes jugadores
	if #MatchManager.MatchmakingQueue >= Config.MIN_PLAYERS_TO_START then
		MatchManager.CreateNormalMatch()
	end
end

function MatchManager.CreateNormalMatch(players, botsNeeded)
	local match = MatchManager.new(MatchManager.NextMatchId, false)
	MatchManager.NextMatchId = MatchManager.NextMatchId + 1

	-- Si se pasan jugadores directamente, usarlos
	if players and #players > 0 then
		for _, player in ipairs(players) do
			match:AddPlayer(player)
		end

		-- Crear bots si se especifican
		if botsNeeded and botsNeeded > 0 then
			for i = 1, botsNeeded do
				local bot = {
					Name = "Bot_" .. i,
					IsBot = true,
					Color = Config.PLAYER_COLORS[(#match.Players + i)],
					Position = Vector3.new(0, 0, 0),
					CurrentZone = nil,
					IsTracing = false,
					TracePath = {}
				}
				table.insert(match.Bots, bot)
				table.insert(match.AlivePlayers, bot)
			end
		end

		match:StartMatch()
	else
		-- Modo antiguo: usar cola de matchmaking
		while #MatchManager.MatchmakingQueue > 0 and #match.Players < Config.MAX_PLAYERS_PER_MATCH do
			local player = table.remove(MatchManager.MatchmakingQueue, 1)
			match:AddPlayer(player)
		end
	end

	table.insert(MatchManager.ActiveMatches, match)
	return match
end

function MatchManager.CreateDebugMatch(player)
	local match = MatchManager.new(MatchManager.NextMatchId, true)
	MatchManager.NextMatchId = MatchManager.NextMatchId + 1

	match:AddPlayer(player)
	match:StartMatch() -- Iniciar inmediatamente

	table.insert(MatchManager.ActiveMatches, match)
	return match
end

-- Obtener partida de un jugador
function MatchManager.GetPlayerMatch(player)
	for _, match in ipairs(MatchManager.ActiveMatches) do
		for _, matchPlayer in ipairs(match.Players) do
			if matchPlayer == player then
				return match
			end
		end
	end
	return nil
end

-- Limpiar partidas terminadas
function MatchManager.CleanupFinishedMatches()
	for i = #MatchManager.ActiveMatches, 1, -1 do
		local match = MatchManager.ActiveMatches[i]
		if match.State == GameState.MatchState.ENDED then
			table.remove(MatchManager.ActiveMatches, i)
		end
	end
end

return MatchManager

