# ZEN METHOD REANIM 

A massive, fully cloud-hosted custom reanimation suite for Roblox executors featuring over 1,800+ animations, a sleek macOS-inspired UI, dynamic keybinding, and zero local dependencies.

---

## 🚀 The Universal Loadstring
You can execute the entire suite from any modern Roblox executor without downloading a single file. Paste the following into your executor and run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/obfrunner.lua"))()
```

*(Note: Your custom keybinds and favorite animations will be automatically saved locally to `ZenReanimConfig.json` in your executor's workspace, so your preferences persist between sessions!)*

---

## 🛠️ The Journey: How We Figured It Out
*A note for the developer enthusiasts diving into this repository.*

Building a flawless, high-performance reanimation suite that supports thousands of custom `.lua` animation files without completely locking up the executor was an architectural challenge. Here is a breakdown of the hurdles we faced and how we architected the "Zen Method" to solve them:

### 1. Separation of Concerns (Frontend vs. Engine)
Originally, many reanimation scripts bundle everything into one massive, unreadable file. We separated the architecture into two distinct halves:
- **`module.lua` (The Engine)**: This handles the raw, complex physics. It creates the dummy clone, strips the player's physical collisions, hides the real body, and performs the intense CFrame interpolation required to play custom animation keyframes on the rig. 
- **`runner.lua` (The Frontend)**: This acts as the remote control. It builds the interactive UI, manages keybinds, and communicates with the engine. 

By separating them, `module.lua` became highly stable, and `runner.lua` could be endlessly customized with new UI elements and features without breaking the core physics engine.

### 2. Overcoming the Keybind Memory Leak
One of the most complex issues was the implementation of dynamic keybinds. Initially, attaching `UserInputService.InputBegan` listeners inside a loop for every animation caused a severe memory leak. Every time a player assigned a keybind, it created an overlapping event listener. Pressing a keybind would cause multiple animations to attempt execution simultaneously, crashing the engine.

**The Solution:** We completely decoupled the keybind execution from the UI list. We implemented a single, global `UserInputService` controller. The UI now simply updates a centralized dictionary `savedConfig.binds[key.Name] = animationName`. The global listener checks this dictionary exactly once per input, firing off a lightweight `task.spawn` to cleanly run the animation in an asynchronous thread. No overlapping loops, no memory leaks.

### 3. Transitioning from Local to the Cloud
Because the suite includes over 1,800 custom `.lua` animations, the original method required users to download an 800+ Megabyte folder and place it directly in their executor's local workspace. This was tedious and bloated.

To transition to a purely cloud-hosted architecture, we encountered the **GitHub API Rate Limit** (60 requests per hour). If `runner.lua` used the GitHub API to fetch the directory contents dynamically, casual users would instantly hit the rate limit and the script would break.

**The Solution (`animations.json`):** Instead of using the API or local `listfiles`, we generated a static `animations.json` file inside the repository containing a pre-computed map of all 1,849 animations and their direct, raw GitHub download URLs. 
Now, `runner.lua` makes a single, unauthenticated HTTP request to fetch `animations.json`. It parses the file instantly, populates the UI, and when a user clicks an animation, `module.lua` streams that specific animation's keyframes directly from GitHub.

The result is a zero-dependency, lightning-fast cloud loader.

### 4. Bypassing the Reanimation Patches (The CBody Method)
Historically, reanimating involved destroying the character's joints and using basic loops to teleport the parts. However, recent Roblox physics updates and anti-exploits (especially in popular games like Mic Up) heavily patched these old methods, causing parts to freeze, fall through the map, or fail to replicate to the server.

**The Solution (CBody/Clone Trickery):** This new method bypasses those patches entirely. Instead of just breaking the original character, the engine creates a perfect local clone (the "CBody") that the client animates flawlessly using CFrame interpolation. The engine then hides your real, raw character (usually by displacing the `HumanoidRootPart` or scaling it down) and exploits **Network Ownership**. Because the client still retains physics ownership over their own unanchored limbs, we rapidly snap the real limbs to the CBody's animated limbs. This tricks the Roblox server into accepting the physics data and replicating your custom animations to everyone else in the server, bypassing modern collision and replication patches completely!

---

## 🎨 Features
* **Minimalist UI**: Clean, macOS-inspired window controls (Red/Yellow dots) without unnecessary branding or clutter.
* **Integrated Speed Slider**: Dynamically adjust the playback speed of the active reanimation on the fly.
* **Favorites System**: Pin your favorite animations to a dedicated tab for quick access.
* **Persistent Keybinds**: Assign any key to any animation for instant execution, saved permanently across gaming sessions.

---
*Created and refined through the Zen Method.*
