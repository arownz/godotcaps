# Functionality Test Case - Lexia Educational Dyslexia Game# Functionality Test Case - Lexia Educational Dyslexia Game# Functionality Test Case - Lexia Educational Dyslexia Game

## Splash Screen Tests## Splash Screen Tests## Splash Screen Tests

| **Runs** | **Expected Results** || **Runs** | **Expected Results** || **Runs** | **Expected Results** |

|----------|---------------------|

| Splash Screen Navigation (Splash Screen) - 1 | The godot native progress bar loading with LEXIA logo display which navigates to authentication screen ||----------|---------------------||----------|---------------------|

## Authentication Tests| Splash Screen Navigation (Splash Screen) - 1 | The godot native progress bar loading with LEXIA logo display which navigates to authentication screen || Splash Screen Navigation (Splash Screen) - 1 | The godot native progress bar loading with LEXIA logo display which navigates to authentication screen |

| **Runs** | **Expected Results** |## Authentication Tests## Authentication Tests

|----------|---------------------|

| Authentication Screen (Authentication) - 1 | Navigated to the web authentication, it navigates to input login, input register, and input forgot password tab || **Runs** | **Expected Results** || **Runs** | **Expected Results** |

| Input Registration Tab (Authentication) - 2 | Navigated to the web input register accepts email, username, birthday (day/month/year), password with input validator |

| Input Login Tab (Authentication) - 3 | Navigated to the web input login tab accepts email and password with input validator ||----------|---------------------||----------|---------------------|

| Input Forgot Password Tab (Authentication) - 4 | Navigated to the web input forgot password tab accept email to send firebase auth password reset email |

| Google Sign In/Up (Authentication) - 5 | Google button that navigates to web OAuth2 google login process that led to the google account domain sign in/up screen || Authentication Screen (Authentication) - 1 | Navigated to the web authentication, it navigates to input login, input register, and input forgot password tab || Authentication Screen (Authentication) - 1 | Navigated to the web authentication, it navigates to input login, input register, and input forgot password tab |

| Admin Button (Authentication) - 6 | The application hidden admin features, click 7 times on the Lexia logo for the admin button to appear |

| Admin Navigation (Authentication) - 7 | The web navigates to the domain of https://gamedevcapz-admin.web.app/login || Input Registration Tab (Authentication) - 2 | Navigated to the web input register accepts email, username, birthday (day/month/year), password with input validator || Input Registration Tab (Authentication) - 2 | Navigated to the web input register accepts email, username, birthday (day/month/year), password with input validator |

| Setting Button (Authentication) - 8 | Settings button opens settings popup with volume controls, TTS control |

| Authenticated User Navigate (Authentication) - 9 | After user is authenticated via native input or google sign in, navigate to main menu screen || Input Login Tab (Authentication) - 3 | Navigated to the web input login tab accepts email and password with input validator || Input Login Tab (Authentication) - 3 | Navigated to the web input login tab accepts email and password with input validator |

## Main Menu Tests| Input Forgot Password Tab (Authentication) - 4 | Navigated to the web input forgot password tab accept email to send firebase auth password reset email || Input Forgot Password Tab (Authentication) - 4 | Navigated to the web input forgot password tab accept email to send firebase auth password reset email |

| **Runs** | **Expected Results** || Google Sign In/Up (Authentication) - 5 | Google button that navigates to web OAuth2 google login process that led to the google account domain sign in/up screen || Google Sign In/Up (Authentication) - 5 | Google button that navigates to web OAuth2 google login process that led to the google account domain sign in/up screen |

|----------|---------------------|

| Main Menu Scene Loading (Main Menu) - 1 | Main menu displays character animation, navigation buttons (Journey Mode, Learning Modules, Character Selection, Leaderboard, Setting), user profile name, level and energy display || Admin Button (Authentication) - 6 | The application hidden admin features, click 7 times on the Lexia logo for the admin button to appear || Admin Button (Authentication) - 6 | The application hidden admin features, click 7 times on the Lexia logo for the admin button to appear |

| Navigations Button Click (Main Menu) - 2 | Navigation buttons click plays sound effect, shows fade-out animation, and navigates to each screen/popup |

| User Profile Info Display (Main Menu) - 3 | The main menu correctly displays the logged-in user's profile information, including their username, selected avatar image, and current level, and these details are consistent with the information stored in the firebase || Admin Navigation (Authentication) - 7 | The web navigates to the domain of https://gamedevcapz-admin.web.app/login || Admin Navigation (Authentication) - 7 | The web navigates to the domain of https://gamedevcapz-admin.web.app/login |

