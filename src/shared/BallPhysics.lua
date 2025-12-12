--[[
    BallPhysics.lua
    Bolas con PINCHOS que rebotan en el mapa
    Si te tocan, mueres
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local BallPhysics = {}
BallPhysics.__index = BallPhysics

-- Crear bola con pinchos
function BallPhysics.new(matchFolder, position, mapBasePosition, mapSize)
	local self = setmetatable({}, BallPhysics)

	-- Guardar límites del mapa
	self.MapBasePosition = mapBasePosition or Vector3.new(0, 0, 0)
	self.MapSize = mapSize or Config.MAP_SIZE

	-- Modelo contenedor
	local model = Instance.new("Model")
	model.Name = "SpikeBall"
	model.Parent = matchFolder

	-- Bola central
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(Config.BALL_RADIUS * 2, Config.BALL_RADIUS * 2, Config.BALL_RADIUS * 2)
	ball.Position = position
	ball.Material = Enum.Material.Metal
	ball.Color = Color3.fromRGB(50, 50, 60)
	ball.Anchored = true
	ball.CanCollide = false
	ball.Parent = model

	-- Brillo interior (rojo peligroso)
	local innerGlow = Instance.new("Part")
	innerGlow.Name = "InnerGlow"
	innerGlow.Shape = Enum.PartType.Ball
	innerGlow.Size = Vector3.new(Config.BALL_RADIUS * 1.5, Config.BALL_RADIUS * 1.5, Config.BALL_RADIUS * 1.5)
	innerGlow.Position = position
	innerGlow.Material = Enum.Material.Neon
	innerGlow.Color = Color3.fromRGB(255, 50, 50)
	innerGlow.Transparency = 0.3
	innerGlow.Anchored = true
	innerGlow.CanCollide = false
	innerGlow.Parent = model

	-- Luz peligrosa
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 50)
	light.Brightness = 2
	light.Range = 15
	light.Parent = ball

	-- Crear PINCHOS
	local numSpikes = 12
	local spikeLength = Config.BALL_RADIUS * 0.8

	for i = 1, numSpikes do
		local phi = math.acos(1 - 2 * (i - 0.5) / numSpikes)
		local theta = math.pi * (1 + math.sqrt(5)) * i

		local x = math.sin(phi) * math.cos(theta)
		local y = math.cos(phi)
		local z = math.sin(phi) * math.sin(theta)

		local direction = Vector3.new(x, y, z).Unit
		local spikePos = position + direction * Config.BALL_RADIUS

		-- Pincho
		local spike = Instance.new("Part")
		spike.Name = "Spike" .. i
		spike.Size = Vector3.new(0.5, spikeLength, 0.5)
		spike.Position = spikePos + direction * (spikeLength / 2)
		spike.Material = Enum.Material.Metal
		spike.Color = Color3.fromRGB(80, 80, 90)
		spike.Anchored = true
		spike.CanCollide = false
		spike.Parent = model
		spike.CFrame = CFrame.lookAt(spikePos, spikePos + direction) * CFrame.Angles(math.rad(90), 0, 0)

		-- Punta brillante
		local tip = Instance.new("Part")
		tip.Name = "SpikeTip" .. i
		tip.Size = Vector3.new(0.3, 0.4, 0.3)
		tip.Position = spikePos + direction * spikeLength
		tip.Material = Enum.Material.Neon
		tip.Color = Color3.fromRGB(255, 100, 100)
		tip.Anchored = true
		tip.CanCollide = false
		tip.Parent = model
		tip.CFrame = CFrame.lookAt(tip.Position, tip.Position + direction) * CFrame.Angles(math.rad(90), 0, 0)
	end

	self.Model = model
	self.Ball = ball
	self.InnerGlow = innerGlow
	self.Position = position
	self.NumSpikes = numSpikes

	-- Velocidad aleatoria
	self.Velocity = Vector3.new(
		math.random(-1, 1) == 0 and 1 or math.random(-1, 1),
		0,
		math.random(-1, 1) == 0 and 1 or math.random(-1, 1)
	).Unit * Config.BALL_SPEED

	self.RotationSpeed = Vector3.new(
		math.random(-3, 3),
		math.random(-3, 3),
		math.random(-3, 3)
	)

	self.CurrentRotation = CFrame.new()

	-- Animación de pulso
	task.spawn(function()
		while self.Ball and self.Ball.Parent do
			TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 3}):Play()
			wait(0.5)
			if not self.Ball or not self.Ball.Parent then break end
			TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 1}):Play()
			wait(0.5)
		end
	end)

	return self
