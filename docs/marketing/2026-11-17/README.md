# 2026-11-17 · 마케팅 요청: 다른 캐릭터 자료

- `reel-abys-en.mp4` · `reel-brit-en.mp4` · `reel-capy-en.mp4`: reel-en과 같은 형식(1080x1920, 30fps, °C+°F, 36° → -12° 옷,
  비 오면 우산), 끝 화면 없음, 10.9초. `python3 make_reel_char.py en CHAR OUTDIR`.
- 캐릭터 PNG(채팅에 zip으로 보냄, 저장소에는 안 넣음 — 앱 그림 그대로라서): `python3 make_char_pngs.py`
  - outfits/NAME-KK.png: `Shared/SharedAssets.xcassets/CHAR-stand-K-none` (480x560, 투명)
  - rain/NAME-KK-rain-now-umbrella.png = `-umbrella`, rain-later-bag = `-bag`
  - rain/NAME-KK-rain-maybe-thought.png: 앱의 "think" 상태(10~29% 비 확률) = 빈손 + 머리 위 생각 말풍선(하늘색, 우산 아이콘).
    BubbleView 모양을 그대로 그림 (홈 화면 비율 176pt = 480px), 말풍선 자리로 위에 40px 더해서 480x600.
- 잠금화면·위젯: ScreenshotTests.test33CharPromo (iOS build, only=test33CharPromo) → ci-output 브랜치.
