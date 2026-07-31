# MeloNX Fork - iPhone 16 Plus + iPad Air M3 Optimization TODO

Legend:
- [ ] Not started
- [~] In progress
- [x] Completed
- [-] Cancelled / On hold

## P0 - Quick Wins

### 0. Device Profile Split for iPhone 16 Plus and iPad Air M3
- [x] Replace launch-time M3-only profile application with mobile device profile selection
- [x] Add iPhone 16 Plus baseline profile (A18, 6-core CPU, 5-core GPU, 60Hz)
- [x] Add iPad Air M3 baseline profile (M3, 8-core CPU, 9-core GPU, 8GB RAM)
- [x] Default `expandRam` to profile policy instead of host RAM size alone
- [ ] Test profile detection on physical iPhone 16 Plus
- [ ] Test profile detection on physical iPad Air M3
- **Status**: Completed pending physical-device validation
- **Notes**: `MobileProfileManager` now selects per-device defaults. `M3ProfileManager` remains for compatibility, but launch uses `MobileProfileManager`.

### 1. Background Translation Thread Count (CPU/JIT)
- [x] Edit `src/ARMeilleure/Translation/Translator.cs` lines 120-138
- [x] Add Apple Silicon-specific thread mapping for M3 (4P+4E -> 2 threads)
- [x] Ensure QoS `.utility` on background translation threads on iOS
- [x] Replace fragile `#if __APPLE__` preprocessor branch with runtime `OperatingSystem.IsMacOS() || OperatingSystem.IsIOS()` check
- [ ] Build and test: verify thread count, no frame hitches during gameplay
- **Status**: Completed
- **Notes**: Runtime Apple platform path uses `(ProcessorCount - 2) / 3`. Target result: iPhone 16 Plus/A18 6-core -> 1 thread, iPad Air M3 8-core -> 2 threads.

### 2. MoltenVK Configuration Expansion
- [x] Edit `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs`
- [x] Add `UseMetalArgumentBuffers = true` (M3 has Tier 2)
- [x] Add `PrefillMetalCommandBuffers = true`
- [x] Review `SynchronousQueueSubmits`, `MaxActiveMetalCommandBuffersPerQueue`
- [x] Uncomment `MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS` in `src/MeloNX/MeloNX/App/UI/MeloNXApp.swift:36`
- [x] Add `MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM = 4` (ASTC)
- [ ] Test game stability: Mario Kart 8 Deluxe, Zelda TOTK
- **Status**: Completed
- **Notes**: Set env vars before `RyujinxBridge.initialize()` is called in `MeloNXApp.init()`.

## P1 - High Priority

### 3. Shader Compilation Thread Scaling
- [x] Edit `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs:223`
- [x] Cap `_backendParallelCompileThreads` to `4` on iOS (`#if __IOS__`)
- [x] Cap `ThreadCount` constant to `4` on iOS
- [x] Replace fragile `#if __IOS__` branches with runtime `OperatingSystem.IsIOS()` checks
- [ ] Add thermal-aware scaling hook (lower threads in thermal warning/critical)
- [ ] Test shader cache load time and thermal behavior
- **Status**: Completed
- **Notes**: Both thread counts are capped at 4 on iOS via runtime checks. Thermal hook can be added later.

### 4. Thermal Governor Enhancement (4-Tier + Hysteresis)
- [x] Edit `src/MeloNX/MeloNX/App/Core/Ryujinx/ThermalGovernor.swift`
- [x] Add `warm` case cap at 60 FPS between nominal and warning
- [x] Add `warning` case cap at 45 FPS between warm and critical
- [x] Add `critical` case cap at 30 FPS
- [x] Add hysteresis: require lower temp before dropping tier
- [x] Add `fps45` FPS pace case
- [x] Update `shouldCapAt30FPS`, `shouldCapAt45FPS`, `shouldCapAt60FPS` for new tiers
- [ ] Test thermal ramp: device at 30C, 40C, 45C, 50C
- **Status**: Completed
- **Notes**: Mapped `.fair` → `.warm` (60 FPS), `.serious` → `.warning` (45 FPS), `.critical` → 30 FPS.

