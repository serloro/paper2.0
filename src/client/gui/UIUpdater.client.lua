--[[
    UIUpdater.client.lua
    Escucha eventos del servidor y actualiza la UI
    Con LOGS de depuración
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("📡 [UIUpdater] Iniciando para", player.Name)

-- Esperar a que GameUI esté disponible
local waitCount = 0
repeat 
	task.wait(0.1) 
	waitCount = waitCount + 1
	if waitCount % 10 == 0 then
		print("📡 [UIUpdater] Esperando GameUI...", waitCount * 0.1, "segundos")
	end
until _G.GameUI or waitCount > 100

if not _G.GameUI then
	warn("📡 [UIUpdater] ERROR: GameUI no se cargó después de 10 segundos")
	return
end

local GameUI = _G.GameUI
print("📡 [UIUpdater] GameUI encontrado!")

-- Esperar eventos remotos
local RemotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
if not RemotesFolder then
	warn("📡 [UIUpdater] ERROR: No se encontró RemoteEvents")
	return
end

print("📡 [UIUpdater] RemoteEvents encontrado!")

-- Listar eventos disponibles
print("📡 [UIUpdater] Eventos disponibles:")
for _, child in ipairs(RemotesFolder:GetChildren()) do
	print("   -", child.Name, "(" .. child.ClassName .. ")")
end

-- ========================================
-- ESTADO DEL JUGADOR EN LA PARTIDA
-- ========================================
local wasEliminatedThisMatch = false

-- ========================================
-- CONFIGURAR LISTENERS
-- ========================================

local function SetupEventListeners()
	print("📡 [UIUpdater] Configurando listeners...")

	-- ========================================
	-- EVENTO: INICIALIZAR JUEGO
	-- ========================================
	local initializeGame = RemotesFolder:FindFirstChild("InitializeGame")
	if initializeGame then
		print("📡 [UIUpdater] ✅ InitializeGame encontrado")
		initializeGame.OnClientEvent:Connect(function(initialData)
			print("📡 [UIUpdater] >>> RECIBIDO InitializeGame <<<")
			print("📡 [UIUpdater] Datos iniciales:", initialData and "sí" or "no")

			-- Reset elimination flag for new match
			wasEliminatedThisMatch = false

			GameUI.Initialize()

			if initialData then
				if initialData.timer then 
					print("📡 [UIUpdater] Timer inicial:", initialData.timer)
					GameUI.SetTimer(initialData.timer) 
				end
				if initialData.players then 
					print("📡 [UIUpdater] Jugadores inicial:", initialData.players)
					GameUI.SetAliveCount(initialData.players) 
				end
			end
		end)
	else
		warn("📡 [UIUpdater] ❌ InitializeGame NO encontrado")
	end

	-- ========================================
	-- EVENTO: FINALIZAR JUEGO
	-- ========================================
	local finalizeGame = RemotesFolder:FindFirstChild("FinalizeGame")
	if finalizeGame then
		print("📡 [UIUpdater] ✅ FinalizeGame encontrado")
		finalizeGame.OnClientEvent:Connect(function()
			print("📡 [UIUpdater] >>> RECIBIDO FinalizeGame <<<")
			-- Reset elimination flag when match ends
			wasEliminatedThisMatch = false
			GameUI.Finalize()
		end)
	else
		warn("📡 [UIUpdater] ❌ FinalizeGame NO encontrado")
	end

	-- ========================================
	-- EVENTO: ShowGameUI (legacy)
	-- ========================================
	local showGameUI = RemotesFolder:FindFirstChild("ShowGameUI")
	if showGameUI then
		print("📡 [UIUpdater] ✅ ShowGameUI encontrado")
		showGameUI.OnClientEvent:Connect(function()
			print("📡 [UIUpdater] >>> RECIBIDO ShowGameUI <<<")
			GameUI.Initialize()
		end)
	end

	-- ========================================
	-- EVENTO: HideGameUI (legacy)
	-- ========================================
	local hideGameUI = RemotesFolder:FindFirstChild("HideGameUI")
	if hideGameUI then
		print("📡 [UIUpdater] ✅ HideGameUI encontrado")
		hideGameUI.OnClientEvent:Connect(function()
			print("📡 [UIUpdater] >>> RECIBIDO HideGameUI <<<")
			GameUI.Finalize()
		end)
	end

	-- ========================================
	-- ACTUALIZACIÓN DE TIMER
	-- ========================================
	local updateTimer = RemotesFolder:FindFirstChild("UpdateTimer")
	if updateTimer then
		updateTimer.OnClientEvent:Connect(function(timeRemaining)
			GameUI.SetTimer(timeRemaining)
		end)
	end

	-- ========================================
	-- ACTUALIZACIÓN DE ÁREA
	-- ========================================
	local updateAreaPercentage = RemotesFolder:FindFirstChild("UpdateAreaPercentage")
	if updateAreaPercentage then
		updateAreaPercentage.OnClientEvent:Connect(function(percentage)
			GameUI.SetAreaPercentage(percentage)
		end)
	end

	-- ========================================
	-- ACTUALIZACIÓN DE JUGADORES VIVOS
	-- ========================================
	local updateAliveCount = RemotesFolder:FindFirstChild("UpdateAliveCount")
	if updateAliveCount then
		print("📡 [UIUpdater] ✅ UpdateAliveCount encontrado")
		updateAliveCount.OnClientEvent:Connect(function(count)
			print("📡 [UIUpdater] >>> RECIBIDO UpdateAliveCount:", count, "<<<")
			GameUI.SetAliveCount(count)
		end)
	else
		warn("📡 [UIUpdater] ❌ UpdateAliveCount NO encontrado")
	end

	-- ========================================
	-- ACTUALIZACIÓN DE ZONA
	-- ========================================
	local updateZoneStatus = RemotesFolder:FindFirstChild("UpdateZoneStatus")
	if updateZoneStatus then
		updateZoneStatus.OnClientEvent:Connect(function(isInSafe, isTracing)
			GameUI.SetZoneStatus(isInSafe, isTracing)
		end)
	end

	-- ========================================
	-- PARTIDA TERMINADA
	-- ========================================
	local matchEnded = RemotesFolder:FindFirstChild("MatchEnded")
	if matchEnded then
		print("📡 [UIUpdater] ✅ MatchEnded encontrado")
		matchEnded.OnClientEvent:Connect(function(winnerName, isWinner, position, totalPlayers)
			print("📡 [UIUpdater] >>> RECIBIDO MatchEnded <<<")
			print("📡 [UIUpdater] Winner:", winnerName, "IsWinner:", isWinner, "Pos:", position)
			print("📡 [UIUpdater] wasEliminatedThisMatch:", wasEliminatedThisMatch)
			print("📡 [UIUpdater] GameUI.isActive:", GameUI.isActive)

			-- If player was already eliminated, don't show end message
			if wasEliminatedThisMatch then
				print("📡 [UIUpdater] Player was eliminated, ignoring MatchEnded message")
				wasEliminatedThisMatch = false  -- Reset for next match
				return
			end

			-- If GameUI is not active (player in lobby), ignore
			if not GameUI.isActive then
				print("📡 [UIUpdater] GameUI not active, ignoring MatchEnded message")
				return
			end

			local posText = position and tostring(position) or "?"
			local totalText = totalPlayers and tostring(totalPlayers) or "8"

			if isWinner then
				GameUI.ShowMessage("🏆 WINNER!! 🏆\n#1 / " .. totalText, 5, Color3.fromRGB(255, 215, 0))
			else
				local msg = "#" .. posText .. " / " .. totalText
				if position and position <= 3 then
					GameUI.ShowMessage("🥈 " .. msg .. "\nGood job!", 5, Color3.fromRGB(200, 200, 255))
				else
					GameUI.ShowMessage(msg .. "\nWinner: " .. (winnerName or "None"), 5, Color3.fromRGB(255, 150, 100))
				end
			end

			-- Finalizar UI después de mostrar resultado
			task.delay(5, function()
				print("📡 [UIUpdater] Finalizando UI después de MatchEnded")
				GameUI.Finalize()
			end)
		end)
	end

	-- ========================================
	-- JUGADOR ELIMINADO
	-- ========================================
	local playerEliminated = RemotesFolder:FindFirstChild("PlayerEliminated")
	if playerEliminated then
		print("📡 [UIUpdater] ✅ PlayerEliminated encontrado")
		playerEliminated.OnClientEvent:Connect(function(victimName, killerName)
			print("📡 [UIUpdater] >>> RECIBIDO PlayerEliminated:", victimName, "<<<")
			if victimName == player.Name then
				-- Mark as eliminated so we don't show end match message
				wasEliminatedThisMatch = true
				print("📡 [UIUpdater] wasEliminatedThisMatch set to TRUE")

				local msg = killerName and ("💀 " .. killerName .. " eliminated you!") or "💀 ELIMINATED!"
				GameUI.ShowMessage(msg, 3, Color3.fromRGB(255, 50, 50))

				task.delay(3, function()
					print("📡 [UIUpdater] Finalizando UI después de eliminación")
					wasEliminatedThisMatch = false  -- Reset after finalize
					GameUI.Finalize()
				end)
			end
		end)
	end

	-- ========================================
	-- COUNTDOWN
	-- ========================================
	local showCountdown = RemotesFolder:FindFirstChild("ShowCountdown")
	if showCountdown then
		showCountdown.OnClientEvent:Connect(function(count)
			if count > 0 then
				GameUI.ShowMessage(tostring(count), 1, Color3.fromRGB(255, 255, 100))
			else
				GameUI.ShowMessage("GO!", 1, Color3.fromRGB(100, 255, 100))
			end
		end)
	end
end

-- ========================================
-- INICIALIZACIÓN
-- ========================================

SetupEventListeners()

-- La UI empieza oculta
GameUI.Finalize()

print("📡 [UIUpdater] Inicializado completamente")
