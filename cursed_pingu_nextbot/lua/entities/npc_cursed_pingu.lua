
AddCSLuaFile()

ENT.Base = "base_nextbot"
-- v (Stuff you can customize) v
-- lines ~36-54: attack distance, and attack power
-- line ~416: acceleration
-- lines ~504-524: damage setup

-- I made every sound ENT a table so you could add more than one sound each. I wouldn't try chaseMusic, because I don't know what will happen.
-- you can also use ctrl+f to search for the terms listed above.
ENT.PhysgunDisabled = true
ENT.AutomaticFrameAdvance = false
-- REMINDER: sounds MUST be at a bitrate of 44100 HZ. If they are not, then the sound will not play.
ENT.JumpSound = {
	Sound("npc_cursed_pingu/pingu_voice_11.mp3")
}
ENT.JumpHighSound = {
	Sound("npc_cursed_pingu/pingu_voice_11.mp3")
}
ENT.TauntSounds = {
	Sound("npc_cursed_pingu/noot_noot.mp3"),
	Sound("npc_cursed_pingu/noot_noot_loud.mp3"),
}
ENT.ChaseSounds = {
	Sound("npc_cursed_pingu/pingu_voice_1.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_2.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_3.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_4.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_5.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_6.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_7.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_8.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_9.mp3"),
	Sound("npc_cursed_pingu/pingu_voice_10.mp3"),
}
local chaseMusic = Sound("npc_cursed_pingu/earthquake.mp3")
local walkingMusic = Sound("npc_cursed_pingu/pingu_walk_loop.wav")

local workshopID = "2834879791"

local IsValid = IsValid

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "Raging" )
	self:NetworkVar( "Bool", 1, "Moving" )
	if ( SERVER ) then
		self:SetRaging( false )
		self:SetMoving( false )
	end
end

local REPEAT_FOREVER = 0

if SERVER then -- SERVER --

local npc_cursed_pingu_acquire_distance =
	CreateConVar("npc_cursed_pingu_acquire_distance", 100000, FCVAR_NONE,
	"The maximum distance at which Cursed Pingu will chase a target.")

