# ReveillePT architecture (short)

Full version: https://claude.ai/artifact/UxwFNxLDxD2L5zZk78Lw38

## Pipeline (all on device)
Camera (AVFoundation, 30 fps) -> Vision body pose (19 joints, normalized 0-1 coords + confidence)
-> `BodyFrame` -> `Measurement` (angle for the current exercise) -> `Smoother` (moving average, ignores low confidence)
-> `RepCounter` (state machine: rest -> rising -> atGoal/holding -> returning -> rep counted)
-> Feedback (goal bar, `ToneEngine` pitch follows progress, ding at goal, haptic tap) and `TraceRecorder` (saves joints ~10/s).

## Measurement kinds (see Engine/Measurement.swift)
| kind | how | used by |
|------|-----|---------|
| jointAngle | angle at joint b between a and c | shoulder raises, wide stretch |
| neckLateral | tilt of neck->nose line from the shoulder-line perpendicular | neck side bend / stretch |
| neckSagittal | ear-shoulder line vs vertical, side view | neck bend / extension |
| neckRotation | nose offset between the ears -> estimated degrees | neck rotation (estimate) |
| shrugRatio | rise of shoulders toward ears, % of shoulder width | shrugs |
| timedHold | no angle; hold timer only | blade pinch, levator stretch |

## Rep counting rules
- progress = (angle - start) / (goal - start), clamped 0...1
- Goal reached when progress >= 1.0 (after smoothing); hold timer runs while progress >= 0.9
- Rep counts when the hold time is met AND the user returns below progress 0.25 (hysteresis prevents double counts)
- Frames with confidence < 0.3 on any measured joint are ignored

## Privacy
No video stored or uploaded. Saved: joint positions per rep, angles, reps, timings, pain scores.

## Later stages
Supabase (Postgres + RLS, Sign in with Apple, Edge Functions) for sync and usage counting;
RevenueCat + StoreKit 2 for subscription + session packs.
