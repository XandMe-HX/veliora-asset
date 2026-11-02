# Ultra Visual Suite v6 — Cinematic Edition

## Files
- `UltraVisualSuite-v6-Cinematic-ALL-IN-ONE.lua`: **complete standalone Luau source** (all settings, controller and GUI in one file). Intended for client-side execution in environments where scripts are authorized.
- No external assets, paid plugins, HTTP requests or DataStore dependency inside the standalone.

## Setup in Roblox Studio
1. Open your own Roblox Studio experience.
2. Insert **LocalScript** into `StarterPlayer > StarterPlayerScripts`.
3. Paste the full content of `UltraVisualSuite-v6-Cinematic-ALL-IN-ONE.lua`.
4. Press Play, click **VISUALS | F3**.
5. Use Cinematic preset initially; choose **Original** in Looks for baseline reflectance.
6. Adjust ShadowStrength, ShadowSoftness, ShadowLift separately; for Terrain water use Water Reflection, Water Clarity, Water Depth (global tint) and Water Waves.
7. Try **BEFORE/AFTER** and **Off** to restore initial captured properties.

## GUI tabs

| Tab | Controls | Visual result |
| --- | --- | --- |
| LOOKS | Cinematic, Max, High Ultra, Ultra, Balanced, Off; time modes; finish; Glossy, Reflectance, Specular, SurfaceStrength, Bloom, GlowThreshold, Saturation, Contrast, Clarity, HighlightProtection, Exposure | Real native skybox/environment highlight, contrast and highlight control |
| SHADOW | ShadowStrength, ShadowSoftness, ShadowLift, Ambient | Perceived shadow darkness and edge softness: **not** shadow opacity |
| WATER | WaterReflection, WaterClarity, WaterDepth, WaterWaves | Terrain Water only; depth is a **global water color tint**, not a depth-buffer calculation |
| FOG | weather, Density, Haze, FogDistance, SunRays | Distance haze and sun halo, **not** true volumetric ray tracing |
| SYSTEM | Feature toggles, BatchPace, Adaptive Performance, Visual Test, Before/After, Photo Mode, Reset | Feature-level control, staged processing and restoration |

**All slider values are normalized 0..100% within explicitly coded engine-safe ranges.** A larger slider value means more of its labeled effect; to darken shadows move ShadowStrength to the right, to reveal dark details move ShadowLift to the right. Greater ShadowSoftness gives softer edges, NOT less blackness.

## Manual A/B test checklist
1. Keep your character, camera, sun position, map and graphics quality unchanged.
2. Toggle Before/After before moving, compare at same camera view.
3. On a wall, compare ShadowStrength 0/50/100%; separately ShadowSoftness 0/50/100%.
4. On metallic or polished surfaces, compare Glossy + Reflectance 0/50/100%; verify original decals, SurfaceAppearance and clothing do not change.
5. On **Terrain Water**, compare WaterReflection, WaterClarity, WaterDepth and WaterWaves at 0/50/100%. Custom MeshPart water may not respond.
6. At a distant open horizon, compare Density/Haze/FogDistance; compare against an occluding wall to see the difference of sun shafts.
7. On close-up character clothing/face, verify that opening the GUI does not blur the world. Clarity is cosmetic contrast; Roblox itself controls texture LOD and anti-aliasing.
8. Set preset Off; verify initial Lighting, Water, ambient/fog and tracked Reflectance restore. If another script continually overrides the same properties, disable its graphics controller before testing.

## Limits
- No universal SSR, neural upscaling, programmable 8K texture enhancement, MSAA control, physically accurate water depth-buffer SSR, or real HDR/AMOLED panel control through Luau.
- LightingStyle Realistic and PrioritizeLightingQuality writes can be restricted client-side. Operations are wrapped in pcall and fail gracefully.
- Reflectance is engine/environment based and does not guarantee nearby player/object mirror reflections.
- Fog uses Atmosphere global settings; weather Rainy does not generate physical rain particle simulation.
- The script does not change Material, TextureID, clothing, facial textures or MeshPart geometry.
- Existing game lighting effects may stack; server scripts may override client property changes.
- "Off" restores original captured values and owned post effects, not third-party changes made later.

## 45-second storyboard (16:9 1080p 60fps, no voice)
| Time | Scene | Camera/motion | UI + effect | Indonesian overlay |
| --- | --- | --- | --- | --- |
| 0–5 s | Japanese riverside, stone pavement, character in textured outfit | locked wide dolly | quick Original to Cinematic wipe in same light | "Cinematic, tekstur tetap utuh" |
| 5–11 s | character face, hoodie, fabric seams | slow push-in | Clarity 0 → 50 → 100, no blur, with limit note | "Lebih jelas, tanpa upscale palsu" |
| 11–17 s | cast shadows on wall and pavement | static side view | ShadowStrength and ShadowSoftness 0 → 50 → 100; lift 50 | "Bayangan: pekat atau lembut" |
| 17–23 s | polished street objects, lamp pole, character accessory | lateral tracking | Glossy and Reflectance 0 → 50 → 100, original decals remain | "Glossy tanpa merusak material" |
| 23–30 s | clear river, rocks at two depths | low, slow tilt | Water Reflection 0 → 100, Clarity 0 → 100, DepthTint 0 → 100; no false per-pixel claims | "Air jernih, tint kedalaman" |
| 30–36 s | path toward far trees and sun | static wide then side step behind wall | Fog Distance 0 → 100, Haze and SunRays preview | "Atmosfer terasa di ruang terbuka" |
| 36–41 s | identical A/B camera on street and character | locked frame | Before/After instant toggle | "Bandingkan pada sudut sama" |
| 41–45 s | final cinematic golden scene, GUI tabs visible | slow pull-back | Cinematic default and five tabs | "Ultra Visual Suite v6" |

Audio: original royalty-free soft ambient cinematic score, small click sounds for UI only. Delivery: H.264 MP4, 1920×1080, nominal 60fps, 45 seconds, captured directly from the game; never label any frame as true DLSS/SSR/HDR.

## Notes on tests
Static source checks are not runtime tests. You must test in Roblox Studio and your own experience. Do not rely on external executors or unaudited remote scripts for security.