| Energy Display (Main Menu) - 4 | Energy bar shows user's current energy (e.g., 20/20) and updates correctly when -2 is consumed in journey mode and will be recharged with 4 energies within 300 second |

| Journey Mode Navigation (Main Menu) - 5 | Journey Mode button plays sound effects, shows transition animation, and navigates to the Dungeon mode screen || Setting Button (Authentication) - 8 | Settings button opens settings popup with volume controls, TTS control || Setting Button (Authentication) - 8 | Settings button opens settings popup with volume controls, TTS control |

| Learning Modules Navigation (Main Menu) - 6 | Learning Modules button plays sound effect, shows transition animation, and navigates to the learning modules screen |

| Leaderboard Navigation (Main Menu) - 7 | Leaderboard button plays sound effect, shows transition animation, and navigates to the leaderboard screen || Authenticated User Navigate (Authentication) - 9 | After user is authenticated via native input or google sign in, navigate to main menu screen || Authenticated User Navigate (Authentication) - 9 | After user is authenticated via native input or google sign in, navigate to main menu screen |

| Settings Navigation (Main Menu) - 8 | Settings button plays sound effect, shows transition animation, and navigates to the settings panel with audio and accessibility options |

| Character Selection Navigation (Main Menu) - 9 | Character Selection button plays sound effects, shows transition animation, and navigates to the character selection screen |## Main Menu Tests## Main Menu Tests

## Journey Mode Tests| **Runs** | **Expected Results** || **Runs** | **Expected Results** |

| **Runs** | **Expected Results** ||----------|---------------------||----------|---------------------|

|----------|---------------------|

| Dungeon Selection Screen (Journey Mode) - 1 | Show 3 dungeons selection: The Plain (Dungeon 1), The Forest (Dungeon 2), The Mountain (Dungeon 3) || Main Menu Scene Loading (Main Menu) - 1 | Main menu displays character animation, navigation buttons (Journey Mode, Learning Modules, Character Selection, Leaderboard, Setting), user profile name, level and energy display || Main Menu Scene Loading (Main Menu) - 1 | Main menu displays character animation, navigation buttons (Journey Mode, Learning Modules, Character Selection, Leaderboard, Setting), user profile name, level and energy display |

| Dungeon Unlock (Journey Mode) - 2 | Dungeon is based on user current firebase stored progress. Dungeon 1 is default unlock, Notification will pop up if Dungeon 2 or 3 selection button is click, which shows a message about unlock condition |

| Dungeon Map Stages Screen (Journey Mode) - 3 | Dungeon map screen with 5 stages button, Stage 1-4 (Mob) and Stage 5 (Boss) || Navigations Button Click (Main Menu) - 2 | Navigation buttons click plays sound effect, shows fade-out animation, and navigates to each screen/popup || Navigations | |

| Dungeon Stages Panel (Journey Mode) - 4 | Once stage button is clicked, a stage mob/boss panel pops up with information about that mob name, description, stats, and reward Fight button that will navigate to battle scene screen to engage that mob/boss |

| Battle Scene Screen (Journey Mode) - 5 | A battle scene that shows a player (left) and enemy (right) with player/enemy information, progress bar of HP, enemy skill meter In right panel shows Player firebase fetch HP, EXP, Attack, Durability progress bar, battle logs, and Engage Button At the top is setting button, timer, and progress stage header || User Profile Info Display (Main Menu) - 3 | The main menu correctly displays the logged-in user's profile information, including their username, selected avatar image, and current level, and these details are consistent with the information stored in the firebase || Button Click (Main Menu) – 2 | Navigation |

| Turn Base Battle Basic (Journey Mode) - 6 | Engage through turn base auto battle tactic where player engage from left and enemy from right |

| Enemy Skill Meter and Counter (Journey Mode) - 7 | Condition: If enemy accumulated 100% skill meter from getting damage by player and damaging player, then, Enemy will use skill and counter random word challenge panel pop up will appear - 50% Whiteboard or Speech to text || Energy Display (Main Menu) - 4 | Energy bar shows user's current energy (e.g., 20/20) and updates correctly when -2 is consumed in journey mode and will be recharged with 4 energies within 300 second || buttons click plays sound effect, shows fade-out animation, and navigates to each | |

