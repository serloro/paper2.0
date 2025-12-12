--[[
    MatchmakingService.lua
    Servicio de matchmaking que conecta jugadores y crea partidas
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Cargar módulos
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local MatchManager = require(ReplicatedStorage:WaitForChild("MatchManager"))

-- Esperar a que MatchController esté disponible
local MatchController = require(ServerScriptService:WaitForChild("MatchController"))

local MatchmakingService = {}

-- Actualizar matchmaking periódicamente
game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
    -- Comprobar si hay suficientes jugadores en cola para crear partida
    if #MatchManager.MatchmakingQueue >= Config.MIN_PLAYERS_TO_START then
        local match = MatchManager.CreateNormalMatch()
        
        if match then
            print("🎮 Creando partida normal con", #match.Players, "jugadores")
            
            -- Crear controlador de partida
            local createMatch = ServerScriptService:FindFirstChild("CreateMatchController")
            if createMatch then
                createMatch:Invoke(match)
            end
        end
    end
end)

print("🔄 MatchmakingService inicializado")

return MatchmakingService

