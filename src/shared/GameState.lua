--[[
    GameState.lua
    Módulo para gestionar el estado del juego (enums y constantes)
]]

local GameState = {}

-- Estados de partida
GameState.MatchState = {
	WAITING = "Waiting",
	COUNTDOWN = "Countdown",
	PLAYING = "Playing",
	ENDED = "Ended"
}

-- Estados de jugador
GameState.PlayerState = {
	IN_LOBBY = "InLobby",
	IN_MATCHMAKING = "InMatchmaking",
	IN_GAME = "InGame",
	SPECTATING = "Spectating",
	DEAD = "Dead"
}

-- Tipos de portal
GameState.PortalType = {
	NORMAL = "Normal",
	DEBUG = "Debug"
}

-- Tipos de zona
GameState.ZoneType = {
	SAFE = "Safe",      -- Zona propia del jugador
	NEUTRAL = "Neutral", -- Zona sin reclamar
	LINE = "Line"       -- Línea en construcción
}

return GameState