| Whiteboard Screen (Journey Mode) - 8 | Whiteboard screen popup shows the random word based on letter count (Dungeon 1 = 3 letters, Dungeon 2 = 4 letters, Dungeon 3 = 5 letters) text to speech read and setting button Whiteboard Interface with undo, redo, clear, cancel and done button |

| Whiteboard Condition and Bonus Damage (Journey Mode) - 9 | Condition: if stroke random word is similar, then perfect high bonus damage counter to enemy skill, Else if, near similar then near perfect low bonus damage counter to enemy skill, Else, get damage by enemy skill || Journey Mode Navigation (Main Menu) - 5 | Journey Mode button plays sound effects, shows transition animation, and navigates to the Dungeon mode screen || screen/popup. | |

| Speech to text Screen (Journey Mode) - 10 | STT screen popup shows the random word based on letter count (Dungeon 1 = 3 letters, Dungeon 2 = 4 letters, Dungeon 3 = 5 letters) text to speech read and setting button STT Interface with speak and cancel button |

| Speech to text Condition (Journey Mode) - 11 | Condition: if STT random word is similar, then perfect high bonus damage counter to enemy skill, Else if, near similar then near perfect low bonus damage counter to enemy skill, Else, get damage by enemy skill || Learning Modules Navigation (Main Menu) - 6 | Learning Modules button plays sound effect, shows transition animation, and navigates to the learning modules screen || User Profile into Display (Main Menu)–3 | The main menu |

| Level up stats (Journey Mode) - 12 | Condition: If player exp = 100% then level up with stats change in HP, ATTACK and DURABILITY - show level up logs in battle logs |

| Victory Conditions (Journey Mode) - 13 | Enemy HP reaches 0: Player wins, gains experience, potential level up, and returns to dungeon map. Boss victories unlock next dungeon || Leaderboard Navigation (Main Menu) - 7 | Leaderboard button plays sound effect, shows transition animation, and navigates to the leaderboard screen || correctly displays the logged-in user’s profile information, including their | |

| Defeat Conditions (Journey Mode) - 14 | Player HP reaches 0: Game over screen appears with restart battle and quit to menu options |

| Energy Consumption (Journey Mode) - 15 | Each battle consumes 2 energy. Insufficient energy shows notification with current/max energy and recovery time (300s per energy) || Settings Navigation (Main Menu) - 8 | Settings button plays sound effect, shows transition animation, and navigates to the settings panel with audio and accessibility options || username, selected avatar image, and current level, and these details are | |

| Energy Recovery (Journey Mode) - 16 | Energy recovers 1 point every 300 seconds automatically, displayed in main menu and battle notifications |

| Settings Popup (Journey Mode) - 17 | Settings button opens battle settings popup with Engage, Leave, volume controls, TTS settings, and quit options || Character Selection Navigation (Main Menu) - 9 | Character Selection button plays sound effects, shows transition animation, and navigates to the character selection screen || consistent with the information stored in the firebase. | |

| Battle Timer (Journey Mode) - 18 | Stage timer tracks battle duration and displays in top area of battle scene |

| Progressive Difficulty (Journey Mode) - 19 | Word challenges increase in difficulty: Dungeon 1 (3 letters), Dungeon 2 (4 letters), Dungeon 3 (5 letters) || Energy Display (Main Menu) - 4 | Energy |

| TTS/STT Button Blocking (Journey Mode) - 20 | When STT microphone is active, TTS "Read Word" button becomes disabled and grayed out to prevent audio feedback loops |

## Journey Mode Tests| bar shows user’s current energy (e.g., 20/20) and updates correctly when -2 is | |

## Learning Modules Tests

| consumed in journey mode and will be recharged with 4 energies within 300 second. | |

| **Runs** | **Expected Results** |

|----------|---------------------|| **Runs** | **Expected Results** || Journey Mode Navigation (Main Menu) – 5 | Journey |

| Module Selection Screen (Learning Modules) - 1 | Displays 3 module cards: Phonics Interactive, Flip Quiz Interactive, and Interactive Read-Aloud with progress bars and action buttons |

| Module Progress Display (Learning Modules) - 2 | Each module card shows current progress percentage based on Firebase stored completion data ||----------|---------------------|| Mode button plays sound effects, shows transition animation, and navigates to | |

