# Origin — outcome tracking

## Study sessions and usable learning records — in progress
- [x] A player can select a built-in subject or add a custom subject, set a focus goal, and begin a focused study session.
- [x] The study timer supports pause and resume, finishing and recording, and stepping away without recording; short unrecorded sessions are handled gently rather than counted as completed.
- [x] Completed sessions record their date, subject, duration, and XP; progress persists between launches in the local save.
- [x] The player can review total study time, daily and weekly activity, subject totals, study history, session count, level/XP, village growth, and achievements in the journal.
- [x] XP, a player level, and gentle return-to-study encouragement make learning visible without treating every minute as a competition.
- [ ] Complete a launch-to-session-to-record acceptance pass in the published Web preview; native screenshots and source checks do not verify Web input or browser persistence.

## Growth makes visible community changes — in progress
- [x] Study XP and consistency contribute to player levels, village levels, building development, milestones, achievements, narrative events, interactions, and newly accessible areas.
- [x] Farms express consistency; the library knowledge; school opportunity; electricity infrastructure and progress; computer center skills and technology; roads connection; clinic well-being; and internet access to information.
- [x] Each significant building exposes its current stage and next progress goal, and the journal includes village development and achievements.
- [ ] Confirm progression-triggered building and area events through a playable Web-preview run; screenshot chapter jumps show developed layouts, not the full player-triggered sequence.

## Villagers remember the journey — in progress
- [x] Named villagers have roles, relationships/personality, progression-sensitive dialogue, and saved conversation/progression reactions; milestone reactions acknowledge village changes.
- [x] The opening community includes grandmother Nani Savitri, mother Meera, shopkeeper Kabir, and child Tiya; later village improvements introduce farmer Old Hari, teacher Ms. Anika, doctor Farah, and technology volunteer Rohan.
- [ ] Confirm dialogue and character interactions from the playable Web preview, including Tiya's later aspiration to become a programmer.

## A village that feels lived in — in progress
- [x] The village has day/night and sunrise/sunset states, changing weather and seasons, animated villagers and ambient life, interactive buildings, and environmental changes associated with progress.
- [x] Weather remains atmospheric and non-punitive; rest days never erase growth, and returning after a break is welcomed.
- [ ] Confirm the scene and controls in the live Web preview at its configured desktop viewport.

## The give-back ending — in progress
- [x] The ending returns the protagonist to the same street lamp after the village has developed, introduces Asha as a new student beginning there, awards the ending achievement, and shows the message “You made it. Now it's your turn.”
- [x] After the ending, the player can guide Asha by studying beside her; her journey has its own saved milestones.
- [ ] Confirm the finale and mentoring transition through a real session/progression playthrough; the debug chapter preview is visual evidence only.

## Independent saved journeys and account services — intentionally scoped by Blueprint
- [x] The approved Blueprint selects an offline single-player game with independent local save data; separate story previews use their own save slot so real progress is not changed.
- [ ] The original product brief separately describes registration/login, account information, cross-return persistence, a database-backed dashboard/history/progression/XP/achievements/village, secure authentication, and authorization that prevents access to another user's data. These online/account services were excluded by the approved Blueprint (`onlineFeatures=[]`, server/database disabled). Do not enable them without an explicit new user approval and Blueprint update.

## Pixel-art identity and delivery — in progress
- [x] The presentation follows the approved cozy, nostalgic 2D pixel-art village direction, with English game content and original generated game art; the core game remains integrated with the study loop instead of a generic timer dashboard.
- [x] Replace the inherited Web loader with an Origin-specific loader and embedded favicon; disable the inherited engine splash image, set accurate sharing metadata, and prepare game sharing.
- [x] Build the Web preview successfully; the configured server passed its HTTP health check and the post-build page returned HTTP 200 with the Origin loading-shell markers. Actual browser/WebAssembly startup, input, audio, resize, and browser-storage acceptance remain unverified.
- [x] Native source and packed checks exit successfully. Their report still marks Blueprint visual coverage 0/8 even though the original game art has been synced and rendered; the coverage/provenance record was not edited to hide this advisory.
