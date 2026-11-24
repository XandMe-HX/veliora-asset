# Parry Training Core

Original, independent Roblox Studio prototype for a private place. It does not connect to Violence District, inspect other players, inject inputs, or call its remotes. No changes to the Velion hub.

## Install
Create a folder ParryTraining in ServerScriptService. Add ModuleScripts named CharacterStateMachine, ItemCooldownService, CombatResolver, and a normal Script named TrainingTests; paste the corresponding source. Start Play or Run and inspect Output. All events are synthetic. A visible NPC/UI and actual game hitboxes are not included.

## Model
- Configurable 0.8 s window, 90 s success cooldown, 60 s failure cooldown, 4 s simulated stun. These are training assumptions, not verified live game values.
- Half-open window: start inclusive, end exclusive. Success cooldown starts at contact; failure cooldown starts at activation.
- The item uses a server-owned grant flag, independent of skin.
- Character action state and cooldown are separate. Respawn cancels active parry but preserves cooldown; Remove releases state.
- Resolver assumes server-generated sequential event IDs and confirmed synthetic contact. It deliberately does not calculate live hitboxes.
- The test script exercises 26 scenarios without waiting for actual cooldowns.
- Clock is injected; a server adapter can use workspace:GetServerTimeNow() in an owned project.
- Source is not runtime-verified until tests run in Studio.

## References
Architecture inspiration: Roblox Creator Hub client-server boundary documentation and kpackk/roblox-gameplay-systems combat core. No source copied from those repositories.
