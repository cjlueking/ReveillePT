# ReveillePT

Home physical therapy for iPhone and iPad, by AIXE Tech. The camera tracks your body, a stick figure follows you,
and a goal bar, rising tone and ding guide each rep. No video is ever stored.

## First run on your Mac
```bash
brew install xcodegen          # once
cd ~/Developer
git clone https://github.com/cjlueking/ReveillePT.git
cd ReveillePT
xcodegen                       # creates ReveillePT.xcodeproj
open ReveillePT.xcodeproj
```
In Xcode: select the ReveillePT target > Signing & Capabilities > Team = your Apple ID.
Plug in the iPad, pick it as the run destination, press Run. Allow camera access on the iPad.

## What works now (steps 1-5)
- Live camera with skeleton overlay and frame rate (step 2)
- Side shoulder raise: live angle, goal bar, rising tone, ding, hold timer, rep counter (steps 3-4)
- Every rep's joint positions saved; replay as a skeleton from the History screen (step 5)
- Unit tests for the angle and rep engine

See `docs/build-plan.md` for the tests each step must pass.
