# Mascot assets: what exists and what's still needed

## Approach

The mascot is shown as **pre-rendered, looping H.264 videos** exported from Blender and played with
`LoopingVideo` (AVFoundation). There is no 3D runtime in the app.

Why not load the rigged model in RealityKit:

- The rig (`GG_Rig`, 41 bones with IK, in `~/Downloads/gogo_character.blend`) has no per-exercise
  actions yet. Its only actions are slouch and lean loops (`GG_RigAction`, `GogoLean_Loop`, `V2_RigAction.001`).
- The aurora look comes from Blender materials and lighting. Matching it in RealityKit means
  rebuilding the shading and doing a USDZ export with baked animation for every exercise. That's
  more work and risk for no visible gain, because the camera never moves.
- Video gives the exact Blender look, predictable performance and no dependencies. Adding an
  exercise needs no code.

Revisit RealityKit only if the mascot needs to be interactive (rotated by touch, or posed live).

## Adding a render

1. In Blender, pose and animate `GG_Rig` for the exercise as a seamless loop.
2. Render square video (800 × 800 or larger), 24 fps, 4–8 s, H.264 MP4, with the
   same navy backdrop as `mascot_shoulder_rolls.mp4`. The app fades the edges into its background.
3. Save it as `Imposture/Resources/mascot_<exercise-id-with-underscores>.mp4`.
4. In `Imposture/Resources/Library.json`, set `"animation": "mascot_<name>"` on the exercise.

Exercises without a render fall back to the drawn figure (5 exercises), or to a
"Demo coming soon" placeholder.

## Status

Rendered and wired up:

- `mascot_shoulder_rolls.mp4`: Shoulder Rolls (copied from `~/Downloads/shoulder_rolls.mp4`)

Still to render, one loop each (30 exercises):

- Programme: supine-chin-tuck, chin-tuck, scapular-retraction, thoracic-extension-chair,
  doorway-chest-stretch, resistance-band-row, prone-w-raise, prone-y-raise, prone-t-raise,
  wall-slide, wall-push-up-plus, prone-cobra, bird-dog, cat-cow, seated-thoracic-extension,
  neck-rotations
- Desk stretches: seated-figure-four, seated-hamstring-stretch, trunk-rotation,
  desk-chest-opener, one-arm-hug-stretch, overhead-triceps-stretch, forearm-stretch
- Other catalogue exercises: side-neck-stretch, back-neck-stretch, wall-angels,
  standing-chest-opener, standing-hip-flexor-stretch, sit-to-stand, calf-raises

App-state loops (placeholders currently reuse shoulder rolls; see `MascotAnimation` in
`Imposture/DesignSystem/MascotDemo.swift`):

- `mascot_idle`: Home hero idle pose
- `mascot_celebrate`: session completion, restrained (for example a stretch and nod)

Optional: a single still per exercise (PNG, square) for catalogue thumbnails, to replace the
category symbols. Register stills in `Artwork.figures`.

## Analysis transition

The "Understanding your posture" visual is drawn in SwiftUI (`AuroraOrb`), so it needs no asset.
