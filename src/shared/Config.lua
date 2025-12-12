--[[
    Config.lua
    Configuración global del juego
]]

local Config = {}

-- Configuración de partidas
Config.MAX_PLAYERS_PER_MATCH = 8
Config.MIN_PLAYERS_TO_START = 2
Config.MATCHMAKING_TIMEOUT = 30
Config.MATCH_COUNTDOWN = 5
Config.MATCH_DURATION = 60
Config.RESPAWN_TIME = 3

-- Configuración del mapa
Config.MAP_SIZE = 200
Config.PLAYER_CIRCLE_RADIUS = 10
Config.PLATFORM_HEIGHT = 2
Config.LINE_WIDTH = 0.5
Config.LINE_HEIGHT = 1.5

-- Configuración de bolas
Config.NUM_BALLS = 5
Config.BALL_RADIUS = 3
Config.BALL_SPEED = 30
Config.BALL_DAMAGE_PLAYERS = true

-- Configuración de jugadores
Config.PLAYER_SPEED = 16
Config.PLAYER_COLORS = {
	Color3.fromRGB(255, 50, 50),
	Color3.fromRGB(50, 150, 255),
	Color3.fromRGB(50, 255, 50),
	Color3.fromRGB(255, 255, 50),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(200, 50, 255),
	Color3.fromRGB(50, 255, 255),
	Color3.fromRGB(255, 50, 200),
}

-- Configuración de bots
Config.BOT_ENABLED = true
Config.BOT_UPDATE_INTERVAL = 0.5
Config.BOT_MAX_LINE_LENGTH = 30
Config.BOT_THINK_DELAY = 1

-- Configuración de puntuaciones
Config.POINTS_PER_WIN = 100
Config.POINTS_PER_AREA = 10
Config.POINTS_PER_ELIMINATION = 50

-- Posiciones en el Lobby
Config.LOBBY_SPAWN_POSITION = Vector3.new(0, 5, 130)
Config.NORMAL_PORTAL_POSITION = Vector3.new(-20, 5, 0)
Config.DEBUG_PORTAL_POSITION = Vector3.new(20, 5, 0)

return Config
