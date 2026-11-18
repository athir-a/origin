# ORIGIN – working notes (resume file)

## Facts
- Project dir: /home/ubuntu/origin (Godot 4.7, Web export, offline single-player). Game runtime: /home/ubuntu/.manus-addons/manus-webdev-sha-ff206904b0183821/runtime/game-dev
- Blueprint approved rev 3. developmentEffort=max_effort ("Standard effort"), assetProduction=ai_generated, mockups=false, onlineFeatures=[] (no accounts/server; progress saved locally via user:// JSON).
- Brief file: /home/ubuntu/upload/pasted_content.txt (Origin: study -> village grows -> villagers -> give back; "You made it. Now it's your turn.")
- Workflow (skills/webdev/references): game-workflow.md, game-delivery.md, game-sharing.md, game-generic.md already read.
  * npm run check ; npm run check -- --pack ; npm run preview:build ; npm run dev (resident, PORT=3000 HOST=0.0.0.0) ; node "$GAME_RUNTIME/save-release.mjs" --message "..." then push exact SHA to origin/main; GET game/sharing/releases/<sha>.
  * Must: replace inherited loading screen (web/loading.html, has 95KB inline stuff; art in <style id="loading-art">), game-specific favicon in game-sharing.json (assets.favicon = assets/share/favicon.png) + title/description, project.godot config/name/icon, POST game/sharing/prepare {}, OG cover required (assets/share/og.png generated already by AI).
  * build config must be {"build":{"command":"true","outputDirectory":"site"}} (check GET config).
  * Don't use "!!" in bash (history expansion) – use `set +H`.
  * Image gen rate-limit: max ~2 concurrent generate_image jobs.
- Scaffold files to replace/disconnect: scripts/main.gd (maze game, 1591 lines), scenes/main.tscn (root Control), test/test_suite.gd (maze tests), game-verification.json (scene test + pack check tools/verify_exported_pack.gd), config/tuning.json (maze settings; categories allowed: UI,Gameplay,Audio,Player,Enemies,Environment; needs en.json keys label_key/description_key/unit_key), autoloads: TuningBridge, ManusFontTheme (auto-applies bundled font theme to top-level Controls w/o theme), SaveStore, I18n, TuningStore, AudioDirector. Fonts: Figtree body (assets/template/fonts/ui_regular/medium/bold.tres), display Sora (assets/template/fonts/display/generic_title.tres etc.).
- project.godot: viewport 1280x720, stretch canvas_items, aspect currently "expand" -> change to "keep".

## Art (done): /home/ubuntu/art_raw (AI raw) -> tools/origin_art/process_art.py -> assets/origin/{buildings,props,chars,ground,scenes}, assets/share/{og,favicon}.png
- buildings/: home(100w) cottage(112) shop(128) library_0..3 (40/88/120/176) school_1(84) school_2(136) clinic(110) computer_1(112) computer_2(150) tower(109x150) market(150) plot (construction site 76)
- props/: oil_lamp electric_lamp power_pole well bench hay crates cart signpost barrier tree_spring/summer/autumn/winter(~66x104) bush pine rocks flowers scarecrow mailbox hen hen_peck chick cat dog goat plot_0..3 (62x71 farm plots)
- chars/: <id>_front/back/side.png for hero grandma mother shopkeeper child farmer teacher doctor tech asha hero_grown (~32px tall); hero_study, asha_study (seated).
- ground/ground_atlas.png 256x176 16px tiles: rows0-3 grass per season (spring,summer,autumn,winter) cols0-3 variants; rows4-7 decor per season cols0-3 (tuft, flowers a, flowers b, pebbles); rows 8,9,10 = dirt, gravel, paved road autotile 16 masks (col = mask; N=1,E=2,S=4,W=8 = neighbor is road; road tile has transparent edges).
- scenes/keyart.png (title + intro), scenes/finale.png (ending), 1280x720.

## Design
- Names: Nani Savitri (grandma), Meera (mother), Kabir (shopkeeper), Tiya (child), Old Hari (farmer), Ms. Anika (teacher, after school), Dr. Farah (clinic), Rohan (tech, computer), Asha (new student after finale). Player enters own name.
- XP 10/min; level n needs 60*(n-1)^2 xp. Building levels derived from metrics (see scripts/origin/content.gd, done). Zones: north Hill Path (pl>=2), east (roads>=1). Finale when farm>=2, lib>=2, school>=1, elec>=1, roads>=1, clinic>=1, computer>=1, internet>=1, pl>=9. After finale: mentor mode (Asha milestones).
- World 1200x800 px, camera zoom 2 (640x360 view), y-sort, sprites feet-origin. Layout: lamp (610,490); home (330,430); library site (500,440); shop (780,450); market (780,560); cottage (250,560); well (360,540); farm plots 2x3 around x 470-610,y 668/740; north fence y=320 gap x640-720 (road x=680); east fence x=860 gap y470-550; school (360,270) clinic (800,270) in north; computer (975,440) tower (1110,430) in east; main road y~500-516; spawn (560,520).
- Preview mode: separate save slot (user://origin_preview.json) with chapter jumps 1-5 + atmosphere controls (time/weather/season).
- UI: parchment panels + wood buttons, bundled fonts, CanvasLayers (world tint via CanvasModulate must not affect UI).
- Silent (no audio).

## Code status
- DONE: scripts/origin/content.gd
- TODO: autoload OriginState (scripts/origin/state.gd), actor.gd, world.gd, ui_kit.gd, main.gd rewrite + scenes/main.tscn (root Node), tests rewrite, tuning.json/en.json trim, loading.html rewrite, project.godot (name, icon, aspect keep, autoload OriginState, pixel snap), game-sharing.json, preview build/capture, save-release, push.

## STATUS UPDATE (2026-11-08, 16:01)
- Standard effort project implementation underway in `/home/ubuntu/origin`. Blueprint revision 3 approved, `onlineFeatures=[]`, server/database disabled; don't enable online account services without explicit new approval.
- Native Godot 4.7 project boots and title/village/study/journal screens have been captured with a real renderer (`/tmp/shots/title.png`, `v3.png`, `st_side_0.png`, `st_side_3.png`, `sheet_a.png`, `sheet_b.png`).
- `scripts/origin/` now contains content, local OriginState, actor, village, weather, study-scene, UI, dialogue, study UI, summary, journal, story, title, pause and main controller. Project icon and OriginState autoload are in project.godot; viewport stretch is `canvas_items`/`keep`. Side-view study art and world ground distribution/zoom were improved.
- Project build config GET confirms `build.command=true`, `build.outputDirectory=site`, `features.database=false`, `features.server=false`, runtime port 3000. LSP registration is absent; Godot workflow uses native check/boot tooling.
- TODO.md now tracks exact deliverable outcomes and clearly marks account/database scope deferred by the approved Blueprint.
- Remaining: finish app-specific Web loading shell (existing web/loading.html has inherited artwork), ensure boot splash uses solid background and `show_image=false`; sharing metadata title/description/OG/favicon, call `game/sharing/prepare`; disconnect inherited maze checks/config from active verification without deleting retained source assets; run `npm run check`, build and preview, inspect native errors/status; prepare checkpoint/save-release, pack-check, push and exact SHA readback. Browser Web input/responsiveness acceptance is pending; don't claim it.
- Keep all shell scripts/patches written to files, not heredocs with literal tabs typed into exec; use `/home/ubuntu/shot.sh` for real-renderer screenshots.
