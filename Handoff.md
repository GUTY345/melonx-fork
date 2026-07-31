# MeloNX Fork - iPhone 16 Plus + iPad Air M3 Optimization Handoff

## Current Session Update - 2026-07-26

Primary optimization target is now **both iPhone 16 Plus and iPad Air M3**, not iPad Air M3 alone.

### Changes Made This Session

- Added `MobileDevicePerformanceClass` and `MobileProfileManager` in `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`.
- Launch path now uses `MobileProfileManager` instead of applying `M3ProfileManager` to every device.
- Added iPhone 16 Plus baseline profile: `resScale = 0.8`, `maxAnisotropy = 4`, `expandRam = false`, thermal stability on.
- Added iPad Air M3 baseline profile: `resScale = 0.9`, `maxAnisotropy = 8`, `expandRam = false`, thermal stability on.
- `Ryujinx.Arguments.applyPerformanceDefaults()` now uses mobile profile policy for `expandRam` instead of enabling it on every 8GB device.
- Swift launch args now pass `--enable-texture-recompression` when enabled.
- Replaced fragile C# `#if __APPLE__` and `#if __IOS__` optimization branches with runtime `OperatingSystem.IsMacOS()` / `OperatingSystem.IsIOS()` checks.
- Background translation thread formula is now `(Environment.ProcessorCount - 2) / 3` on Apple platforms, capped at 4. Target result: A18 6-core -> 1 thread, M3 8-core -> 2 threads.
- Fixed `AppleSystemMemory.GetPhysicalMemory()` null-pointer dereference risk by passing a real `ulong` buffer to `sysctlbyname`.

### Files Changed This Session

- `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`
- `src/MeloNX/MeloNX/App/UI/Main/Home/LaunchGameHandler.swift`
- `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift`
- `src/ARMeilleure/Translation/Translator.cs`
- `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs`
- `src/Ryujinx.Common/SystemInfo/AppleSystemMemory.cs`
- `todo.md`
- `Handoff.md`

### Important Follow-Up

- Build validation is still required. `xcodebuild -list` works with Xcode 26.3, but `dotnet` was not available in PATH during this session.
- Physical-device validation is still required on iPhone 16 Plus and iPad Air M3.
- Do not rely on old notes that say M3 uses `(ProcessorCount - 4) / 3`; that was integer-dividing to 1 thread on 8-core M3 and has been corrected.

## Project Summary

MeloNX Fork is an iOS/iPadOS-focused downstream fork of MeloNX (Ryujinx-based Nintendo Switch emulator). The project targets mobile devices with specific attention to thermal limits, memory pressure, and sustained frame pacing.

```
Repository Root: /Users/apple/Desktop/melonx-fork-main
Branch: main
Git: NOT initialized (no .git directory)
Platforms: iOS / iPadOS
Backend: MoltenVK (Vulkan to Metal translation)
CPU/JIT: ARMeilleure ARM recompiler with background translation threads
App Framework: SwiftUI + native C# runtime through RyujinxBridge
iOS SDK: Xcode + .NET iOS workload
Swift Version: 6.2.3
.NET SDK: 8.0.100
Device Target: iPad Air M3 (8-core CPU: 4P + 4E, 9-core GPU, 8GB unified RAM)
```

## Key Entitlements

```
com.apple.developer.kernel.increased-memory-limit = true
com.apple.developer.kernel.extended-virtual-addressing = true (extended only)
```

## What Works Right Now

- JIT initialization (dual-mapped or legacy)
- MoltenVK rendering via Vulkan to Metal translation
- ARMeilleure background translation threads
- Thermal governor (3-state: nominal/warning/critical)
- Auto-performance governor with FPS-based response
- Shader warmup (simulated currently)
- Per-game settings via NativeSettingsManager
- Metal view rendering for game display

## Tech Stack Details

### Core Emulation
- **ARMeilleure**: ARM87 instruction emulator/jit compiler (`src/ARMeilleure/`)
- **Ryujinx.Cpu**: CPU emulation with LightningJit (`src/Ryujinx.Cpu/`)
- **Ryujinx.HLE**: HLE services, kernel, Horizon OS (`src/Ryujinx.HLE/`)
- **Ryujinx.Memory**: Memory management with Unix/Windows abstraction (`src/Ryujinx.Memory/`)