local npc_cursed_pingu_spawn_protect =
	CreateConVar("npc_cursed_pingu_spawn_protect", 1, FCVAR_NONE,
	"If set to 1, Cursed Pingu will not target players or hide within 200 units of \z
	a spawn point.")

local npc_cursed_pingu_attack_distance =
	CreateConVar("npc_cursed_pingu_attack_distance", 80, FCVAR_NONE,
	"The reach of Cursed Pingu's attack.")

local npc_cursed_pingu_attack_interval =
	CreateConVar("npc_cursed_pingu_attack_interval", 0.2, FCVAR_NONE,
	"The delay between Cursed Pingu's attacks.")

local npc_cursed_pingu_attack_force =
	CreateConVar("npc_cursed_pingu_attack_force", 800, FCVAR_NONE,
	"The physical force of Cursed Pingu's attack. Higher values throw things \z
	farther.")

local npc_cursed_pingu_smash_props =
	CreateConVar("npc_cursed_pingu_smash_props", 1, FCVAR_NONE,
	"If set to 1, Cursed Pingu will punch through any props placed in their way.")

local npc_cursed_pingu_allow_jump =
	CreateConVar("npc_cursed_pingu_allow_jump", 1, FCVAR_NONE,
	"If set to 1, Cursed Pingu will be able to jump.")

local npc_cursed_pingu_hiding_scan_interval =
	CreateConVar("npc_cursed_pingu_hiding_scan_interval", 3, FCVAR_NONE,
	"Cursed Pingu will only seek out hiding places every X seconds. This can be an \z
	expensive operation, so it is not recommended to lower this too much. \z
	However, if distant Cursed Pingus are not hiding from you quickly enough, you \z
	may consider lowering this a small amount.")

local npc_cursed_pingu_hiding_repath_interval =
	CreateConVar("npc_cursed_pingu_hiding_repath_interval", 1, FCVAR_NONE,
	"The path to Cursed Pingu's hiding spot will be redetermined every X seconds.")

local npc_cursed_pingu_chase_repath_interval =
	CreateConVar("npc_cursed_pingu_chase_repath_interval", 0.1, FCVAR_NONE,
	"The path to and position of Cursed Pingu's target will be redetermined every \z
	X seconds.")

local npc_cursed_pingu_expensive_scan_interval =
	CreateConVar("npc_cursed_pingu_expensive_scan_interval", 1, FCVAR_NONE,
	"Slightly expensive operations (distance calculations and entity \z
	searching) will occur every X seconds.")

local npc_cursed_pingu_force_download =
	CreateConVar("npc_cursed_pingu_force_download", 1, FCVAR_ARCHIVE,
	"If set to 1, clients will be forced to download Cursed Pingu resources \z
	(restart required after changing).\n\z
	WARNING: If this option is disabled, clients will be unable to see or \z
	hear Cursed Pingu!")

 -- So we don't spam voice TOO much.
local TAUNT_INTERVAL = 2
local PATH_INFRACTION_TIMEOUT = 5
local CHASE_SOUND_INTERVAL = 8
local SPEED_THRESHOLD = 1
local SPEED_THRESHOLD_SQUARED = SPEED_THRESHOLD * SPEED_THRESHOLD
local SPAWN_PROTECTION_RADIUS = 200
local SPAWN_PROTECTION_TIME = 5

if npc_cursed_pingu_force_download:GetBool() then
	resource.AddWorkshop(workshopID)
end

util.AddNetworkString("cursed_pingu_nag")
util.AddNetworkString("cursed_pingu_navgen")

 -- Pathfinding is only concerned with static geometry anyway.
local trace = {
	mask = MASK_SOLID_BRUSHONLY
}

local function isPointNearSpawn(point, distance)
	--TODO: Is this a reliable standard??
	if not GAMEMODE.SpawnPoints then return false end

	local distanceSqr = distance * distance
	for _, spawnPoint in pairs(GAMEMODE.SpawnPoints) do
		if not IsValid(spawnPoint) then continue end

		if point:DistToSqr(spawnPoint:GetPos()) <= distanceSqr then
			return true
		end
	end

	return false
end

local function isPositionExposed(pos)
	for _, ply in pairs(player.GetAll()) do
		if IsValid(ply) and ply:Alive() and ply:IsLineOfSightClear(pos) then
			-- This spot can be seen!
			return true
		end
	end

	return false
end

local VECTOR_cursed_pingu_HEIGHT = Vector(0, 0, 96)
local function isPointSuitableForHiding(point)
	trace.start = point
	trace.endpos = point + VECTOR_cursed_pingu_HEIGHT
	local tr = util.TraceLine(trace)

	return (not tr.Hit)
end

local g_hidingSpots = nil
local function buildHidingSpotCache()
	local rStart = SysTime()

	g_hidingSpots = {}

	-- Look in every area on the navmesh for usable hiding places.
	-- Compile them into one nice list for lookup.
	local areas = navmesh.GetAllNavAreas()
	local goodSpots, badSpots = 0, 0
	for _, area in pairs(areas) do
		for _, hidingSpot in pairs(area:GetHidingSpots()) do
			if isPointSuitableForHiding(hidingSpot) then
				g_hidingSpots[goodSpots + 1] = {
					pos = hidingSpot,
					nearSpawn = isPointNearSpawn(hidingSpot, 200),
					occupant = nil
				}
				goodSpots = goodSpots + 1
			else
				badSpots = badSpots + 1
			end
		end
	end

	print(string.format("npc_cursed_pingu: found %d suitable (%d unsuitable) hiding \z
		places in %d areas over %.2fms!", goodSpots, badSpots, #areas,
		(SysTime() - rStart) * 1000))
end

local ai_ignoreplayers = GetConVar("ai_ignoreplayers")
local function isValidTarget(ent)
	-- Ignore non-existant entities.
	if not IsValid(ent) then return false end

	-- Ignore dead players (or all players if `ai_ignoreplayers' is 1)
	if ent:IsPlayer() then
		if ai_ignoreplayers:GetBool() then return false end
		return ent:Alive()
	end

	-- Ignore dead NPCs, other Cursed Pingus, and dummy NPCs.
	local class = ent:GetClass()
	return (ent:IsNPC()
		and ent:Health() > 0
		and class ~= "npc_cursed_pingu"
		and not class:find("bullseye"))
end

hook.Add("PlayerSpawnedNPC", "cursed_pinguMissingNavmeshNag", function(ply, ent)
	if not IsValid(ent) then return end
	if ent:GetClass() ~= "npc_cursed_pingu" then return end
	if navmesh.GetNavAreaCount() > 0 then return end

	-- Try to explain why Cursed Pingu isn't working.
	net.Start("cursed_pingu_nag")
	net.Send(ply)
end)

local generateStart = 0
local function navEndGenerate()
	local timeElapsedStr = string.NiceTime(SysTime() - generateStart)

	if not navmesh.IsGenerating() then
		print("npc_cursed_pingu: Navmesh generation completed in " .. timeElapsedStr)
	else
		print("npc_cursed_pingu: Navmesh generation aborted after " .. timeElapsedStr)
	end

	-- Turn this back off.
	RunConsoleCommand("developer", "0")
end

local DEFAULT_SEEDCLASSES = {
	-- Source games in general
	"info_player_start",

	-- Garry's Mod (Obsolete)
	"gmod_player_start", "info_spawnpoint",

	-- Half-Life 2: Deathmatch
	"info_player_combine", "info_player_rebel", "info_player_deathmatch",

	-- Counter-Strike (Source & Global Offensive)
	"info_player_counterterrorist", "info_player_terrorist",

	-- Day of Defeat: Source
	"info_player_allies", "info_player_axis",

	-- Team Fortress 2
	"info_player_teamspawn",

	-- Left 4 Dead (1 & 2)
	"info_survivor_position",

	-- Portal 2
	"info_coop_spawn",

	-- Age of Chivalry
	"aoc_spawnpoint",

	-- D.I.P.R.I.P. Warm Up
	"diprip_start_team_red", "diprip_start_team_blue",

	-- Dystopia
	"dys_spawn_point",

	-- Insurgency
	"ins_spawnpoint",

	-- Pirates, Vikings, and Knights II
	"info_player_pirate", "info_player_viking", "info_player_knight",

	-- Obsidian Conflict (and probably some generic CTF)
	"info_player_red", "info_player_blue",

	-- Synergy
	"info_player_coop",

	-- Zombie Master
	"info_player_zombiemaster",

	-- Zombie Panic: Source
	"info_player_human", "info_player_zombie",

	-- Some maps start you in a cage room with a start button, have building
	-- interiors with teleportation doors, or the like.
	-- This is so the navmesh will (hopefully) still generate correctly and
	-- fully in these cases.
	"info_teleport_destination",
}

local function addEntitiesToSet(set, ents)
	for _, ent in pairs(ents) do
		if IsValid(ent) then
			set[ent] = true
		end
	end
end

local NAV_GEN_STEP_SIZE = 25
local function navGenerate()
	local seeds = {}

	-- Add a bunch of the usual classes as walkable seeds.
	for _, class in pairs(DEFAULT_SEEDCLASSES) do
		addEntitiesToSet(seeds, ents.FindByClass(class))
	end

	-- For gamemodes that define their own spawnpoint entities.
	addEntitiesToSet(seeds, GAMEMODE.SpawnPoints or {})

	if next(seeds, nil) == nil then
		print("npc_cursed_pingu: Couldn't find any places to seed nav_generate")
		return false
	end

	for seed in pairs(seeds) do
		local pos = seed:GetPos()
		pos.x = NAV_GEN_STEP_SIZE * math.Round(pos.x / NAV_GEN_STEP_SIZE)
		pos.y = NAV_GEN_STEP_SIZE * math.Round(pos.y / NAV_GEN_STEP_SIZE)

		-- Start a little above because some mappers stick the
		-- teleport destination right on the ground.
		trace.start = pos + vector_up
		trace.endpos = pos - vector_up * 16384
		local tr = util.TraceLine(trace)

		if not tr.StartSolid and tr.Hit then
			print(string.format("npc_cursed_pingu: Adding seed %s at %s", seed, pos))
			navmesh.AddWalkableSeed(tr.HitPos, tr.HitNormal)
		else
			print(string.format("npc_cursed_pingu: Couldn't add seed %s at %s", seed,
				pos))
		end
	end

	-- The least we can do is ensure they don't have to listen to this noise.
	for _, cursed_pingu in pairs(ents.FindByClass("npc_cursed_pingu")) do
		cursed_pingu:Remove()
	end

	-- This isn't strictly necessary since we just added EVERY spawnpoint as a
	-- walkable seed, but I dunno. What does it hurt?
	navmesh.SetPlayerSpawnName(next(seeds, nil):GetClass())

	navmesh.BeginGeneration()

	if navmesh.IsGenerating() then
		generateStart = SysTime()
		hook.Add("ShutDown", "cursed_pinguNavGen", navEndGenerate)
	else
		print("npc_cursed_pingu: nav_generate failed to initialize")
		navmesh.ClearWalkableSeeds()
	end

	return navmesh.IsGenerating()
end

concommand.Add("npc_cursed_pingu_learn", function(ply, cmd, args)
	if navmesh.IsGenerating() then
		return
	end

	-- Rcon or single-player only.
	local isConsole = (ply:EntIndex() == 0)
	if game.SinglePlayer() then
		print("npc_cursed_pingu: Beginning nav_generate requested by " .. ply:Name())

		-- Disable expensive computations in single-player. Cursed Pingu doesn't use
		-- their results, and it consumes a massive amount of time and CPU.
		-- We'd do this on dedicated servers as well, except that sv_cheats
		-- needs to be enabled in order to disable visibility computations.
		RunConsoleCommand("nav_max_view_distance", "1")
		RunConsoleCommand("nav_quicksave", "1")

		-- Enable developer mode so we can see console messages in the corner.
		RunConsoleCommand("developer", "1")
	elseif isConsole then
		print("npc_cursed_pingu: Beginning nav_generate requested by server console")
	else
		return
	end

	local success = navGenerate()

	-- If it fails, only the person who started it needs to know.
	local recipients = (success and player.GetHumans() or {ply})

	net.Start("cursed_pingu_navgen")
		net.WriteBool(success)
	net.Send(recipients)
end)

ENT.LastPathRecompute = 0
ENT.LastTargetSearch = 0
ENT.LastJumpScan = 0
ENT.LastCeilingUnstick = 0
ENT.LastAttack = 0
ENT.LastHidingPlaceScan = 0
ENT.LastTaunt = 0
ENT.LastChaseSound = 0

ENT.CurrentTarget = nil
ENT.HidingSpot = nil

ENT.lastTrackedPos = Vector(0, 0, 0)
ENT.StepsSound = nil

function ENT:Initialize()
	-- Spawn effect resets render override. Bug!!!
	self:SetSpawnEffect(false)

	self:SetBloodColor(DONT_BLEED)

	-- Just in case.
	self:SetHealth(1e8)

	--self:DrawShadow(false) -- Why doesn't this work???

	--HACK!!! Disables shadow (for real).
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:SetColor(Color(255, 255, 255, 1))

	-- Human-sized collision.
	self:SetCollisionBounds(Vector(-13, -13, 0), Vector(13, 13, 72))

	-- We're a little timid on drops... Give the player a chance. :)
	self.loco:SetDeathDropHeight(600)

	-- In Sandbox, players are faster in singleplayer.
	self.loco:SetDesiredSpeed(game.SinglePlayer() and 650 or 500)

	-- Take corners a bit sharp.
	self.loco:SetAcceleration(500)
	self.loco:SetDeceleration(500)

	-- This isn't really important because we reset it all the time anyway.
	self.loco:SetJumpHeight(300)

	if self.StepSound == nul then
		self.StepsSound = CreateSound(self, walkingMusic)
		self.StepsSound:Stop()
	end

	-- Rebuild caches.
	self:OnReloaded()
end

function ENT:OnInjured(dmg)
	-- Just in case.
	dmg:SetDamage(0)
end

function ENT:OnReloaded()
	if g_hidingSpots == nil then
		buildHidingSpotCache()
	end
end

function ENT:OnRemove()
	-- Give up our hiding spot when we're deleted.
	self:ClaimHidingSpot(nil)
	if self.StepsSound ~= nil then
		self.StepsSound:Stop()
	end
end

function ENT:UpdateMovingStatus(delta)
	local currentPos = self:GetPos()
	local speedSqr = currentPos:DistToSqr(self.lastTrackedPos) / (delta * delta)
	self.lastTrackedPos = currentPos
	if ( speedSqr < SPEED_THRESHOLD_SQUARED ) then
		if self:GetMoving() then
			self:SetMoving( false )
		end
	elseif not self:GetMoving() then
		self:SetMoving( true )
	end
end

function ENT:UpdateStepsSound()
	if self:GetMoving() then
		if not self.StepsSound:IsPlaying() then
			local pitch = math.Clamp(game.GetTimeScale() * 100, 50, 255)
			self.StepsSound:PlayEx(1, pitch)
		end
	else
		if self.StepsSound:IsPlaying() then
			self.StepsSound:Stop()
		end
	end
end

local playersLatestSpawnTime = {}
local function trackPlayersSpawnTime(ply)
	playersLatestSpawnTime[ply:SteamID64()] = CurTime()
end
hook.Add("PlayerSpawn", "track_players_spawn_time", trackPlayersSpawnTime)

local function isPlayerSpawnProtected(ply)
	return npc_cursed_pingu_spawn_protect:GetBool()
	   and isPointNearSpawn(ply:GetPos(), SPAWN_PROTECTION_RADIUS)
	   and (CurTime() - playersLatestSpawnTime[ply:SteamID64()] <= SPAWN_PROTECTION_TIME)
end

function ENT:GetNearestTarget()
	local maxAcquireDist = npc_cursed_pingu_acquire_distance:GetInt()
	local maxAcquireDistSqr = maxAcquireDist * maxAcquireDist
	local myPos = self:GetPos()
	local target = nil

	for _, ent in pairs(ents.FindInSphere(myPos, maxAcquireDist)) do
		if not isValidTarget(ent) then continue end
		if ent:IsPlayer() and isPlayerSpawnProtected(ent) then continue end

		local distSqr = myPos:DistToSqr(ent:GetPos())
		if distSqr < maxAcquireDistSqr then
			target = ent
			maxAcquireDistSqr = distSqr
		end
	end

	return target
end

function ENT:AttackNearbyTargets(radius)
	local attackForce = npc_cursed_pingu_attack_force:GetInt()
	local hitSource = self:LocalToWorld(self:OBBCenter())
	local nearEntities = ents.FindInSphere(hitSource, radius)
	local hit = false
	for _, ent in pairs(nearEntities) do
		if isValidTarget(ent) then
			local health = ent:Health()

			if ent:IsPlayer() and IsValid(ent:GetVehicle()) then
				local vehicle = ent:GetVehicle()
				local vehiclePos = vehicle:LocalToWorld(vehicle:OBBCenter())
				local hitDirection = (vehiclePos - hitSource):GetNormal()
				local phys = vehicle:GetPhysicsObject()
				if IsValid(phys) then
					phys:Wake()
					local hitOffset = vehicle:NearestPoint(hitSource)
					phys:ApplyForceOffset(hitDirection * (attackForce * phys:GetMass()), hitOffset)
				end
				vehicle:TakeDamage(math.max(1e8, ent:Health()), self, self)
				vehicle:EmitSound(string.format("physics/metal/metal_sheet_impact_hard%d.wav",	math.random(6, 8)), 350, 120)
			else
				ent:EmitSound(string.format("physics/body/body_medium_impact_hard%d.wav", math.random(1, 6)), 350, 120)
			end

			local hitDirection = (ent:GetPos() - hitSource):GetNormal()
			ent:SetVelocity(hitDirection * attackForce + vector_up * 500)

			local dmgInfo = DamageInfo()
			dmgInfo:SetAttacker(self)
			dmgInfo:SetInflictor(self)
			dmgInfo:SetDamage(1e8)
			dmgInfo:SetDamagePosition(self:GetPos())
			dmgInfo:SetDamageForce((hitDirection * attackForce + vector_up * 500) * 100)
			ent:TakeDamageInfo(dmgInfo)

			local newHealth = ent:Health()
			hit = (hit or (newHealth < health))
		elseif ent:GetMoveType() == MOVETYPE_VPHYSICS then
			if not npc_cursed_pingu_smash_props:GetBool() then continue end
			if ent:IsVehicle() and IsValid(ent:GetDriver()) then continue end

			local entPos = ent:LocalToWorld(ent:OBBCenter())
			local hitDirection = (entPos - hitSource):GetNormal()
			local hitOffset = ent:NearestPoint(hitSource)
			constraint.RemoveAll(ent)

			local phys = ent:GetPhysicsObject()
			local mass = 0
			local material = "Default"
			if IsValid(phys) then
				mass = phys:GetMass()
				material = phys:GetMaterial()
			end

			if mass >= 5 then
				ent:EmitSound(material .. ".ImpactHard", 350, 120)
			end

			for id = 0, ent:GetPhysicsObjectCount() - 1 do
				local phys = ent:GetPhysicsObjectNum(id)
				if IsValid(phys) then
					phys:EnableMotion(true)
					phys:ApplyForceOffset(hitDirection * (attackForce * mass), hitOffset)
				end
			end

			ent:TakeDamage(25, self, self)
		end
	end

	return hit
end

function ENT:IsHidingSpotFull(hidingSpot)
	local occupant = hidingSpot.occupant
	return (IsValid(occupant) and occupant ~= self)
end

--TODO: Weight spots based on how many people can see them.
function ENT:GetNearestUsableHidingSpot()
	local nearestHidingSpot = nil
	local nearestHidingDistSqr = 1e8

	local myPos = self:GetPos()
	local isHidingSpotFull = self.IsHidingSpotFull
	local distToSqr = myPos.DistToSqr

	-- This could be a long loop. Optimize the heck out of it.
	for _, hidingSpot in pairs(g_hidingSpots) do
		-- Ignore hiding spots that are near spawn, or full.
		if hidingSpot.nearSpawn or isHidingSpotFull(self, hidingSpot) then
			continue
		end

		--TODO: Disallow hiding places near spawn?
		local hidingSpotDistSqr = distToSqr(hidingSpot.pos, myPos)
		if hidingSpotDistSqr < nearestHidingDistSqr
			and not isPositionExposed(hidingSpot.pos)
		then
			nearestHidingDistSqr = hidingSpotDistSqr
			nearestHidingSpot = hidingSpot
		end
	end

	return nearestHidingSpot
end

function ENT:ClaimHidingSpot(hidingSpot)
	-- Release our claim on the old spot.
	if self.HidingSpot ~= nil then
		self.HidingSpot.occupant = nil
	end

	-- Can't claim something that doesn't exist, or a spot that's
	-- already claimed.
	if hidingSpot == nil or self:IsHidingSpotFull(hidingSpot) then
		self.HidingSpot = nil
		return false
	end

	-- Yoink.
	self.HidingSpot = hidingSpot
	self.HidingSpot.occupant = self
	return true
end

local HIGH_JUMP_HEIGHT = 500
function ENT:AdaptiveJumpAtTarget()
	-- No double-jumping.
	if not self:IsOnGround() then return end

	local targetPos = self.CurrentTarget:GetPos()
	local xyDistSqr = (targetPos - self:GetPos()):Length2DSqr()
	local zDifference = targetPos.z - self:GetPos().z
	local maxAttackDistance = npc_cursed_pingu_attack_distance:GetInt()
	if xyDistSqr <= math.pow(maxAttackDistance + 200, 2)
		and zDifference >= maxAttackDistance
	then
		--TODO: Set up jump so target lands on parabola.
		local jumpHeight = zDifference + 50
		self.loco:SetJumpHeight(jumpHeight)
		self.loco:Jump()
		self.loco:SetJumpHeight(300)

		self:EmitSound((jumpHeight > HIGH_JUMP_HEIGHT and
			table.Random(self.JumpSound) or table.Random(self.JumpSound)), 350, 100)
			
	end
end

local VECTOR_HIGH = Vector(0, 0, 16384)
ENT.LastPathingInfraction = 0
function ENT:RecomputeTargetPath()
	if CurTime() - self.LastPathingInfraction < PATH_INFRACTION_TIMEOUT then
		-- No calculations for you today.
		return
	end

	local targetPos = self.CurrentTarget:GetPos()

	-- Run toward the position below the entity we're targetting,
	-- since we can't fly.
	trace.start = targetPos
	trace.endpos = targetPos - VECTOR_HIGH
	trace.filter = self.CurrentTarget
	local tr = util.TraceEntity(trace, self.CurrentTarget)

	-- Of course, we sure that there IS a "below the target."
	if tr.Hit and util.IsInWorld(tr.HitPos) then
		targetPos = tr.HitPos
	end

	local rTime = SysTime()
	self.MovePath:Compute(self, targetPos)

	-- If path computation takes longer than 5ms (A LONG TIME),
	-- disable computation for a little while for this bot.
	if SysTime() - rTime > 0.005 then
		self.LastPathingInfraction = CurTime()
	end
end

function ENT:BehaveStart()
	self.MovePath = Path("Follow")
	self.MovePath:SetMinLookAheadDistance(500)
	self.MovePath:SetGoalTolerance(10)
end

local ai_disabled = GetConVar("ai_disabled")

function ENT:BehaveUpdate(delta)
	self:UpdateMovingStatus(delta)
	self:UpdateStepsSound()

	if ai_disabled:GetBool() then return end

	local currentTime = CurTime()

	if ( self:GetRaging() and (currentTime - self.LastTaunt > TAUNT_INTERVAL) ) then
		self:SetRaging(false)
		self.LastTargetSearch = 0
		self.LastHidingPlaceScan = 0
	end

	if self:GetRaging() then
		return
	end

	local shouldScanForTargets = currentTime - self.LastTargetSearch > npc_cursed_pingu_expensive_scan_interval:GetFloat()
	if shouldScanForTargets then
		local target = self:GetNearestTarget()
		if target ~= self.CurrentTarget then
			self.CurrentTarget = target
			self.LastPathRecompute = 0
		end
		self.LastTargetSearch = currentTime
	end

	if IsValid(self.CurrentTarget) then
		local mayAttack = currentTime - self.LastAttack > npc_cursed_pingu_attack_interval:GetFloat()
		if mayAttack then
			local attackDistance = npc_cursed_pingu_attack_distance:GetInt()
			if self:AttackNearbyTargets(attackDistance) then
				self:SetRaging(true)
				self:EmitSound(table.Random(self.TauntSounds), 350, 100)
				effects.BeamRingPoint(self:GetPos(), 0.5, 0, 1000, 100, 10, {r=100, g=0, b=0, a=200}, {})
				self.LastTaunt = currentTime
				self.CurrentTarget = nil
			end
			self.LastAttack = currentTime
		end
	end

	if IsValid(self.CurrentTarget) then
		local canShoutChaseSounds = currentTime - self.LastChaseSound > CHASE_SOUND_INTERVAL
		if canShoutChaseSounds then
			self:EmitSound(table.Random(self.ChaseSounds), 350, 100)
			self.LastChaseSound = currentTime + math.Rand(0, CHASE_SOUND_INTERVAL / 2)
		end

		local mustRepathChase = currentTime - self.LastPathRecompute > npc_cursed_pingu_chase_repath_interval:GetFloat()
		if mustRepathChase then
			self:RecomputeTargetPath()
			self.LastPathRecompute = currentTime
		end

		self.MovePath:Update(self)

		local isAllowedToJump = self:IsOnGround() and npc_cursed_pingu_allow_jump:GetBool() and currentTime - self.LastJumpScan >= npc_cursed_pingu_expensive_scan_interval:GetFloat()
		if isAllowedToJump then
			self:AdaptiveJumpAtTarget()
			self.LastJumpScan = currentTime
		end
	else
		local maySearchNewHidingSpot = currentTime - self.LastHidingPlaceScan >= npc_cursed_pingu_hiding_scan_interval:GetFloat()
		if maySearchNewHidingSpot then
			self:ClaimHidingSpot(self:GetNearestUsableHidingSpot())
			self.LastHidingPlaceScan = currentTime
		end

		if self.HidingSpot ~= nil then
			local mustRepathHidingSpot = currentTime - self.LastPathRecompute >= npc_cursed_pingu_hiding_repath_interval:GetFloat()
			if mustRepathHidingSpot then
				self.MovePath:Compute(self, self.HidingSpot.pos)
				self.LastPathRecompute = currentTime
			end
			self.MovePath:Update(self)
			local canShoutHiddenSounds = (currentTime - self.LastChaseSound > CHASE_SOUND_INTERVAL) and (self:GetPos():DistToSqr(self.HidingSpot.pos) < 100)
			if canShoutHiddenSounds then
				self:EmitSound(table.Random(self.TauntSounds), 350, 100)
				self.LastChaseSound = currentTime + math.Rand(0, CHASE_SOUND_INTERVAL / 2)
			end
		else
			-- TODO: Wander if we didn't find a place to hide, preferably AWAY from spawn points
		end
	end

	-- Don't even wait until the STUCK flag is set for this: it's much more fluid this way
	local mayTryToGetUnstuck = currentTime - self.LastCeilingUnstick >= npc_cursed_pingu_expensive_scan_interval:GetFloat()
	if mayTryToGetUnstuck then
		self:UnstickFromCeiling()
		self.LastCeilingUnstick = currentTime
	end
	if currentTime - self.LastStuck >= 5 then
		self.StuckTries = 0
	end
end

ENT.LastStuck = 0
ENT.StuckTries = 0
function ENT:OnStuck()
	-- Jump forward a bit on the path.
	self.LastStuck = CurTime()

	local newCursor = self.MovePath:GetCursorPosition()
		+ 40 * math.pow(2, self.StuckTries)
	self:SetPos(self.MovePath:GetPositionOnPath(newCursor))
	self.StuckTries = self.StuckTries + 1

	-- Hope that we're not stuck anymore.
	self.loco:ClearStuck()
end

function ENT:UnstickFromCeiling()
	if self:IsOnGround() then return end

	-- NextBots LOVE to get stuck. Stuck in the morning. Stuck in the evening.
	-- Stuck in the ceiling. Stuck on each other. The stuck never ends.
	local myPos = self:GetPos()
	local myHullMin, myHullMax = self:GetCollisionBounds()
	local myHull = myHullMax - myHullMin
	local myHullTop = myPos + vector_up * myHull.z
	trace.start = myPos
	trace.endpos = myHullTop
	trace.filter = self
	local upTrace = util.TraceLine(trace, self)

	if upTrace.Hit and upTrace.HitNormal ~= vector_origin
		and upTrace.Fraction > 0.5
	then
		local unstuckPos = myPos
			+ upTrace.HitNormal * (myHull.z * (1 - upTrace.Fraction))
		self:SetPos(unstuckPos)
	end
end

else -- CLIENT --


local MAT_cursed_pingu = Material("npc_cursed_pingu/cursed_pingu")
local MAT_cursed_pingu_raging = Material("npc_cursed_pingu/cursed_pingu_raging")
local MAT_cursed_pingu_still = Material("npc_cursed_pingu/cursed_pingu_still")
killicon.Add("npc_cursed_pingu", "npc_cursed_pingu/killicon", color_white)
language.Add("npc_cursed_pingu", "Cursed Pingu")

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local developer = GetConVar("developer")
local function DevPrint(devLevel, msg)
	if developer:GetInt() >= devLevel then
		DebugInfo("npc_cursed_pingu: " .. msg)
	end
end

local viewAlteration = 0

local modifyColoursConf = {
	[ "$pp_colour_addr" ] = 0,
	[ "$pp_colour_addg" ] = 0,
	[ "$pp_colour_addb" ] = 0,
	[ "$pp_colour_brightness" ] = 0,
	[ "$pp_colour_contrast" ] = 1,
	[ "$pp_colour_colour" ] = 1,
	[ "$pp_colour_mulr" ] = 0,
	[ "$pp_colour_mulg" ] = 0,
	[ "$pp_colour_mulb" ] = 0
}

hook.Add( "RenderScreenspaceEffects", "postprocess_cursed_pingu_proximity", function()
	modifyColoursConf["$pp_colour_brightness"] = 0 - 0.25 * viewAlteration
	modifyColoursConf["$pp_colour_contrast"] = 1 + 0.25 * viewAlteration
	modifyColoursConf["$pp_colour_colour"] = 1 - 0.25 * viewAlteration
	DrawColorModify( modifyColoursConf )
	DrawMotionBlur(1 - 0.75 * viewAlteration, 1 - 0.02 * viewAlteration , 0.05 * viewAlteration)
end )

local panicMusic = nil
local lastPanic = 0 -- The last time we were in music range of a Cursed Pingu.

--TODO: Why don't these flags show up? Bug? Documentation would be lovely.
local npc_cursed_pingu_music_volume =
	CreateConVar("npc_cursed_pingu_music_volume", 1,
	bit.bor(FCVAR_DEMO, FCVAR_ARCHIVE),
	"Maximum music volume when being chased by Cursed Pingu. (0-1, where 0 is muted)")

-- If another Cursed Pingu comes in range before this delay is up,
-- the music will continue where it left off.
local MUSIC_RESTART_DELAY = 2

local MUSIC_CUTOFF_DISTANCE = 2500

local MUSIC_LOUD_DISTANCE = 250

local MIN_VOLUME = 0.01

local MUSIC_RANGE = MUSIC_CUTOFF_DISTANCE - MUSIC_LOUD_DISTANCE

local MAX_DISTANCE = MUSIC_CUTOFF_DISTANCE

local function alteration(distance)
	if distance > MUSIC_CUTOFF_DISTANCE then
		return 0
	end
	local r = math.max(0, distance - MUSIC_LOUD_DISTANCE) / MUSIC_RANGE
	local v = 1 / (1 + (r * r) / MIN_VOLUME)
	return math.min(1, v)
end

local function updatePanicMusic()
	if #ents.FindByClass("npc_cursed_pingu") == 0 then
		-- Whoops. No need to run for now.
		DevPrint(4, "Halting music timer.")
		timer.Remove("cursed_pinguPanicMusicUpdate")

		if panicMusic ~= nil then
			panicMusic:Stop()
		end

		viewAlteration = 0

		return
	end

	if not IsValid(LocalPlayer()) then
		return
	end

	if panicMusic == nil then
		panicMusic = CreateSound(LocalPlayer(), chaseMusic)
		panicMusic:Stop()
	end

	local minDistance = MAX_DISTANCE
	local nearEntities = ents.FindInSphere(LocalPlayer():GetPos(), MAX_DISTANCE)
	for _, ent in pairs(nearEntities) do
		if IsValid(ent) and ent:GetClass() == "npc_cursed_pingu" then
			local distance = LocalPlayer():GetPos():Distance(ent:GetPos())
			minDistance = math.min(minDistance, distance)
		end
	end

	viewAlteration = alteration(minDistance)

	local shouldRestartMusic = (CurTime() - lastPanic >= MUSIC_RESTART_DELAY)
	local userVolume = math.Clamp(npc_cursed_pingu_music_volume:GetFloat(), 0, 1)
	local musicVolume = viewAlteration * userVolume
	if musicVolume == 0 then
		if shouldRestartMusic then
			panicMusic:Stop()
		end
	else
		if not LocalPlayer():Alive() then
			-- Quiet down so we can hear Cursed Pingu taunt us.
			musicVolume = musicVolume / 4
		end
		musicVolume = math.max(MIN_VOLUME, musicVolume)

		if shouldRestartMusic then
			panicMusic:Play()
		end
		lastPanic = CurTime()
	end

	local pitch = math.Clamp(game.GetTimeScale() * 100, 50, 255)
	panicMusic:ChangeVolume(musicVolume, 0)
	panicMusic:ChangePitch(pitch, 0)
end

local function startTimer()
	if not timer.Exists("cursed_pinguPanicMusicUpdate") then
		timer.Create("cursed_pinguPanicMusicUpdate", 0.05, REPEAT_FOREVER, updatePanicMusic)
		DevPrint(4, "Beginning music timer.")
	end
end

local SPRITE_SIZE = 128
function ENT:Initialize()
	self:SetRenderBounds(
		Vector(-SPRITE_SIZE / 2, -SPRITE_SIZE / 2, 0),
		Vector(SPRITE_SIZE / 2, SPRITE_SIZE / 2, SPRITE_SIZE),
		Vector(5, 5, 5)
	)

	startTimer()
end

local DRAW_OFFSET = SPRITE_SIZE / 2 * vector_up
function ENT:DrawTranslucent()
	local raging = self:GetRaging()
	local moving = self:GetMoving()
	
	if raging then
		render.SetMaterial(MAT_cursed_pingu_raging)
	elseif moving then
		render.SetMaterial(MAT_cursed_pingu)
	else
		render.SetMaterial(MAT_cursed_pingu_still)
	end

	-- Get the normal vector from Cursed Pingu to the player's eyes, and then compute
	-- a corresponding projection onto the xy-plane.
	local pos = self:GetPos() + DRAW_OFFSET
	local normal = EyePos() - pos
	normal:Normalize()
	local xyNormal = Vector(normal.x, normal.y, 0)
	xyNormal:Normalize()

	-- Cursed Pingu should only look 1/3 of the way up to the player so that they
	-- don't appear to lay flat from above.
	local pitch = math.acos(math.Clamp(normal:Dot(xyNormal), -1, 1)) / 3
	local cos = math.cos(pitch)
	normal = Vector(
		xyNormal.x * cos,
		xyNormal.y * cos,
		math.sin(pitch)
	)

	render.DrawQuadEasy(pos, normal, SPRITE_SIZE, SPRITE_SIZE, color_white, 180)
end

surface.CreateFont("cursed_pinguHUD", {
	font = "Arial",
	size = 56
})

surface.CreateFont("cursed_pinguHUDSmall", {
	font = "Arial",
	size = 24
})

local function string_ToHMS(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds / 60) % 60)
	local seconds = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	else
		return string.format("%02d:%02d", minutes, seconds)
	end
end

local flavourTexts = {
	{
		"Gotta learn fast!",
		"Learning this'll be a piece of cake!",
		"This is too easy."
	}, {
		"This must be a big map.",
		"This map is a bit bigger than I thought.",
	}, {
		"Just how big is this place?",
		"This place is pretty big."
	}, {
		"This place is enormous!",
		"A guy could get lost around here."
	}, {
		"Surely I'm almost done...",
		"There can't be too much more...",
		"This isn't gm_bigcity, is it?",
		"Is it over yet?",
		"You never told me the map was this big!"
	}
}
local SECONDS_PER_BRACKET = 300 -- 5 minutes
local color_yellow = Color(255, 255, 80)
local flavourText = ""
local lastBracket = 0
local generateStart = 0
local function navGenerateHUDOverlay()
	draw.SimpleTextOutlined("Cursed Pingu is studying this map.", "cursed_pinguHUD",
		ScrW() / 2, ScrH() / 2, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black)
	draw.SimpleTextOutlined("Please wait...", "cursed_pinguHUD",
		ScrW() / 2, ScrH() / 2, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)

	local elapsed = SysTime() - generateStart
	local elapsedStr = string_ToHMS(elapsed)
	draw.SimpleTextOutlined("Time Elapsed:", "cursed_pinguHUDSmall",
		ScrW() / 2, ScrH() * 3/4, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
	draw.SimpleTextOutlined(elapsedStr, "cursed_pinguHUDSmall",
		ScrW() / 2, ScrH() * 3/4, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)

	-- It's taking a while.
	local textBracket = math.floor(elapsed / SECONDS_PER_BRACKET) + 1
	if textBracket ~= lastBracket then
		flavourText = table.Random(flavourTexts[math.min(5, textBracket)])
		lastBracket = textBracket
	end
	draw.SimpleTextOutlined(flavourText, "cursed_pinguHUDSmall",
		ScrW() / 2, ScrH() * 4/5, color_yellow,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end

net.Receive("cursed_pingu_navgen", function()
	local startSuccess = net.ReadBool()
	if startSuccess then
		generateStart = SysTime()
		lastBracket = 0
		hook.Add("HUDPaint", "cursed_pinguNavGenOverlay", navGenerateHUDOverlay)
	else
		Derma_Message("Oh no. Cursed Pingu doesn't even know where to start with \z
		this map.\n\z
		If you're not running the Sandbox gamemode, switch to that and try \z
		again.", "Error!")
	end
end)

local nagMe = true

local function requestNavGenerate()
	RunConsoleCommand("npc_cursed_pingu_learn")
end

local function stopNagging()
	nagMe = false
end

local function navWarning()
	Derma_Query("It will take a while (possibly hours) for Cursed Pingu to figure \z
		this map out.\n\z
		While he's studying it, you won't be able to play,\n\z
		and the game will appear to have frozen/crashed.\n\z
		\n\z
		Also note that THE MAP WILL BE RESTARTED.\n\z
		Anything that has been built will be deleted.", "Warning!",
		"Go ahead!", requestNavGenerate,
		"Not right now.", nil)
end

net.Receive("cursed_pingu_nag", function()
	if not nagMe then return end

	if game.SinglePlayer() then
		Derma_Query("Uh oh! Cursed Pingu doesn't know this map.\n\z
			Would you like him to learn it?",
			"This map is not yet Cursed Pingu-compatible!",
			"Yes", navWarning,
			"No", nil,
			"No. Don't ask again.", stopNagging)
	else
		Derma_Query("Uh oh! Cursed Pingu doesn't know this map. \z
			He won't be able to move!\n\z
			Because you're not in a single-player game, he isn't able to \z
			learn it.\n\z
			\n\z
			Ask the server host about teaching this map to Cursed Pingu.\n\z
			\n\z
			If you ARE the server host, you can run npc_cursed_pingu_learn over \z
			rcon.\n\z
			Keep in mind that it may take hours during which you will be \z
			unable\n\z
			to play, and THE MAP WILL BE RESTARTED.",
			"This map is currently not Cursed Pingu-compatible!",
			"Ok", nil,
			"Ok. Don't say this again.", stopNagging)
	end
end)

end

--
-- List the NPC as spawnable.
--
list.Set("NPC", "npc_cursed_pingu", {
	Name = "Cursed Pingu",
	Class = "npc_cursed_pingu",
	Category = "Nextbot",
	AdminOnly = true
})