| Phonics Module Selection (Learning Modules) - 3 | Phonics Interactive button leads to phonics categories: Letters (A-Z practice) and Sight Words (common words practice) |

| Phonics Letters Activity (Learning Modules) - 4 | Interactive letter learning with TTS pronunciation, tracing practice, and whiteboard writing verification || Dungeon Selection Screen (Journey Mode) - 1 | Show 3 dungeons selection: The Plain (Dungeon 1), The Forest (Dungeon 2), The Mountain (Dungeon 3) || the Dungeon mode screen. | |

| Phonics Sight Words Activity (Learning Modules) - 5 | Common sight words practice with TTS pronunciation, visual highlighting, and whiteboard recognition |

| Flip Quiz Module Selection (Learning Modules) - 6 | Flip Quiz Interactive button leads to categories: Animals and Vehicles with matching card games || Dungeon Unlock (Journey Mode) - 2 | Dungeon is based on user current firebase stored progress. Dungeon 1 is default unlock, Notification will pop up if Dungeon 2 or 3 selection button is click, which shows a message about unlock condition || Learning Modules Navigation (Main Menu) | |

| Flip Quiz Animals Activity (Learning Modules) - 7 | Animal matching game with picture cards, sound effects, word-to-image matching, and progress tracking |

| Flip Quiz Vehicles Activity (Learning Modules) - 8 | Variable matching game with picture cards, word-to-image matching, and completion celebration || Dungeon Map Stages Screen (Journey Mode) - 3 | Dungeon map screen with 5 stages button, Stage 1-4 (Mob) and Stage 5 (Boss) || – 6 | Learning |

| Read-Aloud Module Selection (Learning Modules) - 9 | Interactive Read-Aloud button leads to categories: Guided Reading (sentence practice) and Syllable Workshop (word breaking) |

| Guided Reading Activity (Learning Modules) - 10 | Progressive sentence reading with TTS narration, STT pronunciation practice, and word highlighting || Dungeon Stages Panel (Journey Mode) - 4 | Once stage button is clicked, a stage mob/boss panel pops up with information about that mob name, description, stats, and reward Fight button that will navigate to battle scene screen to engage that mob/boss || Modules button plays sound effect, shows transition animation, and navigates | |

| Syllable Workshop Activity (Learning Modules) - 11 | Word syllable breaking practice with TTS pronunciation of full words and individual syllables, STT recognition |

| TTS/STT Mutual Blocking (Learning Modules) - 12 | When STT is active, all TTS buttons (Hear Word, Hear Syllables, Read) become disabled and grayed out to prevent feedback loops || Battle Scene Screen (Journey Mode) - 5 | A battle scene that shows a player (left) and enemy (right) with player/enemy information, progress bar of HP, enemy skill meter In right panel shows Player firebase fetch HP, EXP, Attack, Durability progress bar, battle logs, and Engage Button At the top is setting button, timer, and progress stage header || to the learning modules screen. | |

| Module Progress Persistence (Learning Modules) - 13 | All module progress saves to Firebase and persists across sessions, updating progress bars and completion status |

| Completion Celebration (Learning Modules) - 14 | Completing letters, sight words, or activities triggers celebration popup with progress feedback and continuation options || Turn Base Battle Basic (Journey Mode) - 6 | Engage through turn base auto battle tactic where player engage from left and enemy from right || Leaderboard Navigation (Main Menu) – 7 | Leaderboard |

| Accessibility Features (Learning Modules) - 15 | All modules use dyslexia-friendly fonts, high contrast colors, clear button states, and generous timing without pressure |

| Settings Integration (Learning Modules) - 16 | Settings button in each module opens popup with TTS voice/rate controls, volume adjustment, and guide features || Enemy Skill Meter and Counter (Journey Mode) - 7 | Condition: If enemy accumulated 100% skill meter from getting damage by player and damaging player, then, Enemy will use skill and counter random word challenge panel pop up will appear - 50% Whiteboard or Speech to text || button plays sound effect, shows transition animation, and navigates to the | |

| Real-time UI Updates (Learning Modules) - 17 | Progress bars and completion status update immediately after completing activities, with window focus refresh capability |

| Whiteboard Screen (Journey Mode) - 8 | Whiteboard screen popup shows the random word based on letter count (Dungeon 1 = 3 letters, Dungeon 2 = 4 letters, Dungeon 3 = 5 letters) text to speech read and setting button Whiteboard Interface with undo, redo, clear, cancel and done button || leaderboard screen. | |