### 5. TBDR ASTC Texture Compression Default
- [x] Edit `src/Ryujinx.UI.Common/Configuration/ConfigurationState.cs:808`
- [x] Change `EnableTextureRecompression.Value = true` on iOS/iPadOS
- [x] Verify ASTC support path active in `VulkanRenderer.cs:742`
- [x] Send `--enable-texture-recompression` from Swift launch args when enabled
- [ ] Add per-device toggle if texture artifacts appear
- **Status**: Completed
- **Notes**: Default now `OperatingSystem.IsIOS()`, and Swift command-line args now pass the headless option explicitly.

### 6. AutoPerformanceGovernor Coordination with ThermalGovernor
- [x] Edit `src/MeloNX/MeloNX/App/Core/Ryujinx/AutoPerformanceGovernor.swift`
- [x] Add observer for `ThermalGovernorFPSPaceChanged`
- [x] Lower resScale target when thermal cap is below 60
- [x] Restore resScale when thermal recovers
- [x] Add explicit `thermalFPSCap` published property
- **Status**: Completed
- **Notes**: Thermal cap 30 → powerSaving, 45 → conservative, 60+ → allow recovery.

## P2 - Medium Priority

### 7. Memory Management Tuning for 8GB UMA
- [x] Edit `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift`
- [x] Set `expandRam` default from mobile device profile policy
- [x] Remove forced `expandRam = false` from `normalizeForLaunch`
- [x] Create `src/Ryujinx.Common/SystemInfo/AppleSystemMemory.cs` helper for C# memory queries
- [x] Fix `AppleSystemMemory.GetPhysicalMemory()` null-pointer dereference risk
- [ ] Test with Zelda TOTK texture pack scenario
- **Status**: Completed
- **Notes**: `expandRam` is now off by default for iPhone 16 Plus and iPad Air M3 baseline profiles. Enable only through per-game profiles or explicit user settings for texture-pack/mod scenarios.

### 8. Background QoS Classification Audit
- [x] Audit `DispatchQueue.global()` calls in `src/MeloNX/MeloNX/App/UI/`
- [x] Assign `.utility` to `ShaderWarmupManager` (already `.background`)
- [x] Assign `.userInteractive` to gameplay touch handlers (already done)
- [x] Assign `.userInitiated` to JIT and bridge calls (already done)
- [x] Add explicit QoS to `ControllerManager.controllerQueue` (was default, now `.userInteractive`)
- **Status**: Completed
- **Notes**: Existing code already used correct QoS classes in most places. Only `ControllerManager.queue` needed explicit QoS.

### 9. Frame Pacing / preferredFrameRateRange
- [x] Edit `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MetalView.swift`
- [x] Sync `preferredFramesPerSecond` with `ThermalGovernor.FPSPace` including `fps45`
- [ ] Test ProMotion 120Hz devices
- **Status**: Completed
- **Notes**: Added `fps45` case to updateUIView. ProMotion devices will use `preferredFramesPerSecond` which already adapts.

### 10. Touch Input Latency Reduction
- [x] Edit `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MeloMTKView.swift`
- [x] Remove `print("Touch location: ...")` from `touchesBegan` (debug spam in hot path)
- [x] Remove `setAspectRatio()` calls from all touch handlers (only needed on bounds change)
- [x] Remove `ignoredTouches` tracking overhead
- [x] Simplify touch tracking using `activeTouches.firstIndex(of:)`
- **Status**: Completed
- **Notes**: Touch handlers now do minimal work per frame. Aspect ratio is set once per view update.

## P3 - Lower Priority / Nice to Have

### 10. Per-Game Mobile Profile Database
- [x] Design JSON/plist format for per-game performance profiles
- [x] Create `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`
- [x] Add built-in profiles: default, balanced, performance, quality
- [x] Wire into `LaunchGameHandler.startGame()` auto-apply
- [x] Persist profile overrides in `UserDefaults`
- [x] Add `MobileProfileManager` for iPhone 16 Plus + iPad Air M3 device-specific profiles
- [ ] Add profiles for top 20 Switch titles
- **Status**: Completed
- **Notes**: `MobileProfileManager.shared.applyProfile` is called before game launch. User can create per-game overrides keyed by device class and title ID.

### 11. Pipeline State Cache Tuning for MoltenVK
- [ ] Review `src/Ryujinx.Graphics.Vulkan/PipelineLayoutFactory.cs`
- [ ] Review `src/Ryujinx.Graphics.Vulkan/PipelineState.cs`
- [ ] Verify cache sizes appropriate for 8GB RAM
- **Status**: Not started
- **Notes**: PipelineState is a struct, not a cache. Caching is in ShaderCollection.HashTableSlim which is already unbounded and appropriate for M3. Deferred.