### Graphics Pipeline
- **Ryujinx.Graphics.Vulkan**: Primary renderer via MoltenVK
- **Ryujinx.Graphics.GAL**: Graphics Abstraction Layer
- **Ryujinx.Graphics.Gpu**: GPU device emulation, shader compilation, texture/buffer management
- **Ryujinx.Graphics.Shader**: Shader translation (guest to host)
- **Ryujinx.Graphics.Texture**: Texture format handling
- **Ryujinx.Graphics.Video/Video.Nvdec**: Video decode hardware acceleration

### Audio
- **Ryujinx.Audio**: Core audio rendering
- **Ryujinx.Audio.Backends.Apple**: Core Audio backend (default for iOS)
- **Ryujinx.Audio.Backends.OpenAL**: OpenAL fallback
- **Ryujinx.Audio.Backends.SDL2**: SDL2 cross-platform
- **Ryujinx.Audio.Backends.SoundIo**: Linux-focused

### Input
- **Ryujinx.Input**: Input abstraction
- **Ryujinx.Input.SDL2**: SDL2 gamepad/keyboard
- HID/Npad emulation in `src/Ryujinx.HLE/HOS/Services/Hid/`

### iOS App Shell
- **SwiftUI** UI in `src/MeloNX/MeloNX/App/UI/`
- **RyujinxBridge**: Managed/Unmanaged interop bridge between Swift and C#
- **NativeSettingsManager**: Swift-side settings persistence
- **MetalView**: CAMetalLayer hosting for game output

---

## Optimization Plan for iPad Air M3

### P0 - High Priority / Quick Wins

#### 1. Background Translation Thread Count
**File**: `src/ARMeilleure/Translation/Translator.cs:120-121`
**Issue**: Formula `(Environment.ProcessorCount - 6) / 3` returns 0 on 6-core, clamped to 1 thread. M3 has 8 cores (4P+4E) that can spare 2 E-cores.
**Change**: Add Apple Silicon path using `#if __APPLE__` to return `Math.Max(1, (Environment.ProcessorCount - 4) / 3)` or fixed mapping `2` threads for M3-class.
**Effort**: Low | **Impact**: High

#### 2. MoltenVK Configuration
**File**: `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs:32`
**Issue**: Only `ResumeLostDevice` is set. Missing argument buffers, prefill, and shader compression configs.
**Change**: Add:
```
config.UseMetalArgumentBuffers = true;
config.PrefillMetalCommandBuffers = true;
config.SynchronousQueueSubmits = false;
config.SwapchainMagFilterUseNearest = false;
config.MaxActiveMetalCommandBuffersPerQueue = 128;
```
**File**: `src/MeloNX/MeloNX/App/UI/MeloNXApp.swift:36-38`
Uncomment `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` and `MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM = 4` (ASTC).
**Effort**: Low | **Impact**: High

### P1 - High Priority / Medium Effort

#### 3. Shader Compilation Thread Scaling
**File**: `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs:223`
**Issue**: `Math.Min(Environment.ProcessorCount, 8)` threads for parallel compile can cause thermal spikes on mobile.
**Change**: Use capped threads for mobile:
```
#if __IOS__
_backendParallelCompileThreads = Math.Min(Environment.ProcessorCount, 4);
#else
_backendParallelCompileThreads = Math.Min(Environment.ProcessorCount, 8);
#endif
```
Add thermal-aware scaling using `ProcessInfo.thermalState` to reduce threads further in `.warning`/`.critical` states.
**Effort**: Low | **Impact**: Medium-High

#### 4. Thermal Governor Enhancement (4-Tier)
**File**: `src/MeloNX/MeloNX/App/Core/Ryujinx/ThermalGovernor.swift`
**Issue**: Only 3 states, no hysteresis, direct jump to 30 FPS on warning.
**Change**: Add `.warm` tier between `.nominal` and `.warning`. Cap at 45 FPS in `.warm`, 30 FPS in `.warning`/`.critical`. Add hysteresis so thermal downstep waits for lower temp.
**Effort**: Medium | **Impact**: High

