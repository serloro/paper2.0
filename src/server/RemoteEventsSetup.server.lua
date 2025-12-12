--[[
    RemoteEventsSetup.lua
    Configuración de eventos remotos para comunicación cliente-servidor
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crear carpeta para eventos remotos
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "RemoteEvents"
	RemotesFolder.Parent = ReplicatedStorage
end

-- Eventos del cliente al servidor
local function CreateRemoteEvent(name)
	local existing = RemotesFolder:FindFirstChild(name)
	if existing then return existing end

	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = RemotesFolder
	return remoteEvent
end

local function CreateRemoteFunction(name)
	local existing = RemotesFolder:FindFirstChild(name)
	if existing then return existing end

	local remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = RemotesFolder
	return remoteFunction
end

-- Crear eventos
local PlayerJoinedMatch = CreateRemoteEvent("PlayerJoinedMatch")
local PlayerLeftMatch = CreateRemoteEvent("PlayerLeftMatch")
local PlayerEliminated = CreateRemoteEvent("PlayerEliminated")
local MatchStarted = CreateRemoteEvent("MatchStarted")
local MatchEnded = CreateRemoteEvent("MatchEnded")
local TerritoryUpdated = CreateRemoteEvent("TerritoryUpdated")
local UpdateAliveCount = CreateRemoteEvent("UpdateAliveCount")
local UpdateZoneStatus = CreateRemoteEvent("UpdateZoneStatus")
local UpdateAreaPercentage = CreateRemoteEvent("UpdateAreaPercentage")
local UpdateTimer = CreateRemoteEvent("UpdateTimer")
local ShowCountdown = CreateRemoteEvent("ShowCountdown")
local ShowGameUI = CreateRemoteEvent("ShowGameUI")
local HideGameUI = CreateRemoteEvent("HideGameUI")
local ResetGameUI = CreateRemoteEvent("ResetGameUI")
local InitializeGame = CreateRemoteEvent("InitializeGame")
local FinalizeGame = CreateRemoteEvent("FinalizeGame")

-- Funciones remotas
local GetMatchInfo = CreateRemoteFunction("GetMatchInfo")

print("📡 Eventos remotos configurados")

return {
	PlayerJoinedMatch = PlayerJoinedMatch,
	PlayerLeftMatch = PlayerLeftMatch,
	PlayerEliminated = PlayerEliminated,
	MatchStarted = MatchStarted,
	MatchEnded = MatchEnded,
	TerritoryUpdated = TerritoryUpdated,
	UpdateAliveCount = UpdateAliveCount,
	UpdateZoneStatus = UpdateZoneStatus,
	UpdateAreaPercentage = UpdateAreaPercentage,
	UpdateTimer = UpdateTimer,
	ShowCountdown = ShowCountdown,
	ShowGameUI = ShowGameUI,
	HideGameUI = HideGameUI,
	ResetGameUI = ResetGameUI,
	InitializeGame = InitializeGame,
	FinalizeGame = FinalizeGame,
	GetMatchInfo = GetMatchInfo
}