## Accessibility & Settings Tests

| Whiteboard Condition and Bonus Damage (Journey Mode) - 9 | Condition: if stroke random word is similar, then perfect high bonus damage counter to enemy skill, Else if, near similar then near perfect low bonus damage counter to enemy skill, Else, get damage by enemy skill || Settings Navigation (Main Menu) – 8 | Settings |

| **Runs** | **Expected Results** |

|----------|---------------------|| Speech to text Screen (Journey Mode) - 10 | STT screen popup shows the random word based on letter count (Dungeon 1 = 3 letters, Dungeon 2 = 4 letters, Dungeon 3 = 5 letters) text to speech read and setting button STT Interface with speak and cancel button || button plays sound effect, shows transition animation, and navigates to the | |

| Settings Popup Access (Accessibility) - 1 | Settings button appears in main menu, authentication, battle scenes, and all module scenes with consistent popup overlay |

| TTS Voice Selection (Accessibility) - 2 | TTS Settings popup shows available system voices with dropdown selection, preview capability, and immediate application || Speech to text Condition (Journey Mode) - 11 | Condition: if STT random word is similar, then perfect high bonus damage counter to enemy skill, Else if, near similar then near perfect low bonus damage counter to enemy skill, Else, get damage by enemy skill || settings panel with audio and accessibility options. | |

| TTS Rate Control (Accessibility) - 3 | TTS rate slider adjusts speech speed (0.5x to 2.0x) with real-time preview and persistence across all modules |

| TTS Volume Control (Accessibility) - 4 | TTS volume slider (0-100%) adjusts text-to-speech volume independently from system/game audio || Level up stats (Journey Mode) - 12 | Condition: If player exp = 100% then level up with stats change in HP, ATTACK and DURABILITY - show level up logs in battle logs || Character Selection Navigation (Main | |

| Master Volume Control (Accessibility) - 5 | Master volume slider controls overall game audio including button sounds, background music, and sound effects |

| Background Music Toggle (Accessibility) - 6 | Background music can be enabled/disabled with settings persisting across sessions and scenes || Victory Conditions (Journey Mode) - 13 | Enemy HP reaches 0: Player wins, gains experience, potential level up, and returns to dungeon map. Boss victories unlock next dungeon || Menu) – 9 | Character |

| Dyslexia-Friendly Design (Accessibility) - 7 | All text uses dyslexia-friendly fonts, high contrast colors, generous spacing, and clear visual hierarchy |

| Button State Indication (Accessibility) - 8 | Disabled buttons show visual indication (grayed out), proper cursor states (pointer vs arrow), and clear feedback || Defeat Conditions (Journey Mode) - 14 | Player HP reaches 0: Game over screen appears with restart battle and quit to menu options || Selection button plays sound effects, shows transition animation, and | |

| Settings Persistence (Accessibility) - 9 | All settings save automatically and persist across browser sessions, scenes, and device restarts |

| Popup Background Dismissal (Accessibility) - 10 | Settings popups can be dismissed by clicking background overlay or close button with fade-out animation || Energy Consumption (Journey Mode) - 15 | Each battle consumes 2 energy. Insufficient energy shows notification with current/max energy and recovery time (300s per energy) || navigates to the character selection screen. | |

| Context-Aware Settings (Accessibility) - 11 | Battle scenes show battle-specific options (Engage/Leave buttons), while other scenes show standard settings only |

| Hover Sound Effects (Accessibility) - 12 | All interactive buttons play hover sound on mouse enter and click sound on activation for audio feedback || Energy Recovery (Journey Mode) - 16 | Energy recovers 1 point every 300 seconds automatically, displayed in main menu and battle notifications |

| Visual Transition Effects (Accessibility) - 13 | All scene transitions use smooth fade-in/fade-out effects with scale animation for visual continuity |

| Error Handling & Feedback (Accessibility) - 14 | STT permission errors, TTS failures, and network issues show clear, user-friendly error messages with recovery options || Settings Popup (Journey Mode) - 17 | Settings button opens battle settings popup with Engage, Leave, volume controls, TTS settings, and quit options || **Runs** | **Expected Results** | |

## Profile Tests 

| **Runs** | **Expected Results** |