#### 5. TBDR + ASTC Texture Compression
**File**: `src/Ryujinx.Graphics.Vulkan/VulkanRenderer.cs:742`
**Issue**: `supportsAstcCompression` is computed from format support, but `EnableTextureRecompression` defaults to `false` (`ConfigurationState.cs:808`).
**Change**: Default `EnableTextureRecompression = true` on iOS/iPadOS. Add M3-specific ASTC preference path to TextureRecompression.
**Effort**: Low | **Impact**: Medium

#### 6. AutoPerformanceGovernor Coordination
**File**: `src/MeloNX/MeloNX/App/Core/Ryujinx/AutoPerformanceGovernor.swift`
**Issue**: Governor adjusts resolution and anisotropy but not fully coordinated with ThermalGovernor.
**Change**: Add callback/listener so when ThermalGovernor changes FPS cap, AutoPerformanceGovernor can also adjust resScale and PTC accordingly.
**Effort**: Medium | **Impact**: Medium-High

### P2 - Medium Priority

#### 7. Memory Management for 8GB UMA
**Files**: `src/Ryujinx.Memory/MemoryManagementUnix.cs`, entitlements
**Issue**: No M3-specific memory tuning for 8GB unified RAM.
**Change**: Set dynamic shader cache limit based on `NSProcessInfo.physicalMemory`. Disable `ExpandRam` default collision with extended virtual addressing. Consider per-game override for texture-heavy games.
**Effort**: Medium | **Impact**: Medium

#### 8. Background QoS Classification
**File**: Multiple Swift files
**Issue**: Background tasks may use default QoS instead of appropriate utility/background classes.
**Change**: Audit all `DispatchQueue.global()` calls. Set `qos: .utility` for warmup/file ops, `.userInteractive` for gameplay, `.userInitiated` for JIT work.
**Effort**: Low | **Impact**: Medium

#### 9. Frame Pacing / preferredFrameRateRange
**File**: `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MetalView.swift`
**Issue**: No adaptive refresh rate handling for ProMotion displays.
**Change**: When thermal governor sets 30 FPS cap, set `preferredFrameRateRange` to `30...30`. When cap is 60, use `60...120`. Use `CADisplayLink.preferredFrameRateRange`.
**Effort**: Medium | **Impact**: Medium

### P3 - Lower Priority / Nice to Have

#### 10. Per-Game M3 Profile Database
**Files**: Settings UI + per-game settings manager
**Change**: Add JSON or plist with known-good M3 settings per titleId. Load automatically on game launch.
**Effort**: High | **Impact**: Low-Medium

#### 11. Pipeline State Cache Tuning for MoltenVK
**Files**: `src/Ryujinx.Graphics.Vulkan/PipelineLayoutFactory.cs`, `PipelineState.cs`
**Change**: Verify pipeline caches are fully populated on M3. Consider larger cache sizes for 8GB RAM.
**Effort**: Medium | **Impact**: Low-Medium

### Not Recommended / Deferred

- Switching to Metal native backend (Ryujinx.Graphics.Metal does not exist; only OpenGL/Vulkan)
- Disabling JIT or falling back to interpreter on thermal events
- Custom SPIRV-to-Metal shader translation outside MoltenVK

---

## TODO.md - Work Tracker

All tasks should be tracked here. Update status as work progresses. Use this file to resume work on a new session.

```markdown
# MeloNX Fork - iPad Air M3 Optimization TODO

Legend:
- [ ] Not started
- [~] In progress
- [x] Completed
- [-] Cancelled / On hold

## P0 - Quick Wins

### 1. Background Translation Thread Count
- [ ] Edit `src/ARMeilleure/Translation/Translator.cs` lines 120-138
- [ ] Add `#if __APPLE__` branch for Apple Silicon thread mapping
- [ ] Ensure QoS class `.utility` on background threads
- [ ] Test on iPad Air M3: verify 2 threads spawned, no frame hitches
- **Status**: Not started
- **Notes**: Current formula returns 1 thread on 8-core M3. Target 2 threads using E-cores.

