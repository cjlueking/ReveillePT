#!/usr/bin/env python3
"""Generates a synthetic side-shoulder-raise recording in the app's SessionTrace JSON format.

Real recordings exported from the app (Recordings > Export for tests) can replace or join it:
name them fixture_<anything>.json and put them in ReveillePTTests/Fixtures.
"""
import json, math, random, uuid, sys

ASPECT = 16 / 9
FPS = 10
random.seed(7)


def frame(abduction, t):
    centre, shoulder_y, hip_y, half, arm = 0.5 * ASPECT, 0.40, 0.78, 0.13, 0.30
    r = math.radians(abduction)
    pts = {
        "rightShoulder": (centre - half, shoulder_y),
        "leftShoulder": (centre + half, shoulder_y),
        "rightHip": (centre - half, hip_y),
        "leftHip": (centre + half, hip_y),
        "rightWrist": (centre - half - arm * math.sin(r), shoulder_y + arm * math.cos(r)),
        "leftWrist": (centre + half + arm * math.sin(r), shoulder_y + arm * math.cos(r)),
        "rightElbow": (centre - half - arm / 2 * math.sin(r), shoulder_y + arm / 2 * math.cos(r)),
        "leftElbow": (centre + half + arm / 2 * math.sin(r), shoulder_y + arm / 2 * math.cos(r)),
        "neck": (centre, shoulder_y),
        "nose": (centre, shoulder_y - 0.14),
        "leftEar": (centre + 0.035, shoulder_y - 0.15),
        "rightEar": (centre - 0.035, shoulder_y - 0.15),
    }
    joints = {k: {"x": round(x / ASPECT, 5), "y": round(y, 5), "confidence": 0.9} for k, (x, y) in pts.items()}
    return {"time": round(t, 3), "aspect": ASPECT, "joints": joints}


def main(out):
    t = 0.0
    reps = []
    rest, peak = 15.0, 138.0
    for i in range(3):
        frames, best = [], 0.0
        def add(a):
            nonlocal t, best
            a += random.uniform(-3, 3)
            best = max(best, a)
            frames.append(frame(a, t))
            t += 1 / FPS
        if i == 0:
            for _ in range(10):
                add(rest)
        up = 15
        for k in range(up):
            add(rest + (peak - rest) * k / up)
        for _ in range(25):  # 2.5 s hold
            add(peak)
        for k in range(up):
            add(peak - (peak - rest) * k / up)
        for _ in range(8):
            add(rest)
        reps.append({"index": i + 1, "best": round(best, 2), "frames": frames})
    trace = {
        "id": str(uuid.UUID(int=12345)).upper(),
        "exerciseId": "side_shoulder_raise",
        "exerciseName": "Side shoulder raise",
        "date": "2026-11-25T12:00:00Z",
        "startValue": 20,
        "goalValue": 130,
        "unit": "deg",
        "reps": reps,
        "trailing": [],
    }
    with open(out, "w") as f:
        json.dump(trace, f)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "ReveillePTTests/Fixtures/fixture_side_raise_synthetic.json")
