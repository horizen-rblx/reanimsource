local zen = {
	services = {
		players = game:GetService("Players");
		workspace = game:GetService("Workspace");
		replicated = game:GetService("ReplicatedStorage");
		run_service = game:GetService("RunService");
		user_input_service = game:GetService("UserInputService");
		http_service = game:GetService("HttpService");
	};
	flags = {
		reanimated = false;
		is_processing = false;
	};
	clones = {};
	connections = {
		stepped = nil;
		hb = nil;
		render = nil;
		died = nil;
		real_char_child_removed = nil;
		character_removing = nil;
		clone_died = nil;
		clone_char_child_removed = nil;
		animation_hb = nil;
	};
	real_chars = {};
	callbacks = {
		on_play = nil,
		on_stop = nil,
	},
	animation = {
		cache = {};
		state = {
			is_playing = false;
			current_url = nil;
			speed = 1.0;
			keyframes = nil;
			total_duration = 0;
			elapsed_time = 0;
		};
		original_motor_c0s = {};
		joints = {};
	};
};

_G.hiddenBodyParts = _G.hiddenBodyParts or {}

local part_names = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"HumanoidRootPart"
};

local API = {};

local get_game_ragdoll_info = function(enable)
	local place_id = game.PlaceId;
	if place_id == 15546218972 or place_id == 6884319169 then
		-- Mic Up and Mic Up 18+
		local remote = zen.services.replicated:FindFirstChild("event_rag");
		if not remote then return nil, nil, false end
		return remote, {"Ball"}, false;
	elseif place_id == 5991163185 then
		-- Spray Paint
		local remote = zen.services.replicated:FindFirstChild("Remotes") and zen.services.replicated.Remotes:FindFirstChild("Physics") and zen.services.replicated.Remotes.Physics:FindFirstChild("Ragdoll");
		if not remote then return nil, nil, false end
		return remote, {}, false;
	elseif place_id == 5683833663 then
		-- Ragdoll Engine (uses LocalEvent, not RemoteEvent)
		local local_event = zen.services.replicated:FindFirstChild("LocalRagdollEvent");
		if not local_event then return nil, nil, false end
		return local_event, {enable}, true;
	end;
	return nil, nil, false;
end;

local set_model_transparency = function(model, transparency)
	if not model then return end;
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = transparency;
		elseif part:IsA("Decal") then
			part.Transparency = transparency;
		end;
	end;
end;

local get_local_player = function()
	local player = zen.services.players.LocalPlayer;
	if not player then
		return "bad argument to 'get_local_player' (LocalPlayer not found; must run in a LocalScript)";
	end;
	return player;
end;

local get_char = function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return ("bad argument #1 to 'get_char' (Player expected, got %s)"):format(typeof(player));
	end;
	local character = player.Character;
	if not character or not character.Parent then
		return ("Player %s has no active character."):format(player.Name);
	end;
	return character;
end;

local clone_char = function(model)
	if typeof(model) ~= "Instance" then
		return ("bad argument #1 to 'clone_char' (Instance expected, got %s)"):format(typeof(model));
	end;
    
	local old_archivables = {}
	old_archivables[model] = model.Archivable
	model.Archivable = true;
	for _, desc in ipairs(model:GetDescendants()) do
		old_archivables[desc] = desc.Archivable
		desc.Archivable = true
	end

	local new_clone = model:Clone();
	for _, desc in ipairs(new_clone:GetDescendants()) do
		if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("Highlight") or desc:IsA("ParticleEmitter") then
			desc:Destroy()
		end
	end
    
	-- Manually reconstruct any missing Motor6Ds (bypasses games that break Clone())
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Motor6D") and desc.Part0 and desc.Part1 then
			local p0_name = desc.Part0.Name
			local p1_name = desc.Part1.Name
            
			local clone_p1 = new_clone:FindFirstChild(p1_name, true)
			if clone_p1 then
				local existing_joint = clone_p1:FindFirstChild(desc.Name)
				if not existing_joint then
					local clone_p0 = new_clone:FindFirstChild(p0_name, true)
					if clone_p0 then
						local new_motor = Instance.new("Motor6D")
						new_motor.Name = desc.Name
						new_motor.Part0 = clone_p0
						new_motor.Part1 = clone_p1
						new_motor.C0 = desc.C0
						new_motor.C1 = desc.C1
						new_motor.Parent = clone_p1
					end
				end
			end
		end
	end

	for obj, arch in pairs(old_archivables) do
		if obj and obj.Parent then
			obj.Archivable = arch
		end
	end

	new_clone.Name = "Reanimation";
	new_clone.Parent = zen.services.workspace;

	local animate_script = new_clone:FindFirstChild("Animate");
	if animate_script then
		animate_script.Disabled = true;
	end;

	local hum = new_clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.RequiresNeck = false;
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
		hum.NameDisplayDistance = 0;
		hum.HealthDisplayDistance = 0;
		hum.DisplayName = "";
		hum.AutoRotate = true;
	end

	if new_clone:FindFirstChildWhichIsA("ForceField") then
		new_clone:FindFirstChildWhichIsA("ForceField"):Destroy();
	end;
	return new_clone;