### 2. MoltenVK Config Expansion
- [ ] Edit `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs`
- [ ] Add argument buffers, prefill, command buffer tuning
- [ ] Uncomment `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` in `MeloNXApp.swift`
- [ ] Test game stability: Mario Kart 8, Zelda TOTK
- **Status**: Not started
- **Notes**: M3 has Tier 2 argument buffers. Always set to 1 on M3+.

## P1 - High Priority

### 3. Shader Compile Thread Tuning
- [ ] Edit `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs:223`
- [ ] Add `#if __IOS__` cap at 4 threads
- [ ] Hook scaling to ProcessInfo.thermalState where available from Swift
- **Status**: Not started

### 4. Thermal Governor 4-Tier
- [ ] Edit `src/MeloNX/MeloNX/App/Core/Ryujinx/ThermalGovernor.swift`
- [ ] Add `warm` case with 45 FPS cap
- [ ] Add hysteresis to prevent FPS cap flicker
- [ ] Integrate with AutoPerformanceGovernor
- **Status**: Not started

### 5. TBDR ASTC Texture Default
- [ ] Change `ConfigurationState.LoadDefault` in `src/Ryujinx.UI.Common/Configuration/ConfigurationState.cs:808`
- [ ] Consider per-game texture recompression logic
- **Status**: Not started

## P2 - Medium Priority

### 6. Memory Management for 8GB UMA
- [ ] Edit `src/Ryujinx.Memory/MemoryManagementUnix.cs`
- [ ] Query physical memory and tune cache limits
- **Status**: Not started

### 7. Background QoS Audit
- [ ] Audit all `DispatchQueue.global()` in Swift files under `src/MeloNX`
- [ ] Assign appropriate QoS class
- **Status**: Not started

### 8. Frame Pacing / preferredFrameRateRange
- [ ] Edit `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MetalView.swift`
- [ ] Sync preferredFrameRateRange with thermal governor FPS cap
- **Status**: Not started

## P3 - Lower Priority

### 9. Per-Game M3 Profiles
- [ ] Design profile format (JSON)
- [ ] Add profiles for top 20 Switch games
- [ ] Wire into LaunchGameHandler
- **Status**: Not started
```

---

## How to Resume Work in a New Session

1. Read `Handoff.md` (this file) to understand architecture, what works, and what needs to be optimized.
2. Read `todo.md` to find the next uncompleted task.
3. Work on the task starting from the referenced file paths.
4. Update `todo.md` with new status after each significant step.
5. If adding entitlements or build config, check `src/MeloNX/MeloNX/MeloNX.entitlements` and `MeloNX-extended.entitlements`.
6. If optimizing rendering, check `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs` for MoltenVK config hooks.
7. If optimizing CPU/JIT, check `src/ARMeilleure/Translation/Translator.cs` for thread heuristics.

## What Works Right Now

- JIT initialization (dual-mapped or legacy)
- MoltenVK rendering via Vulkan to Metal translation
- ARMeilleure background translation threads
- Thermal governor (4-state: nominal/warm/warning/critical with hysteresis)
- Auto-performance governor with FPS-based response and thermal coordination
- Shader warmup (simulated currently)
- Per-game settings via NativeSettingsManager
- Metal view rendering for game display with adaptive FPS caps (30/45/60/120Hz ProMotion)

## Changes Made In This Session

### P0.1 - Background Translation Thread Count
- **File**: `src/ARMeilleure/Translation/Translator.cs:120-121`
- **Change**: Added `#if __APPLE__` branch. Formula changed from `(ProcessorCount - 6) / 3` to `(ProcessorCount - 4) / 3`. On M3 8-core this yields 2 threads instead of 1.

### P0.2 - MoltenVK Configuration Expansion
- **Files**: 
  - `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs:32`
  - `src/MeloNX/MeloNX/App/UI/MeloNXApp.swift:36-38`
- **Change**: Enabled `UseMetalArgumentBuffers`, `PrefillMetalCommandBuffers`, `SynchronousQueueSubmits = false`, `SwapchainMagFilterUseNearest = false`, ASTC shader compression (`MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM = 4`).