|----------|---------------------|| Phonics Module Selection (Learning Modules) - 3 | Phonics Interactive button leads to phonics categories: Letters (A-Z practice) and Sight Words (common words practice) || with 5 stages button, Stage 1-4 (Mob) and Stage 5 (Boss). | | |

| Profile Popup Access (Profile Management) - 1 | Profile button in main menu opens popup overlay with user information, stats, character display, and dungeon progress |

| User Information Display (Profile Management) - 2 | Profile popup displays current username, email, unique UID, character level, and equipped profile picture from Firebase data || Phonics Letters Activity (Learning Modules) - 4 | Interactive letter learning with TTS pronunciation, tracing practice, and whiteboard writing verification || Dungeon Stages Panel (Journey Mode) – 4 | Once stage button is clicked, | |

| Player Statistics Display (Profile Management) - 3 | Profile shows current player stats including Health, Attack, Durability values, with character bonuses calculated and displayed separately |

| Character Animation Display (Profile Management) - 4 | Profile popup shows animated character sprite based on currently selected character (Lexia, Ragna, or Magi) || Phonics Sight Words Activity (Learning Modules) - 5 | Common sight words practice with TTS pronunciation, visual highlighting, and whiteboard recognition || a stage mob/boss panel pops up with information about that mob name, | | |

| Dungeon Progress Display (Profile Management) - 5 | Profile shows current dungeon name, stage number, and appropriate dungeon background image based on user's progression |

| Energy Status Display (Profile Management) - 6 | Profile displays current energy level and maximum energy with proper formatting || Flip Quiz Module Selection (Learning Modules) - 6 | Flip Quiz Interactive button leads to categories: Animals and Vehicles with matching card games || description, stats, and reward Fight button that | | |

| Rank Medal Display (Profile Management) - 7 | Profile shows appropriate medal icon (bronze, silver, gold) based on calculated user rank from dungeon progression |

| Profile Picture Change (Profile Management) - 8 | Clicking profile picture opens selection popup with grid of available portrait options and current selection highlighted || Flip Quiz Animals Activity (Learning Modules) - 7 | Animal matching game with picture cards, sound effects, word-to-image matching, and progress tracking || will navigate to battle scene screen to engage that mob/boss. | | |

| Profile Picture Selection (Profile Management) - 9 | Portrait selection popup shows checkmark on currently equipped picture, allows selection with highlighting, and confirm button activation |

| Profile Picture Confirmation (Profile Management) - 10 | Confirming new profile picture updates Firebase database and immediately refreshes profile display with new picture || Flip Quiz Vehicles Activity (Learning Modules) - 8 | Vehicle matching game with picture cards, word-to-image matching, and completion celebration || Battle Scene Screen (Journey Mode) – 5 | A battle scene that shows | |

| Username Editing (Profile Management) - 11 | Edit username button opens input panel with current username pre-filled, validation for empty names, and Firebase update on confirmation |

| UID Copy Functionality (Profile Management) - 12 | Copy UID button copies user's Firebase authentication ID to clipboard with success notification popup || Read-Aloud Module Selection (Learning Modules) - 9 | Interactive Read-Aloud button leads to categories: Guided Reading (sentence practice) and Syllable Workshop (word breaking) || a player (left) and enemy (right) with player/enemy information, progress bar | | |

| Dungeon Navigation (Profile Management) - 13 | Clicking dungeon area closes profile popup and navigates directly to user's current dungeon map scene |

| Character Selection Navigation (Profile Management) - 14 | Clicking character area closes profile popup and navigates to character selection scene for character switching || Guided Reading Activity (Learning Modules) - 10 | Progressive sentence reading with TTS narration, STT pronunciation practice, and word highlighting || of HP, enemy skill meter In right panel shows Player | | |

| Profile Popup Dismissal (Profile Management) - 15 | Profile popup can be closed via close button or background click with smooth fade-out animation |

| Logout Functionality (Profile Management) - 16 | Logout button properly clears Firebase authentication, sets logout flag, and navigates to authentication scene || Syllable Workshop Activity (Learning Modules) - 11 | Word syllable breaking practice with TTS pronunciation of full words and individual syllables, STT recognition || firebase fetch HP, EXP, Attack, Durability progress bar, battle logs, and Engage | | |

| Profile Data Persistence (Profile Management) - 17 | All profile changes save to Firebase immediately and persist across browser sessions with real-time synchronization |

