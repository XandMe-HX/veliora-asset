# Ultra Visual Suite v5 · Texture-Safe

This is a **client-side visual controller for authorized Roblox experiences**. The single `.lua` is self-contained and creates its UI automatically. It does not contain executable ReShade `.fx` programs.

## Differences vs v4

- No automatic material replacement (no SmoothPlastic / Metal / Glass conversion). Clothing, faces, base materials, texture assets, Decals, and `SurfaceAppearance` are intentionally left unchanged.
- Camera-side ColorCorrection uses restrained contrast/saturation, and DepthOfField is disabled by default to keep foreground faces and clothing sharp.
- Auto mode follows the game clock. Lighting adjustments are based on the initial game Lighting snapshot and later external lighting changes observed outside our own transition window.
- Progressive breadth-first `Workspace` traversal, queued BasePart updates in 65-part batches, and a configurable `BatchPace` slider. Does not impose an arbitrary hard limit on the number of objects; the loading phase can take longer on large maps.
- `Wet Look` and explicit `Rainy` weather apply a modest sky-reflective coating to suitable horizontal surfaces, without replacing underlying textures. This is **not** SSR, physically simulated rain, or a true puddle shader.
- Terrain water preserves the experience's `WaterColor` and transparency while applying bounded wave and reflection controls. It is not an ocean/SSR shader and may differ from custom water meshes.
- Original / Polished / Wet Look / Chrome Highlights are all reflectance-focused, texture-preserving options. The Original finish restores original part reflectance.
- Partial character highlights are restricted to accessory handles by default, not the character's face or clothing. User can opt in to all Character BaseParts, but textures still remain untouched.
- Off/Before restore startup Lighting, water and original part reflectance; effects owned by the suite are destroyed and other post effects remain unchanged.

## Controls

1. Open UI with `F3` or **VISUALS** button.
2. Choose quality preset Max / High Ultra / Ultra / Balanced / Off.
3. Start with `Auto` time, `Clear` weather, `Polished` finish and all default settings.
4. For stronger highlights without replacing textures, choose `Chrome Highlights` and adjust Glossy, Reflectance, SurfaceStrength, Specular.
5. For visible wet-ground response, use `Rainy` weather or `Wet Look` finish; the module doesn't automatically detect a game's custom rain system.
6. Set `BatchPace` higher for slower, gentler transitions. The status footer displays scan progress and FPS.
7. Turn Off or select Before for original visuals. An explicit shutdown occurs when a new copy is run.

## Known limitations

- Roblox Luau **cannot** enable actual NVIDIA DLSS, screen-space reflections (SSR), neural upscaling, ray-traced GI, 8K texture resolution or control monitor HDR/AMOLED display hardware. These labels are not implemented as fake APIs.
- `BasePart.Reflectance` reflects the skybox and may be ignored for certain materials. Photo-realistic scene reflections on every textured object require engine renderer capabilities or PBR assets authored for that specific game.
- Real material roughness and metalness maps must be authored through Studio assets; this script never generates new PBR texture maps. Optional `UVS_PBR` tagged parts can use pre-existing explicitly authored variants.
- User Graphics Quality 10 / high hardware quality improves the renderer's texture and AA behavior. The script **only displays a hint** and never modifies Roblox quality or antialiasing flags.
- No shader can make a low-resolution original texture genuinely 8K; keeping DoF off prevents avoidable blur, but cannot add source texture detail.
- Weather setting is manual, not based on undocumented weather APIs. Fog shafts are simulated by Atmosphere + SunRays, not true volumetric path tracing.
- Off restores a startup snapshot. If another game script changes the same properties while UVS is active, the exact final appearance depends on which script last writes those properties.
- No Roblox Studio live runtime test was available in the development environment. Static integrity checks were performed, but gameplay results must be tested in an authorized Roblox experience.

## Links

[Roblox Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting) · [Roblox BasePart](https://create.roblox.com/docs/reference/engine/classes/BasePart) · [Terrain water](https://create.roblox.com/docs/reference/engine/classes/Terrain) · [Post-processing](https://create.roblox.com/docs/environment/post-processing-effects) · [Graphics quality](https://create.roblox.com/docs/reference/engine/enums/SavedQualitySetting)