### P1.3 - Shader Compilation Thread Scaling
- **File**: `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs:223`
- **Change**: Added `#if __IOS__` to cap `_backendParallelCompileThreads` and `ThreadCount` constant at 4 on iOS.

### P1.4 - Thermal Governor Enhancement (4-Tier + Hysteresis)
- **File**: `src/MeloNX/MeloNX/App/Core/Ryujinx/ThermalGovernor.swift`
- **Change**: Added `.warm` (60 FPS), `.warning` (45 FPS), and kept `.critical` (30 FPS). Added `fps45` to `FPSPace` enum. Implemented `thermalStateHistory` for hysteresis - requires consistent readings before transitioning down.

### P1.5 - TBDR ASTC Texture Compression Default
- **File**: `src/Ryujinx.UI.Common/Configuration/ConfigurationState.cs:808`
- **Change**: `EnableTextureRecompression.Value` now `OperatingSystem.IsIOS()` instead of `false`. ASTC support is already active in MoltenVK path.

### P1.6 - AutoPerformanceGovernor Coordination
- **File**: `src/MeloNX/MeloNX/App/Core/Ryujinx/AutoPerformanceGovernor.swift`
- **Change**: Added `thermalFPSCap` published property. Subscribes to `ThermalGovernorFPSPaceChanged` notification. Degrades to `powerSaving` at 30 FPS cap, `conservative` at 45 FPS cap, allows recovery at 60 FPS cap.

### P2.7 - Memory Management Tuning for 8GB UMA
- **Files**:
  - `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift`
  - `src/Ryujinx.Common/SystemInfo/AppleSystemMemory.cs`
- **Change**: `applyPerformanceDefaults()` now sets `expandRam = true` when `ProcessInfo.processInfo.physicalMemory >= 8GB`. Removed forced `expandRam = false` from `normalizeForLaunch`. Created `AppleSystemMemory.GetPhysicalMemory()` using `sysctlbyname("hw.memsize")` for C# backend use.

### P2 QoS Audit
- **File**: `src/MeloNX/MeloNX/App/Core/Controllers/ControllerManager.swift`
- **Change**: Added explicit `.userInteractive` QoS to `controllerQueue`. Other queues already used correct QoS classes.

### P2.10 - Touch Input Latency Reduction
- **File**: `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MeloMTKView.swift`
- **Change**: Removed debug `print` from `touchesBegan` hot path. Removed `setAspectRatio()` calls from all touch handlers (only needed on bounds change). Removed `ignoredTouches` Set tracking overhead. Simplified touch tracking using `activeTouches.firstIndex(of:)`. Reduced per-touch work to minimum: capture location + bridge call.

### P2.8 - Frame Pacing / ProMotion Support
- **File**: `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MetalView.swift`
- **Change**: Added `fps45` case to `preferredFramesPerSecond` synchronization with thermal governor. ProMotion devices will now correctly adapt to 30/45/60 FPS caps.

### P3.9 - Per-Game M3 Profile Database
- **Files**:
  - `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`
  - `src/MeloNX/MeloNX/App/UI/Main/Home/LaunchGameHandler.swift`
- **Change**: Created `M3ProfileManager` with built-in profiles (default, balanced, performance, quality). Wired into `LaunchGameHandler.startGame()` auto-apply before launch. Persists overrides in `UserDefaults`.

## Important Notes

- Do NOT commit changes unless explicitly asked. The git repo does not exist yet (`Is directory a git repo: no`), so commits are impossible without initialization.
- Never hardcode device names; use `UIDevice.modelName` or `ProcessInfo.processInfo.thermalState`.
- MoltenVK configs set in Swift (`MeloNXApp.swift` init) apply before `RyujinxBridge.initialize()`.
- Dual-mapped JIT is preferred on iOS 19+ (TXM path), legacy path on older iOS.
- Existing settings: `NativeSettingsManager` keys `MOBILE_PERFORMANCE_PROFILE`, `THERMAL_STABILITY_PROFILE`, `AUTO_PERFORMANCE_PROFILE`, `SHADER_WARMUP_ENABLED`, `DUAL_MAPPED_JIT`.
