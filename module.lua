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
	};
	clones = {};
	connections = {
		hb = nil;
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

local API = {};

local get_game_ragdoll_info = function(enable)
	local place_id = game.PlaceId;
	if place_id == 15546218972 or place_id == 6884319169 then
		-- Mic Up and Mic Up 18+
		local remote = zen.services.replicated:WaitForChild("event_rag");
		return remote, {"Ball"}, false;
	elseif place_id == 5991163185 then
		-- Spray Paint
		local remote = zen.services.replicated.Remotes.Physics.Ragdoll;
		return remote, {}, false;
	elseif place_id == 5683833663 then
		-- Ragdoll Engine (uses LocalEvent, not RemoteEvent)
		local local_event = zen.services.replicated:WaitForChild("LocalRagdollEvent");
		return local_event, {enable}, true;
	end;
	return nil, nil, false;
end;

local set_model_transparency = function(model, transparency)
	if not model then
		return;
	end;
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
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
    
    -- Manually reconstruct any missing Motor6Ds (bypasses games that break Clone())
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("Motor6D") and desc.Part0 and desc.Part1 then
            local p0_name = desc.Part0.Name
            local p1_name = desc.Part1.Name
            
            -- Check if the clone already has this joint
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
	new_clone:WaitForChild("Animate").Disabled = true;
    new_clone.Humanoid.RequiresNeck = false;
    new_clone.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;
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
		-- Handle local events (BindableEvent)
		if not remote:IsA("BindableEvent") then
			return ("bad argument to 'fire_remote' (BindableEvent expected for local event, got %s)"):format(remote.ClassName);
		end;
		remote:Fire(...);
	else
		-- Handle remote events/functions
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
		if not real_char:FindFirstChild("Humanoid") then
			return "Real character is missing a Humanoid.";
		end;
		local real_hrp = real_char:FindFirstChild("HumanoidRootPart")
		if not real_hrp then
			return "Real character is missing a HumanoidRootPart, cannot reanimate.";
		end
		zen.real_chars[player] = real_char;
		local cloned_char = clone_char(real_char);
        if typeof(cloned_char) == "string" then return cloned_char end;
		if not cloned_char:FindFirstChild("Humanoid") then
			return "Cloned character failed to create or is missing a Humanoid.";
		end;
		zen.clones[player] = cloned_char;
		set_model_transparency(cloned_char, 1);
		local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
		if player_gui then
			for _, gui in player_gui:GetChildren() do
				if gui:IsA("ScreenGui") then
					saved_gui_states[gui] = gui.ResetOnSpawn;
					gui.ResetOnSpawn = false;
				end;
			end;
		end;
		player.Character = cloned_char;
		cloned_char:WaitForChild("Animate").Disabled = true;
		cloned_char:WaitForChild("Animate").Disabled = false;
		task.spawn(function()
			task.wait();
			if player_gui then
				for gui, state in pairs(saved_gui_states) do
					if gui and gui.Parent then
						gui.ResetOnSpawn = state;
					end;
				end;
			end;
		end);
		zen.connections.hb = zen.services.run_service.Heartbeat:Connect(function()
			if not real_char or not real_char.Parent or not cloned_char or not cloned_char.Parent then
				API.reanimate(false, remote, args);
				return;
			end;
			for _, p in real_char:GetChildren() do
				local clone_part = cloned_char:FindFirstChild(p.Name);
				if p:IsA("BasePart") and clone_part then
					p.CFrame = clone_part.CFrame;
					p.Velocity = Vector3.new();
				end;
			end;
		end);
		local real_humanoid = real_char.Humanoid;
		local cloned_humanoid = cloned_char.Humanoid;
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
		if remote then
			local err = fire_remote(remote, is_local_event, unpack(args or {}));
            if err then return err end;
		end;
		zen.flags.reanimated = true;
	else
		if not zen.flags.reanimated then
			return;
		end;
        API.stop_animation();
		if remote then
			local err = fire_remote(remote, is_local_event, unpack(args or {}));
            if err then return err end;
		end;
		for key, connection in pairs(zen.connections) do
			if connection then
				connection:Disconnect();
				zen.connections[key] = nil;
			end;
		end;
		local cloned_char = zen.clones[player];
		if cloned_char and cloned_char.Parent then
			cloned_char:Destroy();
			zen.clones[player] = nil;
		end;
		local real_char = zen.real_chars[player];
		if real_char and real_char.Parent then
			set_model_transparency(real_char, 0);
			local hrp = real_char:FindFirstChild("HumanoidRootPart");
			if hrp then
				hrp.Transparency = 1;
			end;
			local player_gui = player:FindFirstChildWhichIsA("PlayerGui");
			if player_gui then
				for _, gui in player_gui:GetChildren() do
					if gui:IsA("ScreenGui") then
						saved_gui_states[gui] = gui.ResetOnSpawn;
						gui.ResetOnSpawn = false;
					end;
				end;
			end;
			player.Character = real_char;

            local animator = real_char:FindFirstChild("Humanoid") and real_char.Humanoid:FindFirstChild("Animator");
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop();
                end
            end

            local animate_script = real_char:FindFirstChild("Animate");
			if animate_script and animate_script:IsA("LocalScript") then
				animate_script.Disabled = true;
				task.wait();
				animate_script.Disabled = false;
			end;
			task.spawn(function()
				task.wait();
				if player_gui then
					for gui, state in pairs(saved_gui_states) do
						if gui and gui.Parent then
							gui.ResetOnSpawn = state;
						end;
					end;
				end;
			end);
		end;
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
        if url:sub(1, 4) == "http" then
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
        
        -- Custom regex parser for giant animation files to prevent executor crash
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
    local real_char = get_char(player)
    
    local constraints = ""

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
	
    warn("Zen Reanimations: Successfully loaded and started animation! Duration: " .. tostring(anim.state.total_duration))

	
	if zen.callbacks.on_play then
		pcall(zen.callbacks.on_play, anim.state.current_url)
	end
	
	zen.connections.animation_hb = zen.services.run_service.Stepped:Connect(function(time, deltaTime)
		if not anim.state.is_playing then return end;
		
		anim.state.elapsed_time = (anim.state.elapsed_time + (deltaTime * anim.state.speed)) % anim.state.total_duration;
		
		local current_frame, next_frame;
		for i = 1, #anim.state.keyframes - 1 do
			if anim.state.elapsed_time >= anim.state.keyframes[i].Time and anim.state.elapsed_time < anim.state.keyframes[i+1].Time then
				current_frame = anim.state.keyframes[i];
				next_frame = anim.state.keyframes[i+1];
				break;
			end
		end
		if not current_frame then
			current_frame = anim.state.keyframes[#anim.state.keyframes];
			next_frame = anim.state.keyframes[1];
		end
		
		local frame_duration = next_frame.Time - current_frame.Time;
		if frame_duration <= 0 then frame_duration = anim.state.total_duration end;

		local alpha = (frame_duration > 0) and (anim.state.elapsed_time - current_frame.Time) / frame_duration or 0;
		alpha = math.clamp(alpha, 0, 1)

		for partName, pose_cframe in pairs(current_frame.Data) do
            local motor = anim.joints[partName];
            if motor then
                local next_pose_cframe = next_frame.Data and next_frame.Data[partName];

                if next_pose_cframe then
                    motor.Transform = pose_cframe:Lerp(next_pose_cframe, alpha);
                else
                    motor.Transform = pose_cframe;
                end
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

return API;