end;

local fire_remote = function(remote, is_local, ...)
	if typeof(remote) ~= "Instance" then
		return ("bad argument to 'fire_remote' (Instance expected, got %s)"):format(typeof(remote));
	end;
	if is_local then
		if not remote:IsA("BindableEvent") then
			return ("bad argument to 'fire_remote' (BindableEvent expected for local event, got %s)"):format(remote.ClassName);
		end;
		remote:Fire(...);
	else
		if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
			return ("bad argument to 'fire_remote' (RemoteEvent or RemoteFunction expected, got %s)"):format(remote.ClassName);
		end;
		if remote:IsA("RemoteEvent") then
			remote:FireServer(...);
		else
			remote:InvokeServer(...);
		end;
	end;
end;

--- Stops any currently playing animation.
API.stop_animation = function()
	if not zen.animation.state.is_playing then return end;
    
	local stopped_url = zen.animation.state.current_url

	if zen.connections.animation_hb then
		zen.connections.animation_hb:Disconnect();
		zen.connections.animation_hb = nil;
	end

	local player = get_local_player();
	if typeof(player) == "string" then return player end;

	local clone_char = API.get_clone(player);
	if clone_char then
		for motor, orig_c0 in pairs(zen.animation.original_motor_c0s) do
			if motor and motor.Parent then
				if motor:IsA("Motor6D") or motor:IsA("Motor") or motor:IsA("Weld") then
					pcall(function() motor.C0 = orig_c0 end)
				else
					pcall(function() motor.Transform = orig_c0 end)
				end
			end
		end
		local animator = clone_char:FindFirstChild("Humanoid") and clone_char.Humanoid:FindFirstChild("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
			end
		end

		local clone_animate_script = clone_char:FindFirstChild("Animate")
		if clone_animate_script and clone_animate_script:IsA("LocalScript") then
			clone_animate_script.Disabled = true
			task.wait()
			clone_animate_script.Disabled = false
		end
	end
    
	table.clear(zen.animation.original_motor_c0s);
	table.clear(zen.animation.joints);
	zen.animation.state = { is_playing = false, current_url = nil, speed = 1.0, keyframes = nil, total_duration = 0, elapsed_time = 0 };

	if zen.callbacks.on_stop then
		pcall(zen.callbacks.on_stop, stopped_url)
	end
end;

--- Toggles the Reanimate state.
-- @param bool (boolean) - true to enable reanimation, false to disable.
-- @param remote (Instance) [optional] - A RemoteEvent or RemoteFunction to fire.
-- @param args (table) [optional] - Arguments for the remote.
API.reanimate = function(bool, remote, args)
	if bool ~= true and bool ~= false then
		return ("bad argument #1 to 'reanimate' (boolean expected, got %s)"):format(typeof(bool));
	end;
	if zen.flags.is_processing then
		return "Busy processing reanimation request, please wait.";
	end;
	zen.flags.is_processing = true;
	local success, result = pcall(function()
		return API._reanimate_internal(bool, remote, args)
	end)
	zen.flags.is_processing = false;
	if not success then
		return "Reanimation error: " .. tostring(result);
	end
	return result;
end;

API._reanimate_internal = function(bool, remote, args)
	local player = get_local_player();
	if typeof(player) == "string" then return player end;

	-- Auto-detect game ragdoll remote if none provided
	local is_local_event = false;
	if not remote then
		local game_remote, game_args, is_local = get_game_ragdoll_info(bool);
		if game_remote then
			remote = game_remote;
			args = game_args;
			is_local_event = is_local;
		end;
	end;

	if bool then
		if zen.flags.reanimated then
			return "Already reanimated.";
		end;
		local real_char = get_char(player);
		if typeof(real_char) == "string" then return real_char end;

		local real_humanoid = real_char:FindFirstChildOfClass("Humanoid");
		local real_hrp = real_char:FindFirstChild("HumanoidRootPart");
		if not real_humanoid or not real_hrp then
			return "Missing Humanoid or HumanoidRootPart.";
		end;

		-- Save default hip height
		if not real_humanoid:GetAttribute("ZenDefaultHipHeight") then
			real_humanoid:SetAttribute("ZenDefaultHipHeight", real_humanoid.HipHeight)
		end

		-- Lock down internal humanoid physics states
		pcall(function()
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			real_humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
			real_humanoid.AutoRotate = false
			real_humanoid.PlatformStand = true
			real_humanoid.RequiresNeck = false
			real_humanoid.BreakJointsOnDeath = false
			real_humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			real_humanoid.NameDisplayDistance = 0
			real_humanoid.HealthDisplayDistance = 0
			real_humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		zen.real_chars[player] = real_char;

		-- Clone the character
		local cloned_char = clone_char(real_char);
		if typeof(cloned_char) == "string" then return cloned_char end;
		local cloned_humanoid = cloned_char:FindFirstChildOfClass("Humanoid");
		if not cloned_humanoid then
			return "Cloned character failed to create or is missing a Humanoid.";
		end;
		zen.clones[player] = cloned_char;

		-- Hide the clone visually (the visible avatar is the real character following the clone)
		set_model_transparency(cloned_char, 1);

		-- Apply zero-density physical properties on the real character so limbs don't exert drag or weight
		local zeroPhys = PhysicalProperties.new(0.001, 0, 0, 0, 0)
		for _, desc in ipairs(real_char:GetDescendants()) do
			if desc:IsA("BasePart") then
				pcall(function()
					desc.CanCollide = false
					desc.CanTouch = false
					desc.CanQuery = false
					desc.Massless = true
					desc.CustomPhysicalProperties = zeroPhys
				end)
			end
		end

		-- Destroy tags on the real character so they don't overlap with tags added to the cloned character
		for _, desc in ipairs(real_char:GetDescendants()) do
			if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
				desc:Destroy();
			end
		end

		-- Build pre-resolved part and accessory handle map
		local part_map = {}
		for _, name in ipairs(part_names) do
			local rP = real_char:FindFirstChild(name)
			local fP = cloned_char:FindFirstChild(name)
			if rP and fP and rP:IsA("BasePart") and fP:IsA("BasePart") then
				table.insert(part_map, { name = name, real = rP, fake = fP })
			end
		end

		for _, rDesc in ipairs(real_char:GetDescendants()) do
			if rDesc:IsA("Accessory") then
				local rHandle = rDesc:FindFirstChild("Handle")
				local fAcc = cloned_char:FindFirstChild(rDesc.Name)
				local fHandle = fAcc and fAcc:FindFirstChild("Handle")
				if rHandle and fHandle and rHandle:IsA("BasePart") and fHandle:IsA("BasePart") then
					for _, w in ipairs(rDesc:GetDescendants()) do
						if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then
							w.Enabled = false
						end
					end
					table.insert(part_map, { name = rDesc.Name, real = rHandle, fake = fHandle })
				end
			end
		end

		-- Create NoCollisionConstraints between real parts and fake parts, and among real parts
		for i = 1, #part_map do
			local rP = part_map[i].real
			local fP = part_map[i].fake
			if rP and fP then
				pcall(function()
					local ncc = Instance.new("NoCollisionConstraint")
					ncc.Name = "ZenNCC_Clone"
					ncc.Part0 = rP
					ncc.Part1 = fP
					ncc.Parent = rP
				end)
			end
		end

		for i = 1, math.min(#part_map, 25) do
			for j = i + 1, math.min(#part_map, 25) do
				local p1 = part_map[i].real
				local p2 = part_map[j].real
				if p1 and p2 then
					pcall(function()
						local ncc = Instance.new("NoCollisionConstraint")
						ncc.Name = "ZenNCC_Real"
						ncc.Part0 = p1
						ncc.Part1 = p2
						ncc.Parent = p1
					end)
				end
			end
		end

		-- Save and protect ResetOnSpawn on PlayerGui ScreenGuis while swapping character
		local saved_gui_states = {};
		local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
		if player_gui then
			for _, gui in player_gui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.ResetOnSpawn then
					saved_gui_states[gui] = true;
					gui.ResetOnSpawn = false;
				end;
			end;
		end;

		player.Character = cloned_char;
		if workspace.CurrentCamera and cloned_humanoid then
			workspace.CurrentCamera.CameraSubject = cloned_humanoid;
		end

		for gui, _ in pairs(saved_gui_states) do
			if gui and gui.Parent then
				gui.ResetOnSpawn = true;
			end;
		end;

		local animate_script = cloned_char:FindFirstChild("Animate");
		if animate_script then
			animate_script.Disabled = false;
		end;
		cloned_humanoid:ChangeState(Enum.HumanoidStateType.Running)

		-- Handle ragdoll: if remote exists, fire it; otherwise, disable all real Motor6Ds for universal compatibility
		task.spawn(function()
			if remote then
				local err = fire_remote(remote, is_local_event, unpack(args or {}));
				if err then warn("Zen Reanimations ragdoll error: " .. tostring(err)) end;
			else
				pcall(function()
					for _, v in ipairs(real_char:GetDescendants()) do
						if v:IsA("Motor6D") then
							v.Enabled = false
						end
					end
				end)
			end
		end)

		-- Clear old connections
		for k, conn in pairs(zen.connections) do
			if conn then
				pcall(function() conn:Disconnect() end)
				zen.connections[k] = nil;
			end
		end

		-- ════════════════════════════════════════════════════════════════
		-- 3-STAGE SYNCHRONIZATION PIPELINE
		-- ════════════════════════════════════════════════════════════════

		local function is_part_hidden(entry, fake_char)
			if not _G.hiddenBodyParts then return false end
			if _G.hiddenBodyParts[entry.name] then return true end
			if _G.hiddenBodyParts["Head"] then
				local fP = entry.fake
				if fP and fP.Parent and fP.Parent:IsA("Accessory") then
					local att = fP:FindFirstChildOfClass("Attachment")
					if att and (att.Name:find("Hat") or att.Name:find("Hair") or att.Name:find("Face") or att.Name:find("Head")) then
						return true
					else
						local weld = fP:FindFirstChildOfClass("Weld") or fP:FindFirstChildOfClass("WeldConstraint") or fP:FindFirstChildOfClass("Motor6D")
						local head = fake_char and fake_char:FindFirstChild("Head")
						if weld and head and (weld.Part1 == head or weld.Part0 == head) then
							return true
						end
					end
				end
			end
			return false
		end

		-- 1. Stepped (PreSimulation): Maintain noclip and neutral humanoid state before physics step
		zen.connections.stepped = zen.services.run_service.Stepped:Connect(function()
			if not (real_char and real_char.Parent and cloned_char and cloned_char.Parent) then return end
			if real_humanoid and real_humanoid.Parent then
				pcall(function() real_humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
			end
			for i = 1, #part_map do
				local entry = part_map[i]
				local rP = entry.real
				local fP = entry.fake
				if rP and fP and rP.Parent and fP.Parent then
					rP.CanCollide = false
					if is_part_hidden(entry, cloned_char) then
						rP.CFrame = CFrame.new(0, 10000, 0)
					else
						rP.CFrame = fP.CFrame
					end
				end
			end
		end)

		-- 2. Heartbeat (PostSimulation): Apply CFrame alignment and velocity after physics simulation
		zen.connections.hb = zen.services.run_service.Heartbeat:Connect(function()
			if not (real_char and real_char.Parent and cloned_char and cloned_char.Parent) then
				API.reanimate(false, remote, args);
				return;
			end;

			local fakeHRP = cloned_char:FindFirstChild("HumanoidRootPart")
			local fHrpVel = fakeHRP and fakeHRP.AssemblyLinearVelocity or Vector3.zero
			local fHrpAngVel = fakeHRP and fakeHRP.AssemblyAngularVelocity or Vector3.zero

			for i = 1, #part_map do
				local entry = part_map[i]
				local rP = entry.real
				local fP = entry.fake
				if rP and fP and rP.Parent and fP.Parent then
					rP.Anchored = false
					rP.CanCollide = false
					if is_part_hidden(entry, cloned_char) then
						rP.CFrame = CFrame.new(0, 10000, 0)
						rP.AssemblyLinearVelocity = Vector3.zero
						rP.AssemblyAngularVelocity = Vector3.zero
					else
						rP.CFrame = fP.CFrame
						local pVel = fP.AssemblyLinearVelocity or fHrpVel
						local pAngVel = fP.AssemblyAngularVelocity or fHrpAngVel
						local smoothVel = (pVel.Magnitude > 0.05) and pVel or Vector3.new(0, -0.01, 0)
						rP.AssemblyLinearVelocity = smoothVel
						rP.AssemblyAngularVelocity = pAngVel
					end
				end
			end
		end)

		-- 3. RenderStepped (PreRender): Synchronize local CFrame right before rendering to eliminate shift-lock / camera jitter
		zen.connections.render = zen.services.run_service.RenderStepped:Connect(function()
			if not (real_char and real_char.Parent and cloned_char and cloned_char.Parent) then return end
			if real_humanoid and real_humanoid.Parent then
				real_humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				real_humanoid.NameDisplayDistance = 0
				real_humanoid.HealthDisplayDistance = 0
			end
			if cloned_humanoid and cloned_humanoid.Parent then
				cloned_humanoid.DisplayName = ""
				cloned_humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				cloned_humanoid.NameDisplayDistance = 0
				cloned_humanoid.HealthDisplayDistance = 0
			end
			for i = 1, #part_map do
				local entry = part_map[i]
				local rP = entry.real
				local fP = entry.fake
				if rP and fP and rP.Parent and fP.Parent then
					if is_part_hidden(entry, cloned_char) then
						rP.CFrame = CFrame.new(0, 10000, 0)
					else
						rP.CFrame = fP.CFrame
					end
				end
			end
		end)

		-- Lifecycle cleanup connections
		zen.connections.died = real_humanoid.Died:Connect(function()
			API.reanimate(false, remote, args);
		end);
		zen.connections.real_char_child_removed = real_char.ChildRemoved:Connect(function(child)
			if child == real_humanoid or child == real_hrp then
				API.reanimate(false, remote, args);
			end;
		end);
		zen.connections.clone_char_child_removed = cloned_char.ChildRemoved:Connect(function(child)
			if child == cloned_humanoid then
				API.reanimate(false, remote, args);
			end;
		end);
		zen.connections.clone_died = cloned_humanoid.Died:Connect(function()
			local current_real_humanoid = real_char and real_char:FindFirstChild("Humanoid");
			if current_real_humanoid and current_real_humanoid.Health > 0 then
				current_real_humanoid.Health = 0;
			else
				API.reanimate(false, remote, args);
			end;
		end);
		zen.connections.character_removing = player.CharacterRemoving:Connect(function(character_being_removed)
			if character_being_removed == cloned_char or character_being_removed == real_char then
				API.reanimate(false, remote, args);
			end;
		end);

		zen.flags.reanimated = true;
	else
		-- ════════════════════════════════════════════════════════════════
		-- SAFE REANIMATION DISABLE (Restoration Pipeline)
		-- ════════════════════════════════════════════════════════════════
		if not zen.flags.reanimated then
			return;
		end;

		API.stop_animation();

		-- Disconnect all active loops
		for key, connection in pairs(zen.connections) do
			if connection then
				pcall(function() connection:Disconnect() end);
				zen.connections[key] = nil;
			end;
		end;

		local cloned_char = zen.clones[player];
		local real_char = zen.real_chars[player];

		if real_char and real_char.Parent then
			local real_hum = real_char:FindFirstChildWhichIsA("Humanoid");
			local real_hrp = real_char:FindFirstChild("HumanoidRootPart");
			local fake_hrp = cloned_char and cloned_char:FindFirstChild("HumanoidRootPart");
			local targetCF = fake_hrp and fake_hrp.CFrame or (cloned_char and cloned_char:GetPivot()) or (real_hrp and real_hrp.CFrame);

			-- 1. Instantly snap position & zero out physics velocities
			if real_hrp and targetCF then
				real_hrp.CFrame = targetCF;
				real_hrp.AssemblyLinearVelocity = Vector3.zero;
				real_hrp.AssemblyAngularVelocity = Vector3.zero;
			end;

			-- 2. Restore humanoid states and collision properties
			if real_hum then
				pcall(function()
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
					real_hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
					real_hum.AutoRotate = true
					real_hum.PlatformStand = false
					real_hum.Sit = false
					real_hum.RequiresNeck = true
					real_hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
					real_hum.NameDisplayDistance = 100
					real_hum.HealthDisplayDistance = 100
					local defHip = real_hum:GetAttribute("ZenDefaultHipHeight")
					if defHip ~= nil then
						real_hum.HipHeight = defHip
					else
						real_hum.HipHeight = (real_hum.RigType == Enum.HumanoidRigType.R6) and 0 or (real_hum.HipHeight > 0 and real_hum.HipHeight or 2.0)
					end
					real_hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					real_hum:ChangeState(Enum.HumanoidStateType.Landed)
					real_hum:ChangeState(Enum.HumanoidStateType.Running)
				end)
			end;

			-- 3. Destroy constraints, re-enable joints, and restore visibility
			for _, v in ipairs(real_char:GetDescendants()) do
				if v:IsA("NoCollisionConstraint") then
					pcall(function() v:Destroy() end)
				elseif v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("WeldConstraint") then
					pcall(function() v.Enabled = true end)
				elseif v:IsA("BasePart") then
					pcall(function()
						v.Massless = false
						v.CanTouch = true
						v.CanQuery = true
						v.CustomPhysicalProperties = nil
						v.AssemblyLinearVelocity = Vector3.zero
						v.AssemblyAngularVelocity = Vector3.zero
						if v.Name ~= "HumanoidRootPart" then
							v.Transparency = 0
							v.LocalTransparencyModifier = 0
						else
							v.Transparency = 1
							v.LocalTransparencyModifier = 1
						end
						local n = v.Name
						if n == "UpperTorso" or n == "LowerTorso" or n == "Torso" then
							v.CanCollide = true
						else
							v.CanCollide = false
						end
					end)
				elseif v:IsA("Decal") then
					pcall(function() v.Transparency = 0 end)
				end;
			end;

			-- 4. Switch active character and camera subject
			local saved_gui_states = {};
			local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
			if player_gui then
				for _, gui in player_gui:GetChildren() do
					if gui:IsA("ScreenGui") and gui.ResetOnSpawn then
						saved_gui_states[gui] = true;
						gui.ResetOnSpawn = false;
					end;
				end;
			end;

			player.Character = real_char;
			if workspace.CurrentCamera and real_hum then
				workspace.CurrentCamera.CameraSubject = real_hum;
			end

			for gui, _ in pairs(saved_gui_states) do
				if gui and gui.Parent then
					gui.ResetOnSpawn = true;
				end;
			end;

			local fake_animate = cloned_char and cloned_char:FindFirstChild("Animate")
			if fake_animate then fake_animate:Destroy() end

			local real_animate = real_char:FindFirstChild("Animate");
			if real_animate and real_animate:IsA("LocalScript") then
				real_animate.Disabled = true;
				task.wait();
				real_animate.Disabled = false;
			end;

			-- 5. Hold position for 3 frames so physics doesn't drop character during transition
			if real_hrp and targetCF then
				local anchorFrames = 0
				local anchorConn
				anchorConn = zen.services.run_service.Heartbeat:Connect(function()
					anchorFrames = anchorFrames + 1
					if real_hrp and real_hrp.Parent then
						real_hrp.CFrame = targetCF
						real_hrp.AssemblyLinearVelocity = Vector3.zero
						real_hrp.AssemblyAngularVelocity = Vector3.zero
					end
					if anchorFrames >= 3 then
						anchorConn:Disconnect()
					end
				end)
			end
		end;

		-- 6. Fire unragdoll signals in background
		task.spawn(function()
			if remote then
				for _ = 1, 3 do
					pcall(function() fire_remote(remote, is_local_event, unpack(args or {})) end)
					task.wait(0.05)
				end
			end
		end)

		if cloned_char and cloned_char.Parent then
			cloned_char:Destroy();
		end;
		zen.clones[player] = nil;
		zen.real_chars[player] = nil;
		zen.flags.reanimated = false;
	end;
end;

--- Plays an animation on the reanimated character.
-- @param url (string) - The URL of the keyframe script.
-- @param speed (number) [optional] - The playback speed multiplier. Defaults to 1.
API.play_animation = function(url, speed)
	if not zen.flags.reanimated then
		return "Cannot play animation, not reanimated.";
	end
    
	local player = get_local_player();
	if typeof(player) == "string" then return player end;
    
	local clone_char = API.get_clone(player);
	if not clone_char then 
		return "Cannot play animation, clone character not found.";
	end
    
	if zen.animation.state.is_playing and zen.animation.state.current_url == url then
		API.stop_animation();
		return;
	end
    
	API.stop_animation();
    
	local clone_anim_controller = clone_char:FindFirstChildOfClass("Humanoid") or clone_char:FindFirstChildOfClass("AnimationController")
	if clone_anim_controller then
		for _, track in ipairs(clone_anim_controller:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end
	local clone_animate_script = clone_char:FindFirstChild("Animate")
	if clone_animate_script then
		clone_animate_script.Disabled = true
	end
    
	local anim = zen.animation;
	anim.state.speed = tonumber(speed) or 1.0;

	local keyframe_data = anim.cache[url];
	if not keyframe_data then
		local response
		if typeof(url) == "table" then
			keyframe_data = url
		elseif typeof(url) == "string" and (url:find("^%s*return") or url:find("^%s*{") or url:find("^%s*%-%-")) then
			response = url
		elseif typeof(url) == "string" and url:sub(1, 4) == "http" then
			local cache_path
			if isfolder and makefolder and isfile and readfile and writefile then
				if not isfolder("ZenAnimCache") then
					pcall(makefolder, "ZenAnimCache")
				end
				local safe_name = url:match("([^/]+)$") or "unknown.lua"
				safe_name = safe_name:gsub("%%20", "_"):gsub("%%27", "")
				cache_path = "ZenAnimCache/" .. safe_name
			end
            
			if cache_path and isfile(cache_path) then
				local success, file_res = pcall(readfile, cache_path)
				if success then
					response = file_res
				end
			end
            
			if not response then
				local success, http_res = pcall(game.HttpGet, game, url);
				if not success then return "Animation Error: Failed to fetch URL." end
				response = http_res
                
				if cache_path then
					pcall(writefile, cache_path, response)
				end
			end
		else
			if type(readfile) == "function" then
				local success, file_res = pcall(readfile, url)
				if not success then return "Animation Error: Failed to read local file." end
				response = file_res
			else
				return "Animation Error: Cannot load local file (readfile not supported)."
			end
		end
        
		-- Custom regex parser for animation files
		local is_custom_format = false
		if response:match("{Time%s*=") then
			local frames = {}
			for t_str, data_block in response:gmatch("{Time%s*=%s*([%d%.]+),%s*Data%s*=%s*{(.-)}}") do
				local t_val = tonumber(t_str)
				local frame_data = {}
				for part, args in data_block:gmatch('%["([^"]+)"%]%s*=%s*CFrame%.new%(([^%)]+)%)') do
					local n = {}
					for num in args:gmatch("([^,%s]+)") do
						table.insert(n, tonumber(num))
					end
					if #n == 12 then
						frame_data[part] = CFrame.new(n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8], n[9], n[10], n[11], n[12])
					end
				end
				table.insert(frames, {Time = t_val, Data = frame_data})
			end
			if #frames > 0 then
				is_custom_format = true
				local anim_name = url:match("([^/\\]+)%.lua$") or "CustomAnim"
				keyframe_data = {[anim_name] = frames}
			end
		end

		if not is_custom_format then
			local loaded_fn, err = loadstring(response);
			if not loaded_fn then return "Animation Error: Invalid script from URL. " .. tostring(err) end;
			local success, data = pcall(loaded_fn)
			if not success then return "Animation Error: Script from URL failed to execute. " .. tostring(data) end
			keyframe_data = data;
		end

		if typeof(keyframe_data) ~= "table" then return "Animation Error: Script from URL did not return a table." end;
        
		anim.cache[url] = keyframe_data;
	end

	local keyframes = keyframe_data[next(keyframe_data)];
	if not keyframes or #keyframes == 0 then
		return "No keyframes array found for animation URL: " .. url;
	end

	anim.state.keyframes = keyframes;

	table.clear(anim.joints);
	table.clear(anim.original_motor_c0s);

	for _, descendant in ipairs(clone_char:GetDescendants()) do
		if descendant:IsA("JointInstance") then
			if descendant.Part1 then
				anim.joints[descendant.Part1.Name] = descendant;
			else
				anim.joints[descendant.Name] = descendant;
			end
			if descendant:IsA("Motor6D") or descendant:IsA("Motor") or descendant:IsA("Weld") then
				anim.original_motor_c0s[descendant] = descendant.C0;
			end
		elseif descendant:IsA("Bone") then
			anim.joints[descendant.Name] = descendant;
			anim.original_motor_c0s[descendant] = descendant.Transform;
		elseif descendant:IsA("AnimationConstraint") then
			if descendant.Part1 then
				anim.joints[descendant.Part1.Name] = descendant;
			else
				anim.joints[descendant.Name] = descendant;
			end
			anim.original_motor_c0s[descendant] = descendant.Transform;
		end
	end

	local found_joints = 0
	local required_joints = 0

	for partName, _ in pairs(keyframes[1].Data) do
		required_joints = required_joints + 1
		if anim.joints[partName] then found_joints = found_joints + 1 end
	end
    
	if found_joints == 0 then
		return "Animation Error: NO JOINTS MATCH! Are you using an R6 avatar for an R15 animation? Or did another script break your joints?"
	end

	anim.state.is_playing = true;
	anim.state.current_url = url;
	anim.state.total_duration = keyframes[#keyframes].Time;
	if anim.state.total_duration <= 0 then API.stop_animation(); return end;
	
	anim.state.elapsed_time = 0;
	
	if zen.callbacks.on_play then
		pcall(zen.callbacks.on_play, anim.state.current_url)
	end
	
	-- Fast O(1) / O(log N) keyframe evaluation loop
	local last_index = 1
	zen.connections.animation_hb = zen.services.run_service.Stepped:Connect(function(time, deltaTime)
		if not anim.state.is_playing then return end;
		
		anim.state.elapsed_time = (anim.state.elapsed_time + (deltaTime * anim.state.speed)) % anim.state.total_duration;
		
		local kfs = anim.state.keyframes
		local elapsed = anim.state.elapsed_time
		local num_keyframes = #kfs
		local current_frame, next_frame

		if not last_index or last_index >= num_keyframes then
			last_index = 1
		end

		if elapsed >= kfs[last_index].Time and (last_index == num_keyframes or elapsed < kfs[last_index + 1].Time) then
			current_frame = kfs[last_index]
			next_frame = kfs[last_index == num_keyframes and 1 or last_index + 1]
		elseif last_index < num_keyframes and elapsed >= kfs[last_index + 1].Time and (last_index + 1 == num_keyframes or elapsed < kfs[last_index + 2].Time) then
			last_index = last_index + 1
			current_frame = kfs[last_index]
			next_frame = kfs[last_index == num_keyframes and 1 or last_index + 1]
		else
			local low = 1
			local high = num_keyframes - 1
			local found = 1
			while low <= high do
				local mid = math.floor((low + high) / 2)
				if elapsed >= kfs[mid].Time then
					found = mid
					low = mid + 1
				else
					high = mid - 1
				end
			end
			last_index = found
			current_frame = kfs[last_index]
			next_frame = kfs[last_index == num_keyframes and 1 or last_index + 1]
		end

		if not current_frame then
			current_frame = kfs[num_keyframes]
			next_frame = kfs[1]
		end

		local frame_duration = next_frame.Time - current_frame.Time;
		if frame_duration <= 0 then frame_duration = anim.state.total_duration end;

		local alpha = (frame_duration > 0) and (elapsed - current_frame.Time) / frame_duration or 0;
		alpha = math.clamp(alpha, 0, 1)

		for partName, pose_cframe in pairs(current_frame.Data) do
			local motor = anim.joints[partName];
			if motor then
				local next_pose_cframe = next_frame.Data and next_frame.Data[partName];
				local target_pose = next_pose_cframe and pose_cframe:Lerp(next_pose_cframe, alpha) or pose_cframe;
				motor.Transform = target_pose;
			end
		end
	end);
end;

--- Sets the playback speed for any currently playing animation.
-- @param speed (number) - The new playback speed multiplier.
API.set_animation_speed = function(speed)
	zen.animation.state.speed = tonumber(speed) or 1.0;
end;

--- Registers a callback function to be called when an animation starts playing.
-- @param callback (function) - The function to call. It receives the animation URL as an argument.
API.on_animation_play = function(callback)
	if type(callback) == "function" then
		zen.callbacks.on_play = callback
	end
end

--- Registers a callback function to be called when an animation stops.
-- @param callback (function) - The function to call. It receives the animation URL that was stopped.
API.on_animation_stop = function(callback)
	if type(callback) == "function" then
		zen.callbacks.on_stop = callback
	end
end

--- Returns the current animation playback state.
-- @return boolean, string | nil - is_playing, current_url
API.is_animation_playing = function()
	return zen.animation.state.is_playing, zen.animation.state.current_url
end

--- Returns true if the local player is currently reanimated.
-- @return boolean
API.is_reanimated = function()
	return zen.flags.reanimated;
end;

--- Gets the active clone character model for a player.
-- @param player (Player) [optional] - The player to get the clone of. Defaults to LocalPlayer.
-- @return Model | nil
API.get_clone = function(player)
	player = player or get_local_player();
	if typeof(player) == "string" then return nil end;
	return zen.clones[player];
end;

--- Gets the real character model for a player.
-- @param player (Player) [optional] - The player to get the real character of. Defaults to LocalPlayer.
-- @return Model | nil
API.get_real_character = function(player)
	player = player or get_local_player();
	if typeof(player) == "string" then return nil end;
	return zen.real_chars[player];
end;

--- Preloads and caches an animation in the background without playing it
-- @param url (string) - The URL of the keyframe script.
API.preload_animation = function(url)
	if not (url and url:sub(1, 4) == "http") then return end
	if not (isfolder and makefolder and isfile and readfile and writefile) then return end
    
	local safe_name = url:match("([^/]+)$") or "unknown.lua"
	safe_name = safe_name:gsub("%%20", "_"):gsub("%%27", "")
	local cache_path = "ZenAnimCache/" .. safe_name
    
	if not isfolder("ZenAnimCache") then
		pcall(makefolder, "ZenAnimCache")
	end
    
	if not isfile(cache_path) then
		local success, http_res = pcall(game.HttpGet, game, url);
		if success then
			pcall(writefile, cache_path, http_res)
		end
	end
end

--- Sets visibility state for a specific body part (Head, Torso, Arms, Legs)
API.set_limb_visibility = function(partName, visible)
	_G.hiddenBodyParts = _G.hiddenBodyParts or {}
	if visible then
		_G.hiddenBodyParts[partName] = nil
	else
		_G.hiddenBodyParts[partName] = true
	end
end;

--- Checks if a body part is currently set to hidden
API.is_limb_hidden = function(partName)
	return (_G.hiddenBodyParts and _G.hiddenBodyParts[partName] == true) or false
end;

--- Restores visibility for all hidden body parts
API.unhide_all_limbs = function()
	if _G.hiddenBodyParts then
		table.clear(_G.hiddenBodyParts)
	end
end;

return API;
