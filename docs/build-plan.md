# ReveillePT build plan

Each step ends with a test. Move on only when it passes on a real device (iPad for daily testing, iPhone before marking passed).
Living version with status dropdowns: https://claude.ai/artifact/L6zCqaTsEs3Yxv6ZH9uxqj

## Stage 1: personal app on device

| # | Task | Test to pass | Status |
|---|------|--------------|--------|
| 1 | Xcode project (XcodeGen), private GitHub repo, runs on device | App opens on iPad/iPhone from Xcode | Code ready |
| 2 | Camera + Vision skeleton overlay, FPS readout | Skeleton follows you smoothly at 6-8 ft, front and side, normal room light; FPS >= 20 | Code ready |
| 3 | Angle + rep engine, side shoulder raise | Angle within ~5 deg of a phone protractor app; 10/10 reps counted, no double counts | Code ready (unit tested) |
| 4 | Goal bar, rising tone, ding, hold timer, haptics | You can finish a set by sound alone | Code ready |
| 5 | Record joint data per rep, replay skeleton, tests from recordings | Replay matches what you did; tests pass | Code ready |
| 6 | Neck exercises (side bend, rotation, bend, extension, stretches) | Each counts reps correctly; flag any the camera can't measure | Not started |
| 7 | SwiftData models, library seeded from exercises.json | Data survives app restart | Not started |
| 8 | Session flow, pain before/after, summary | Full 19-exercise session end to end | Not started |
| 9 | Welcome, profiles Chris Lueking + Irene Lueking, PIN, Face ID | Plans and history stay separate | Not started |
| 10 | Home daily plan (add/remove), journey, badges | Matches design canvas, updates after a real session | Not started |
| 11 | Cartoon animations per exercise + "Your motion" replay | Every exercise has an animation and a replay | Not started |
| 12 | 2 weeks daily use; Apple Developer Program; TestFlight to Irene | No crashes; agreed fix list | Not started |

## Stage 2 and 3
13 Supabase schema + row-level security · 14 Sign in with Apple · 15 Sync · 16 Usage counting ·
17 RevenueCat + StoreKit 2 · 18 Paywall · 19 App Store submission