| TTS/STT Mutual Blocking (Learning Modules) - 12 | When STT is active, all TTS buttons (Hear Word, Hear Syllables, Read) become disabled and grayed out to prevent feedback loops || Button At the top is setting | | |

## Character Selection Tests

| **Runs** | **Expected Results** |

|----------|---------------------|| Completion Celebration (Learning Modules) - 14 | Completing letters, sight words, or activities triggers celebration popup with progress feedback and continuation options || Turn Base Battle Basic (Journey Mode) – 6 | Engage through turn | |

| Character Selection Screen Access (Character Selection) - 1 | Character selection scene displays carousel with 3 character options (Lexia, Ragna, Magi) in circular arrangement |

| Character Unlock Status Display (Character Selection) - 2 | Characters show unlocked/locked status based on dungeon progression: Lexia (always), Ragna (Dungeon 1 complete), Magi (Dungeon 2 complete) || Accessibility Features (Learning Modules) - 15 | All modules use dyslexia-friendly fonts, high contrast colors, clear button states, and generous timing without pressure || base auto battle tactic where player engage from left and enemy from right. | | |

| Circular Character Navigation (Character Selection) - 3 | Next/Previous buttons rotate through characters in circular pattern (0→1→2→0) with smooth carousel animation |

| Character Selection Indicators (Character Selection) - 4 | Selected character shows visual selection indicator with pulsing animation and highlight border around character card || Settings Integration (Learning Modules) - 16 | Settings button in each module opens popup with TTS voice/rate controls, volume adjustment, and guide features || Enemy Skill Meter and Counter (Journey Mode) | | |

| Character Stats Popup (Character Selection) - 5 | Clicking unlocked character opens detailed stats popup showing weapon, counter attack, stat bonuses, and character description |

| Character Stats Information (Character Selection) - 6 | Stats popup displays character-specific weapon names, counter attack names, health/attack/durability bonuses with color coding || Real-time UI Updates (Learning Modules) - 17 | Progress bars and completion status update immediately after completing activities, with window focus refresh capability || – 7 | Condition: If enemy | |

| Locked Character Notification (Character Selection) - 7 | Clicking locked character triggers notification popup explaining unlock requirements (dungeon completion needed) |

| Character Selection Confirmation (Character Selection) - 8 | Select button only enabled for unlocked characters, saves selection to Firebase, and returns to main menu || accumulated 100% skill meter from getting damage by player and damaging | | |

| Character Animation Preview (Character Selection) - 9 | Each character displays appropriate texture/sprite with unlocked characters showing full detail and locked showing locked overlay |

| Character Data Persistence (Character Selection) - 10 | Selected character saves to Firebase user profile and affects battle stats, animations, and profile display |## Accessibility & Settings Tests| player, then, Enemy will use skill and | | |

| Navigation Controls (Character Selection) - 11 | Back button returns to main menu, navigation buttons work in circular pattern regardless of unlock status |

| Hover Sound Effects (Character Selection) - 12 | All interactive elements (buttons, character cards) play appropriate hover and click sound effects || counter random word challenge panel pop up will appear – 50% Whiteboard or | | |

| Character Bonus Calculation (Character Selection) - 13 | Each character applies correct stat bonuses: Lexia (balanced), Ragna (+attack, -durability), Magi (+health, +durability) |

| Selection Visual Feedback (Character Selection) - 14 | Selected character shows clear visual distinction with animated selection indicator and proper highlighting || **Runs** | **Expected Results** || Speech to text. | | |

## Leaderboard Tests

| Leaderboard Screen Access (Leaderboard) - 1 | Leaderboard scene loads with three tabs: Dungeon Rankings, Power Scale, and Word Masters with fade-in animation || TTS Voice Selection (Accessibility) - 2 | TTS Settings popup shows available system voices with dropdown selection, preview capability, and immediate application || Dungeon 2 = 4 letters, Dungeon 3 = 5 letters)\*\* text to speech read | | |

| Tab Navigation System (Leaderboard) - 2 | Tab container allows switching between different ranking categories with enhanced tab styling and hover effects |

| Dungeon Rankings Display (Leaderboard) - 3 | Dungeon Rankings tab shows players ranked by progression with columns: Rank, Avatar, Player, Medal, Dungeon, Stage, Kills || TTS Rate Control (Accessibility) - 3 | TTS rate slider adjusts speech speed (0.5x to 2.0x) with real-time preview and persistence across all modules || and setting button Whiteboard Interface with | | |

