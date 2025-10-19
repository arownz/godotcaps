**4.4.1 Web App System**

[screenshot]

**Figure 8. Splash Screen**

The Lexia splash screen displays the logo with a progress bar that loads game assets from browser cache for optimized performance. The screen serves as the initial entry point before authentication.

[screenshot]

**Figure 9. Authentication**

The authentication screen provides tab-based login and registration with email/password fields and Google Sign-In integration. Firebase Authentication handles user account creation, login validation, and session persistence across devices.

[screenshot]

**Figure 10. Main Menu**

The main menu displays user profile, level, and energy status (20 max, recovers 4 every 3 minutes). Five navigation buttons provide access to Journey Mode (RPG battles), Modules (educational activities), Character selection, Leaderboards, and Settings. The selected character animation plays idle state on the left side.

[screenshot]

**Figure 11. Dungeon Selection**

Three dungeons with progressive difficulty: Dungeon 1 (3-letter words), Dungeon 2 (4-letter words), Dungeon 3 (5-letter words). Each dungeon has 5 stages with completion tracking. Firebase saves dungeon progression and stage completion status.

[screenshot]

**Figure 12. Dungeon Map**

Displays 5 battle stages in the selected dungeon with enemy icons showing completion status. Stage 5 is always the boss battle. Clicking a stage navigates to the battle scene. Firebase tracks which stages are completed per dungeon.

[screenshot]

**Figure 13. Battle Scene**

Turn-based RPG combat with auto-battle system consuming 2 energy per fight. Player and enemy animations show attack, skill, hurt, and death states. Enemy skill meter fills +25 per turn; at 100 triggers word challenge (STT or Whiteboard). Battle log shows combat events. Stage timer tracks completion time and saves personal best to Firebase. Manager-based architecture handles battle flow, enemy AI, player stats, and challenge coordination.

[screenshot]

**Figure 14. Word Challenge - Speech-to-Text**

Web Speech API with JavaScriptBridge captures voice input for word pronunciation. Fuzzy matching (Levenshtein distance ≤2) accepts phonetically similar words. Success grants 5-15 bonus damage; failure/cancel applies enemy skill damage. Firebase tracks STT challenge completion stats.

[screenshot]

**Figure 15. Word Challenge - Whiteboard**

Drawing canvas captures handwriting as Vector2 stroke arrays. Exports to PNG, encodes Base64, sends to Google Cloud Vision API for OCR (78% accuracy). Undo/redo with stack history, 4 colors, 4 stroke widths. Success grants bonus damage; failure applies enemy skill damage. Firebase tracks whiteboard challenge stats.

[screenshot]

**Figure 16. Victory Screen**

Displays EXP reward (50 for normal enemies, 125/150/175 for bosses). Shows level-up if triggered with stat increases (HP +8-12, DMG +2-4, DUR +1-2). Compares stage completion time to personal best. Firebase saves progression, EXP, level, stats, and best times. Boss victory routes to dungeon selection; regular victory advances to next stage.

[screenshot]

**Figure 17. Defeat Screen**

Supportive messaging with "Try Again" or "Return to Map" options. No energy consumed on defeat. No negative stats saved. Stage timer resets without saving. Firebase tracks word challenge attempts only, not defeats.

[screenshot]

**Figure 18. Module Selection**

Three module cards: Phonics (letters + sight words), Flip Practice (picture matching), Read-Aloud (guided reading + syllables). Progress bars show completion percentage. ModuleProgress.gd handles Firebase persistence with async document updates.

[screenshot]

**Figure 19. Phonics Module Selection**

Two options: Letters (26 uppercase) and Sight Words (20 high-frequency words). Progress tracking via ModuleProgress showing completed items. Navigates to letter tracing or sight word practice.

[screenshot]

**Figure 20. Phonics Letters**

Grid of 26 uppercase letters. Clicking opens tracing activity with directional arrows and start points. Tracing captures Vector2 input, evaluates coverage percentage. TTS plays phoneme on completion. Firebase saves via ModuleProgress.set_phonics_letter_completed().

[screenshot]

**Figure 21. Phonics Sight Words**

List of 20 high-frequency words ("the", "and", "is", etc.). Each word has TTS pronunciation, picture support, and multiple-choice identification. Firebase saves via ModuleProgress.set_phonics_sight_word_completed().

[screenshot]

**Figure 22. Read-Aloud Module Selection**

Two options: Syllable Building (word decomposition) and Guided Story (passage reading). Progress bars show completion. Navigates to respective activities.

[screenshot]

**Figure 23. Syllable Building**

Word decomposition exercises with phoneme-by-phoneme breakdown, visual chunking with color-coded syllables, and blending practice. Progress tracked per word completed via ModuleProgress Firebase sync.

[screenshot]

**Figure 24. Guided Story Reading**

Decodable passages with adjustable WPM (80-180, default 120). Per-sentence replay, focus mode dims other lines. Tap word for syllables, definition, picture. TTS synchronized highlighting. Progress saved to Firebase.

[screenshot]

**Figure 25. Flip Quiz Module Selection**

Two categories: Animals (15 exercises) and Vehicles (15 exercises). Progress bars show completion. No timers (removes speed pressure). Navigates to picture-word matching.

[screenshot]

**Figure 26. Flip Quiz Animals**

15 picture-word matching exercises with animal theme. Flip animation reveals answer. "Try Again" and "Show Example" always available. Firebase tracks completion via ModuleProgress.

[screenshot]

**Figure 27. Flip Quiz Vehicles**

15 picture-word matching exercises with vehicle theme. Same mechanics as Animals. Firebase saves progress separately per category.

[screenshot]

**Figure 28. Leaderboard**

Displays top players ranked by level and experience. Shows username, level, EXP, and rank position. Fetches data from Firebase dyslexia_users collection ordered by stats.player.level descending. Real-time updates when users level up.

[screenshot]

**Figure 29. Change Character**

Grid of character portraits (Lexia, Ragna). Clicking selects and saves to Firebase profile.character_selected field. Updates main menu animation immediately. Character animations play idle, attack, skill, hurt, death states in battles.

[screenshot]

**Figure 30. Settings**

Four tabs: Audio (volume sliders, TTS voice/rate/volume), Display (combat speed 1x-8x), Accessibility (font size, high-contrast, reduce motion), Account (email, username, logout). Settings saved to Firebase profile.preferences with document-based updates. Accessible from main menu and in-battle.
