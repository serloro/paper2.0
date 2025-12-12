--[[
    ClientController.lua (LocalScript)
    Script del cliente que maneja la experiencia del jugador
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Esperar a que GameUI esté disponible
repeat task.wait() until _G.GameUI
local GameUI = _G.GameUI

print("🎮 ClientController iniciado para", player.Name)

-- Función para manejar la muerte del jugador
local function HandleDeath()
	print("🎮 [ClientController] Jugador murió")

	-- Solo mostrar mensaje si el HUD está activo (está en partida)
	if GameUI.IsActive and GameUI.IsActive() then
		GameUI.ShowMessage("¡HAS SIDO ELIMINADO!", 3, Color3.fromRGB(255, 50, 50))
		GameUI.SetStatus("ELIMINADO", Color3.fromRGB(255, 50, 50))

		-- Ocultar HUD después de mostrar el mensaje
		task.delay(3, function()
			print("🎮 [ClientController] Ocultando HUD después de muerte")
			if GameUI.Finalize then
				GameUI.Finalize()
			end
		end)
	end
end

-- Detectar cuando el personaje muere
local humanoid = character:WaitForChild("Humanoid")
humanoid.Died:Connect(HandleDeath)

-- Detectar cuando el personaje reaparece
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	local newHumanoid = character:WaitForChild("Humanoid")
	newHumanoid.Died:Connect(HandleDeath)
end)

print("✅ ClientController configurado")