end

-- Actualizar física
function BallPhysics:Update(deltaTime, boundaries)
	if not self.Ball or not self.Ball.Parent then return end

	local currentPos = self.Position
	local newPos = currentPos + (self.Velocity * deltaTime)

	-- Límites del mapa (relativos a MapBasePosition)
	local halfSize = self.MapSize / 2 - 5
	local minX = self.MapBasePosition.X - halfSize
	local maxX = self.MapBasePosition.X + halfSize
	local minZ = self.MapBasePosition.Z - halfSize
	local maxZ = self.MapBasePosition.Z + halfSize

	-- Rebotar en bordes
	if newPos.X < minX or newPos.X > maxX then
		self.Velocity = Vector3.new(-self.Velocity.X, self.Velocity.Y, self.Velocity.Z)
		newPos = Vector3.new(math.clamp(newPos.X, minX, maxX), newPos.Y, newPos.Z)
	end

	if newPos.Z < minZ or newPos.Z > maxZ then
		self.Velocity = Vector3.new(self.Velocity.X, self.Velocity.Y, -self.Velocity.Z)
		newPos = Vector3.new(newPos.X, newPos.Y, math.clamp(newPos.Z, minZ, maxZ))
	end

	-- Mantener altura constante
	newPos = Vector3.new(newPos.X, self.MapBasePosition.Y + 3, newPos.Z)

	-- Actualizar rotación
	self.CurrentRotation = self.CurrentRotation * CFrame.Angles(
		self.RotationSpeed.X * deltaTime,
		self.RotationSpeed.Y * deltaTime,
		self.RotationSpeed.Z * deltaTime
	)

	self.Position = newPos
	self:UpdateModelPosition()
end

-- Actualizar posición del modelo
function BallPhysics:UpdateModelPosition()
	if not self.Model or not self.Model.Parent then return end

	local pos = self.Position
	local rot = self.CurrentRotation

	-- Bola central
	if self.Ball then
		self.Ball.CFrame = CFrame.new(pos) * rot
	end

	-- Brillo interior
	if self.InnerGlow then
		self.InnerGlow.CFrame = CFrame.new(pos) * rot
	end

	-- Pinchos
	for i = 1, self.NumSpikes do
		local spike = self.Model:FindFirstChild("Spike" .. i)
		local tip = self.Model:FindFirstChild("SpikeTip" .. i)

		if spike then
			local phi = math.acos(1 - 2 * (i - 0.5) / self.NumSpikes)
			local theta = math.pi * (1 + math.sqrt(5)) * i

			local x = math.sin(phi) * math.cos(theta)
			local y = math.cos(phi)
			local z = math.sin(phi) * math.sin(theta)

			local direction = (rot * CFrame.new(Vector3.new(x, y, z))).Position.Unit
			local spikePos = pos + direction * Config.BALL_RADIUS
			local spikeLength = Config.BALL_RADIUS * 0.8

			spike.CFrame = CFrame.lookAt(spikePos, spikePos + direction) * CFrame.Angles(math.rad(90), 0, 0)
			spike.Position = spikePos + direction * (spikeLength / 2)

			if tip then
				tip.CFrame = CFrame.lookAt(spikePos + direction * spikeLength, spikePos + direction * (spikeLength + 1)) * CFrame.Angles(math.rad(90), 0, 0)
				tip.Position = spikePos + direction * spikeLength
			end
		end
	end
end

-- Comprobar colisión con jugador
function BallPhysics:CheckPlayerCollision(playerPosition)
	if not self.Ball or not self.Ball.Parent then return false end

	local distance = (self.Position - playerPosition).Magnitude
	local collisionRadius = Config.BALL_RADIUS + (Config.BALL_RADIUS * 0.8) + 2
	return distance <= collisionRadius
end

-- Destruir
function BallPhysics:Destroy()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	self.Ball = nil
	self.InnerGlow = nil
end

return BallPhysics