---

## Completed In This Session

| Task | File(s) Changed | Summary |
|------|-----------------|---------|
| P0.0 Device Profiles | `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`, `src/MeloNX/MeloNX/App/UI/Main/Home/LaunchGameHandler.swift`, `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift` | Added MobileProfileManager with iPhone 16 Plus and iPad Air M3 baselines; launch now uses mobile profiles |
| P0 Compile Guards | `src/ARMeilleure/Translation/Translator.cs`, `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs` | Replaced `__APPLE__`/`__IOS__` compile symbols with runtime OS checks |
| P1 ASTC Args | `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift` | Swift launch args now pass `--enable-texture-recompression` when enabled |
| P2 Memory Helper | `src/Ryujinx.Common/SystemInfo/AppleSystemMemory.cs` | Fixed null-pointer dereference in `GetPhysicalMemory()` |
| P0.1 Thread Count | `src/ARMeilleure/Translation/Translator.cs` | Apple Silicon runtime path using `(ProcessorCount - 2) / 3` |
| P0.2 MoltenVK Config | `src/Ryujinx.Graphics.Vulkan/MoltenVK/MVKInitialization.cs`, `src/MeloNX/MeloNX/App/UI/MeloNXApp.swift` | Enabled argument buffers, prefill, ASTC shader compression |
| P1.3 Shader Threads | `src/Ryujinx.Graphics.Gpu/Shader/DiskCache/ParallelDiskCacheLoader.cs` | Capped at 4 threads on iOS via `#if __IOS__` |
| P1.4 Thermal 4-Tier | `src/MeloNX/MeloNX/App/Core/Ryujinx/ThermalGovernor.swift` | Added warm/warning states, 45 FPS cap, hysteresis |
| P1.5 ASTC Default | `src/Ryujinx.UI.Common/Configuration/ConfigurationState.cs` | `EnableTextureRecompression = true` on iOS |
| P1.6 AutoPerf | `src/MeloNX/MeloNX/App/Core/Ryujinx/AutoPerformanceGovernor.swift` | Added thermal FPS cap observer and coordinated scaling |
| P2.7 Memory Tuning | `src/MeloNX/MeloNX/App/Core/Ryujinx/Ryujinx.swift`, `src/Ryujinx.Common/SystemInfo/AppleSystemMemory.cs` | Device-aware expandRam default (>=8GB host → 8GB emulated) |
| P2.8 Frame Pacing | `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MetalView.swift` | Added `fps45` to `preferredFramesPerSecond` |
| P2 QoS Audit | `src/MeloNX/MeloNX/App/Core/Controllers/ControllerManager.swift` | Set explicit `.userInteractive` QoS |
| P3.9 M3 Profiles | `src/MeloNX/MeloNX/App/Core/Ryujinx/M3GameProfile.swift`, `src/MeloNX/MeloNX/App/UI/Main/Home/LaunchGameHandler.swift` | Created M3ProfileManager with built-in profiles |
| P2.10 Touch Latency | `src/MeloNX/MeloNX/App/UI/Emulation/MetalView/MeloMTKView.swift` | Removed debug print, setAspectRatio from touch handlers, simplified tracking |

## Remaining High-Priority Work

- Build and test on physical iPad Air M3
- Validate thread spawning behavior on M3
- Verify thermal governor transitions at various temperatures
- Check for texture artifacts with ASTC recompression enabled
- Test ProMotion 120Hz frame pacing
- Verify touch latency improvements in gameplay

---

## How to Use This File

1. Pick the highest priority uncompleted task.
2. Follow the file paths and notes under each task.
3. Mark items `[x]` as they are completed.
4. Add new sub-tasks if you discover additional work needed.
5. Keep `Handoff.md` synchronized if you add new files or architecture changes.

## Important Reminders

- Do NOT commit unless explicitly asked (repo is not a git repo yet).
- Do NOT add copyrighted content (firmware, keys, games).
- Test on physical iPad Air M3; do not rely on simulator results alone.
- JIT is required for games to run. Do not break existing JIT paths.
- Entitlements are already in place: `increased-memory-limit` and `extended-virtual-addressing`.
