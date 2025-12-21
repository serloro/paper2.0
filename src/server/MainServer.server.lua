--[[
    MainServer.lua
    Script principal del servidor
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local DataManager = require(ReplicatedStorage:WaitForChild("DataManager"))
local MatchManager = require(ReplicatedStorage:WaitForChild("MatchManager"))

local LobbyFolder = workspace:WaitForChild("Lobby")
local MatchesFolder = workspace:FindFirstChild("Matches") or Instance.new("Folder", workspace)
MatchesFolder.Name = "Matches"

local PlayerStates = {}

print("🎮 Pap3rBlox 3.0 - Servidor iniciado")

local function SendToLobby(player)
	PlayerStates[player] = GameState.PlayerState.IN_LOBBY

	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(Config.LOBBY_SPAWN_POSITION)
		end
	end

	print("✅", player.Name, "enviado al lobby")
end

Players.PlayerAdded:Connect(function(player)
	print("👤 Jugador conectado:", player.Name)
	DataManager:LoadPlayerData(player)

	player.CharacterAdded:Connect(function(character)
		wait(0.5)
		SendToLobby(player)
	end)

	if player.Character then
		SendToLobby(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	print("👋 Jugador desconectado:", player.Name)
	DataManager:PlayerRemoving(player)

	for i, queuedPlayer in ipairs(MatchManager.MatchmakingQueue) do
		if queuedPlayer == player then
			table.remove(MatchManager.MatchmakingQueue, i)
			break
		end
	end

	PlayerStates[player] = nil
end)

game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
	for _, match in ipairs(MatchManager.ActiveMatches) do
		match:Update(deltaTime)
	end
	MatchManager.CleanupFinishedMatches()
end)

local GetPlayerStateEvent = Instance.new("BindableFunction")
GetPlayerStateEvent.Name = "GetPlayerState"
GetPlayerStateEvent.Parent = ServerScriptService

GetPlayerStateEvent.OnInvoke = function(player)
	return PlayerStates[player]
end

local SendToLobbyEvent = Instance.new("BindableFunction")
SendToLobbyEvent.Name = "SendToLobby"
SendToLobbyEvent.Parent = ServerScriptService

SendToLobbyEvent.OnInvoke = function(player)
	SendToLobby(player)
	return true
end

print("🚀 Sistema principal inicializado")