| Power Scale Rankings Display (Leaderboard) - 4 | Power Scale tab displays players ranked by combined stats with columns: Rank, Avatar, Player, Level, HP, DMG, DEF, Scale |

| Word Masters Rankings Display (Leaderboard) - 5 | Word Masters tab shows players ranked by challenge performance with columns: Rank, Avatar, Player, STT, Board, Total || TTS Volume Control (Accessibility) - 4 | TTS volume slider (0-100%) adjusts text-to-speech volume independently from system/game audio || undo, redo, clear, cancel and done button. | | |

| User Data Fetching (Leaderboard) - 6 | Leaderboard fetches all user data from Firebase dyslexia_users collection and processes for ranking calculations |

| Ranking Calculation System (Leaderboard) - 7 | Players ranked appropriately: Dungeon progress for dungeon rankings, total stats for power scale, word challenges for masters || Master Volume Control (Accessibility) - 5 | Master volume slider controls overall game audio including button sounds, background music, and sound effects || Whiteboard Condition and Bonus Damage (Journey | | |

| Medal Assignment Logic (Leaderboard) - 8 | Players receive appropriate medals (gold, silver, bronze) based on their ranking position in dungeon progression |

| Avatar Display System (Leaderboard) - 9 | Each leaderboard entry shows player's selected profile picture with proper loading and fallback handling || Background Music Toggle (Accessibility) - 6 | Background music can be enabled/disabled with settings persisting across sessions and scenes || Mode) – 9 | Condition: if stroke | |

| Current User Highlighting (Leaderboard) - 10 | Current authenticated user's entry highlighted differently in rankings for easy identification |

| Responsive Table Layout (Leaderboard) - 11 | Leaderboard tables use responsive design with proper column sizing, text truncation, and bordered containers || Dyslexia-Friendly Design (Accessibility) - 7 | All text uses dyslexia-friendly fonts, high contrast colors, generous spacing, and clear visual hierarchy || random word is similar, then perfect high bonus damage counter to enemy skill, Else if, near similar | | |

| Data Sorting and Filtering (Leaderboard) - 12 | Rankings properly sorted by relevant criteria with ties handled appropriately and consistent ordering |

| Dungeon Name Mapping (Leaderboard) - 13 | Dungeon numbers correctly mapped to names: 1=The Plain, 2=The Forest, 3=The Mountain in dungeon rankings || Button State Indication (Accessibility) - 8 | Disabled buttons show visual indication (grayed out), proper cursor states (pointer vs arrow), and clear feedback || then near perfect low bonus damage counter to enemy skill, Else, get damage by | | |

| Statistical Data Display (Leaderboard) - 14 | All player statistics (health, attack, durability, challenge counts) display accurately with proper formatting |

| Leaderboard Navigation (Leaderboard) - 15 | Back button returns to main menu with fade-out animation and proper scene transition || Settings Persistence (Accessibility) - 9 | All settings save automatically and persist across browser sessions, scenes, and device restarts || enemy skill | | |

| Real-time Data Updates (Leaderboard) - 16 | Leaderboard data refreshes to show current player statistics and rankings based on latest Firebase data |

| Error Handling (Leaderboard) - 17 | Graceful handling of missing player data, network errors, and invalid Firebase responses with fallback displays || Popup Background Dismissal (Accessibility) - 10 | Settings popups can be dismissed by clicking background overlay or close button with fade-out animation || Speech to text Screen (Journey Mode) – 10 | STT screen popup shows | |

| Context-Aware Settings (Accessibility) - 11 | Battle scenes show battle-specific options (Engage/Leave buttons), while other scenes show standard settings only || the random word based on letter count\*\*(Dungeon 1 = 3 letters, Dungeon 2 = | | |

| Hover Sound Effects (Accessibility) - 12 | All interactive buttons play hover sound on mouse enter and click sound on activation for audio feedback || 4 letters, Dungeon 3 = 5 letters)\*\* text to speech read | | |

| Visual Transition Effects (Accessibility) - 13 | All scene transitions use smooth fade-in/fade-out effects with scale animation for visual continuity || and setting button STT Interface with speak | | |

| Error Handling & Feedback (Accessibility) - 14 | STT permission errors, TTS failures, and network issues show clear, user-friendly error messages with recovery options || and cancel button | | |

| Speech to text Condition (Journey Mode) – 11 | Condition: if STT | |
