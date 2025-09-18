# Lexia: A Gamified Web for Dyslexia Children - Comprehensive Test Cases Documentation

## Overview

This document provides comprehensive test cases for the Lexia gamified learning web application, covering all functionality from initialization through completion for both Journey Mode and Module Mode pathways.

---

## Test Cases Table

| Test Case Scenario ID                  | Name of Module Function     | Test Case Scenario                         | Action                                       | Actual Input                                                  |
| -------------------------------------- | --------------------------- | ------------------------------------------ | -------------------------------------------- | ------------------------------------------------------------- |
| **SYSTEM INITIALIZATION**              |                             |                                            |                                              |                                                               |
| TC-INIT-001                            | SplashScene                 | Application startup and loading            | Launch web application                       | Browser URL access                                            |
| TC-INIT-002                            | SplashScene Animation       | Logo breathing animation display           | Wait 4 seconds during splash                 | Automatic timing                                              |
| TC-INIT-003                            | SplashScene Transition      | Smooth fade to authentication              | Complete splash screen timing                | Automatic scene change                                        |
| **AUTHENTICATION SYSTEM**              |                             |                                            |                                              |                                                               |
| TC-AUTH-001                            | Email Registration          | New user account creation                  | Click "Register" tab, fill form, submit      | Email: test@example.com, Password: TestPass123                |
| TC-AUTH-002                            | Email Login                 | Existing user authentication               | Click "Login" tab, enter credentials, submit | Valid email/password combination                              |
| TC-AUTH-003                            | Google Authentication       | OAuth login process                        | Click "Sign in with Google" button           | Google account credentials                                    |
| TC-AUTH-004                            | Admin Access                | Hidden administrator features              | Click logo 7 times rapidly                   | 7 consecutive clicks on logo                                  |
| TC-AUTH-005                            | Authentication Validation   | Form validation and error handling         | Submit empty form or invalid data            | Empty fields or malformed email                               |
| TC-AUTH-006                            | Password Requirements       | Strong password enforcement                | Enter weak password during registration      | Password: 123 (too weak)                                      |
| **MAIN MENU NAVIGATION**               |                             |                                            |                                              |                                                               |
| TC-MENU-001                            | Main Menu Loading           | User profile and energy display            | Successfully authenticate and load main menu | Valid login credentials                                       |
| TC-MENU-002                            | Energy System Display       | Current energy and maximum energy shown    | View energy indicator in top panel           | Visual energy counter (20 max)                                |
| TC-MENU-003                            | Energy Recovery             | 4-minute energy recovery intervals         | Wait for energy recovery                     | Time-based automatic recovery                                 |
| TC-MENU-004                            | Journey Mode Access         | Navigate to dungeon selection              | Click "Journey Mode" button                  | Single click on Journey button                                |
| TC-MENU-005                            | Module Mode Access          | Navigate to learning modules               | Click "Learning Modules" button              | Single click on Modules button                                |
| TC-MENU-006                            | Settings Access             | Open settings configuration                | Click settings gear icon                     | Single click on settings icon                                 |
| TC-MENU-007                            | Leaderboard Access          | View rankings and statistics               | Click "Leaderboards" button                  | Single click on Leaderboards button                           |
| TC-MENU-008                            | Profile Access              | View user profile information              | Click profile picture/name                   | Single click on profile area                                  |
| **JOURNEY MODE - DUNGEON SYSTEM**      |                             |                                            |                                              |                                                               |
| TC-JOUR-001                            | Dungeon Selection           | Choose dungeon difficulty level            | Select dungeon from map interface            | Click on Dungeon 1, 2, or 3                                   |
| TC-JOUR-002                            | Stage Selection             | Choose specific stage within dungeon       | Click on stage icon in dungeon map           | Click on unlocked stage                                       |
| TC-JOUR-003                            | Energy Consumption Check    | Verify sufficient energy before battle     | Attempt to start battle with low energy      | Energy < 2 units                                              |
| TC-JOUR-004                            | Battle Initialization       | Load battle scene with enemy               | Click "Engage" button in dungeon             | Single click on Engage button                                 |
| TC-JOUR-005                            | Battle Scene Loading        | Display player stats and enemy             | Successfully enter battle scene              | Complete battle initialization                                |
| **JOURNEY MODE - BATTLE SYSTEM**       |                             |                                            |                                              |                                                               |
| TC-BATT-001                            | Player Stats Display        | Show health, damage, durability, and level | View battle interface                        | Battle scene loaded                                           |
| TC-BATT-002                            | Enemy Information           | Display enemy health and type              | View enemy in battle scene                   | Enemy sprite and health bar                                   |
| TC-BATT-003                            | Turn-Based Combat           | Alternating player/enemy actions           | Start battle sequence                        | Battle auto-progression                                       |
| TC-BATT-004                            | Auto-Battle Toggle          | Enable/disable automatic battles           | Toggle auto-battle button                    | Click auto-battle toggle                                      |
| TC-BATT-005                            | Auto-Battle Speed           | Adjust battle progression speed            | Modify auto-battle speed setting             | Speed slider 1.0-8.0x                                         |
| TC-BATT-006                            | Battle Timer                | Track time spent in current stage          | Monitor stage timer display                  | Active battle timing                                          |
| **WORD CHALLENGE SYSTEM**              |                             |                                            |                                              |                                                               |
| TC-WORD-001                            | Challenge Trigger           | Enemy skill activates word challenge       | Enemy performs skill attack                  | Enemy skill animation                                         |
| TC-WORD-002                            | Word Length Scaling         | Words scale with dungeon difficulty        | Progress through dungeons                    | Dungeon 1: 3-letter, Dungeon 2: 4-letter, Dungeon 3: 5-letter |
| TC-WORD-003                            | STT Challenge Setup         | Speech-to-text word recognition            | Select STT challenge type                    | Word displayed with microphone button                         |
| TC-WORD-004                            | STT Permission Request      | Microphone access permission               | Click "Start Speaking" button                | Browser microphone permission dialog                          |
| TC-WORD-005                            | STT Recording Active        | Live speech recognition feedback           | Speak into microphone                        | Audio input with visual feedback                              |
| TC-WORD-006                            | STT Word Recognition        | Accurate word matching                     | Speak the displayed word clearly             | Spoken word: "cat" for target "cat"                           |
| TC-WORD-007                            | STT Fuzzy Matching          | Dyslexia-friendly word acceptance          | Speak similar-sounding word                  | Spoken word: "kat" for target "cat"                           |
| TC-WORD-008                            | STT Phonetic Matching       | Phonetic similarity recognition            | Speak phonetically similar word              | Spoken word: "bae" for target "bay"                           |
| TC-WORD-009                            | STT Recognition Stop        | End recording and process result           | Click "Stop Recording" button                | Button click to end recording                                 |
| TC-WORD-010                            | Whiteboard Challenge Setup  | Handwriting recognition interface          | Select whiteboard challenge type             | Empty drawing canvas displayed                                |
| TC-WORD-011                            | Whiteboard Drawing          | Write word on digital canvas               | Draw letters with mouse/touch                | Hand-drawn word on canvas                                     |
| TC-WORD-012                            | Whiteboard Cloud Vision     | Google Cloud Vision text recognition       | Submit drawn word                            | Send image to Cloud Vision API                                |
| TC-WORD-013                            | Whiteboard Recognition      | Accurate handwriting matching              | Write legible word on canvas                 | Handwritten word matches target                               |
| TC-WORD-014                            | Challenge Success           | Bonus damage calculation                   | Successfully complete word challenge         | Bonus damage applied to enemy                                 |
| TC-WORD-015                            | Challenge Failure           | Enemy skill damage applied                 | Fail or cancel word challenge                | Enemy skill damage to player                                  |
| TC-WORD-016                            | Challenge Cleanup           | UI cleanup after challenge                 | Complete any challenge outcome               | Challenge panels removed                                      |
| **BATTLE PROGRESSION**                 |                             |                                            |                                              |                                                               |
| TC-PROG-001                            | Enemy Defeat                | Victory condition and rewards              | Defeat enemy in battle                       | Enemy health reaches 0                                        |
| TC-PROG-002                            | Experience Gain             | Player level progression                   | Win battles and gain experience              | Experience points added                                       |
| TC-PROG-003                            | Level Up Benefits           | Stat increases on level up                 | Reach new player level                       | Health/damage increase                                        |
| TC-PROG-004                            | Stage Completion            | Progress to next stage                     | Complete current battle stage                | Unlock next stage                                             |
| TC-PROG-005                            | Boss Battle                 | Special enemy encounters                   | Reach final stage of dungeon                 | Boss enemy with enhanced stats                                |
| TC-PROG-006                            | Dungeon Completion          | Complete all stages in dungeon             | Defeat dungeon boss                          | Return to dungeon selection                                   |
| TC-PROG-007                            | Progress Saving             | Firebase progress persistence              | Complete any battle                          | Progress saved to database                                    |
| **MODULE MODE - MAIN INTERFACE**       |                             |                                            |                                              |                                                               |
| TC-MOD-001                             | Module Selection            | Choose learning module category            | Access Module Mode from main menu            | Three module options displayed                                |
| TC-MOD-002                             | Phonics Module Access       | Navigate to phonics learning               | Click "Phonics" module button                | Phonics module interface loaded                               |
| TC-MOD-003                             | Flip Quiz Module Access     | Navigate to flip quiz games                | Click "Flip Quiz" module button              | Flip Quiz module interface loaded                             |
| TC-MOD-004                             | Read Aloud Module Access    | Navigate to reading practice               | Click "Read Aloud" module button             | Read Aloud module interface loaded                            |
| TC-MOD-005                             | Module Progress Display     | Show completion percentages                | View any module interface                    | Progress bars and percentages                                 |
| **PHONICS MODULE - LETTERS**           |                             |                                            |                                              |                                                               |
| TC-PHON-001                            | Letter Practice Setup       | Initialize alphabet tracing                | Access Phonics Letters                       | Letter A displayed with whiteboard                            |
| TC-PHON-002                            | Letter Display              | Current target letter shown                | View letter practice interface               | Large letter A displayed                                      |
| TC-PHON-003                            | Letter Audio Guide          | TTS pronunciation of letter                | Click "Hear" button                          | Audio pronunciation of current letter                         |
| TC-PHON-004                            | Letter Tracing              | Whiteboard letter tracing                  | Draw letter on whiteboard                    | Hand-drawn letter A on canvas                                 |
| TC-PHON-005                            | Letter Recognition          | Cloud Vision letter recognition            | Submit traced letter                         | Letter A recognized correctly                                 |
| TC-PHON-006                            | Letter Success Feedback     | Completion celebration display             | Successfully trace letter                    | Celebration popup with progress                               |
| TC-PHON-007                            | Letter Progression          | Advance to next letter                     | Complete current letter                      | Move from A to B                                              |
| TC-PHON-008                            | Letter Navigation           | Jump to specific letters                   | Use letter navigation controls               | Click specific letter button                                  |
| TC-PHON-009                            | Progress Persistence        | Save letter completion status              | Complete any letter                          | Firebase progress update                                      |
| TC-PHON-010                            | Adaptive Revisiting         | Return to missed letters                   | Struggle with specific letters               | Recent errors tracked for revisit                             |
| **PHONICS MODULE - SIGHT WORDS**       |                             |                                            |                                              |                                                               |
| TC-SIGHT-001                           | Sight Word Practice Setup   | Initialize sight word tracing              | Access Phonics Sight Words                   | Word "the" displayed                                          |
| TC-SIGHT-002                           | Sight Word Display          | Current target word shown                  | View sight word interface                    | Common sight word displayed                                   |
| TC-SIGHT-003                           | Sight Word Audio            | TTS pronunciation of word                  | Click "Hear" button                          | Audio pronunciation of sight word                             |
| TC-SIGHT-004                           | Sight Word Tracing          | Whiteboard word tracing                    | Draw word on whiteboard                      | Hand-drawn sight word on canvas                               |
| TC-SIGHT-005                           | Sight Word Recognition      | Cloud Vision word recognition              | Submit traced word                           | Sight word recognized correctly                               |
| TC-SIGHT-006                           | Sight Word Success          | Completion celebration display             | Successfully trace word                      | Celebration popup with progress                               |
| TC-SIGHT-007                           | Sight Word Progression      | Advance through 20 sight words             | Complete current word                        | Progress through word list                                    |
| TC-SIGHT-008                           | Combined Progress           | Letters + sight words total                | Complete both letter and word activities     | Combined 46-item progress calculation                         |
| **FLIP QUIZ MODULE - ANIMALS**         |                             |                                            |                                              |                                                               |
| TC-FLIP-001                            | Animal Quiz Setup           | Initialize animal matching game            | Access Flip Quiz Animals                     | Animal card grid displayed                                    |
| TC-FLIP-002                            | Card Flip Mechanics         | Reveal hidden animal cards                 | Click on face-down cards                     | Cards flip to show animals                                    |
| TC-FLIP-003                            | Animal Matching             | Match identical animal pairs               | Click two matching animal cards              | Pair remains revealed                                         |
| TC-FLIP-004                            | Mismatch Handling           | Non-matching cards flip back               | Click two different animals                  | Cards flip back face-down                                     |
| TC-FLIP-005                            | Animal Audio                | Animal sound effects                       | Successfully match animal pair               | Animal sound plays on match                                   |
| TC-FLIP-006                            | Quiz Completion             | Complete all animal pairs                  | Match all available pairs                    | Quiz completion celebration                                   |
| TC-FLIP-007                            | Animal Progress Tracking    | Save animal quiz completion                | Complete animal quiz                         | Progress saved to Firebase                                    |
| **FLIP QUIZ MODULE - VEHICLES**        |                             |                                            |                                              |                                                               |
| TC-FLIP-008                            | Vehicle Quiz Setup          | Initialize vehicle matching game           | Access Flip Quiz Vehicles                    | Vehicle card grid displayed                                   |
| TC-FLIP-009                            | Vehicle Card Flipping       | Reveal hidden vehicle cards                | Click on face-down cards                     | Cards flip to show vehicles                                   |
| TC-FLIP-010                            | Vehicle Matching            | Match identical vehicle pairs              | Click two matching vehicle cards             | Pair remains revealed                                         |
| TC-FLIP-011                            | Vehicle Audio               | Vehicle sound effects                      | Successfully match vehicle pair              | Vehicle sound plays on match                                  |
| TC-FLIP-012                            | Vehicle Quiz Completion     | Complete all vehicle pairs                 | Match all available pairs                    | Quiz completion celebration                                   |
| TC-FLIP-013                            | Combined Flip Progress      | Animals + vehicles combined                | Complete both quiz types                     | Combined flip quiz progress                                   |
| **READ ALOUD MODULE - GUIDED READING** |                             |                                            |                                              |                                                               |
| TC-READ-001                            | Guided Reading Setup        | Initialize reading passages                | Access Read Aloud Guided                     | First passage displayed                                       |
| TC-READ-002                            | Passage Selection           | Choose from 4 reading passages             | Select reading passage                       | Passage text displayed                                        |
| TC-READ-003                            | Sentence Highlighting       | Current sentence emphasized                | View passage interface                       | Current sentence highlighted                                  |
| TC-READ-004                            | Sentence Audio              | TTS reading of sentences                   | Click "Read" button                          | Audio reading of current sentence                             |
| TC-READ-005                            | Reading Speed Control       | Adjust TTS reading pace                    | Modify reading speed setting                 | WPM adjustment (80-180)                                       |
| TC-READ-006                            | STT Sentence Practice       | Speech recognition for sentences           | Click "Practice Speaking" button             | STT interface for sentence                                    |
| TC-READ-007                            | STT Sentence Recognition    | Accurate sentence matching                 | Speak the highlighted sentence               | Spoken sentence matches target                                |
| TC-READ-008                            | STT Fuzzy Sentence Matching | Partial sentence acceptance                | Speak approximate sentence                   | 80%+ word matching accepted                                   |
| TC-READ-009                            | Word Highlighting           | Individual word focus                      | Speak individual words                       | Words highlighted in real-time                                |
| TC-READ-010                            | Sentence Progression        | Advance through passage                    | Complete current sentence                    | Move to next sentence                                         |
| TC-READ-011                            | Passage Completion          | Complete entire reading passage            | Finish all sentences                         | Passage completion celebration                                |
| TC-READ-012                            | Reading Progress Tracking   | Save guided reading completion             | Complete any passage                         | Progress saved to Firebase                                    |
| **SETTINGS SYSTEM**                    |                             |                                            |                                              |                                                               |
| TC-SET-001                             | Settings Access             | Open settings interface                    | Click settings icon                          | Settings panel displayed                                      |
| TC-SET-002                             | Font Size Adjustment        | Modify text size for readability           | Adjust font size slider                      | Text size changes globally                                    |
| TC-SET-003                             | Reading Speed Setting       | Adjust TTS reading pace                    | Modify reading speed slider                  | TTS rate changes (WPM)                                        |
| TC-SET-004                             | High Contrast Toggle        | Enable accessibility contrast              | Toggle high contrast switch                  | UI contrast enhanced                                          |
| TC-SET-005                             | TTS Voice Selection         | Choose text-to-speech voice                | Access TTS settings popup                    | Voice selection dropdown                                      |
| TC-SET-006                             | Volume Controls             | Adjust audio levels                        | Modify volume sliders                        | Master/SFX/Music volume changes                               |
| TC-SET-007                             | Tutorial Toggle             | Enable/disable help guidance               | Toggle tutorial switch                       | Tutorial availability changed                                 |
| TC-SET-008                             | Settings Persistence        | Save configuration changes                 | Modify any setting                           | Settings saved to SettingsManager                             |
| TC-SET-009                             | Background Close            | Close settings with background click       | Click outside settings panel                 | Settings panel closes                                         |
| **LEADERBOARD SYSTEM**                 |                             |                                            |                                              |                                                               |
| TC-LEAD-001                            | Leaderboard Access          | View ranking interface                     | Click "Leaderboards" button                  | Leaderboard tabs displayed                                    |
| TC-LEAD-002                            | Dungeon Rankings            | View dungeon completion stats              | Click "Dungeon Rankings" tab                 | Dungeon progress leaderboard                                  |
| TC-LEAD-003                            | Power Scale Rankings        | View player level rankings                 | Click "Power Scale" tab                      | Player level leaderboard                                      |
| TC-LEAD-004                            | Word Masters Rankings       | View word challenge stats                  | Click "Word Masters" tab                     | Word recognition leaderboard                                  |
| TC-LEAD-005                            | User Position Display       | Show current user's rank                   | View any leaderboard tab                     | Current user highlighted                                      |
| TC-LEAD-006                            | Medal System                | Gold/silver/bronze rank indicators         | View top 3 positions                         | Medal icons displayed                                         |
| TC-LEAD-007                            | Statistics Display          | Detailed user performance data             | View leaderboard entries                     | Stats like completion rates                                   |
| **PROFILE SYSTEM**                     |                             |                                            |                                              |                                                               |
| TC-PROF-001                            | Profile Access              | View user profile information              | Click profile picture/area                   | Profile popup displayed                                       |
| TC-PROF-002                            | User Statistics             | Display progress and achievements          | View profile details                         | Stats like level, dungeons completed                          |
| TC-PROF-003                            | Profile Picture Selection   | Choose avatar from options                 | Click profile picture options                | Avatar selection interface                                    |
| TC-PROF-004                            | Progress Summary            | Overall completion percentages             | View profile statistics                      | Module and journey progress                                   |
| TC-PROF-005                            | Data Export                 | Export user progress data                  | Click "Export Data" button                   | JSON data download                                            |
| **ACCESSIBILITY FEATURES**             |                             |                                            |                                              |                                                               |
| TC-ACC-001                             | TTS Integration             | Text-to-speech throughout app              | Access any text-based content                | Audio reading available                                       |
| TC-ACC-002                             | STT Integration             | Speech-to-text input support               | Access speech input features                 | Microphone input accepted                                     |
| TC-ACC-003                             | Dyslexia Font Support       | Specialized readable fonts                 | View any text content                        | Dyslexia-friendly font rendering                              |
| TC-ACC-004                             | High Contrast Mode          | Enhanced visual accessibility              | Enable high contrast setting                 | Improved color contrast                                       |
| TC-ACC-005                             | Fuzzy Matching              | Forgiving input recognition                | Enter approximate text/speech                | Close matches accepted                                        |
| TC-ACC-006                             | Audio Feedback              | Sound effects and confirmations            | Perform any action                           | Audio confirmation provided                                   |
| TC-ACC-007                             | Visual Feedback             | Clear success/error indicators             | Complete any task                            | Visual feedback displayed                                     |
| **ERROR HANDLING**                     |                             |                                            |                                              |                                                               |
| TC-ERR-001                             | Network Connectivity        | Handle offline conditions                  | Disconnect internet during use               | Graceful error handling                                       |
| TC-ERR-002                             | API Failures                | Handle external service errors             | Random word API unavailable                  | Fallback word selection                                       |
| TC-ERR-003                             | Firebase Errors             | Handle database connection issues          | Firebase service unavailable                 | Local progress fallback                                       |
| TC-ERR-004                             | Microphone Permission       | Handle denied microphone access            | Deny microphone permission                   | Clear error message displayed                                 |
| TC-ERR-005                             | Invalid Input               | Handle malformed user input                | Enter invalid data in forms                  | Input validation and feedback                                 |
| TC-ERR-006                             | Session Timeout             | Handle authentication expiration           | Extended session inactivity                  | Re-authentication prompt                                      |
| **PERFORMANCE & OPTIMIZATION**         |                             |                                            |                                              |                                                               |
| TC-PERF-001                            | Loading Times               | Acceptable scene transition speeds         | Navigate between scenes                      | Transitions under 2 seconds                                   |
| TC-PERF-002                            | Memory Usage                | Efficient resource management              | Extended application usage                   | No memory leaks or crashes                                    |
| TC-PERF-003                            | Audio Performance           | Smooth TTS and audio playback              | Use TTS and sound effects                    | Clear audio without delays                                    |
| TC-PERF-004                            | Visual Performance          | Smooth animations and transitions          | Use interface animations                     | 60fps animation performance                                   |
| TC-PERF-005                            | Database Performance        | Efficient Firebase operations              | Save/load progress frequently                | Quick data persistence                                        |
| **INTEGRATION TESTING**                |                             |                                            |                                              |                                                               |
| TC-INT-001                             | Cross-Module Progress       | Progress tracking across modules           | Complete activities in different modules     | Combined progress calculation                                 |
| TC-INT-002                             | Journey-Module Integration  | Switch between game modes                  | Alternate between Journey and Module modes   | Seamless mode transitions                                     |
| TC-INT-003                             | Settings Application        | Settings affect all modules                | Change settings and use different features   | Settings applied globally                                     |
| TC-INT-004                             | Data Synchronization        | Firebase sync across sessions              | Use app on different devices/sessions        | Progress synchronized                                         |
| TC-INT-005                             | Complete User Journey       | End-to-end application usage               | Complete full learning session               | All features work together                                    |

---

## Test Environment Requirements

### Browser Compatibility

- Chrome 90+ (recommended for STT/TTS features)
- Firefox 88+ (limited STT support)
- Safari 14+ (iOS/macOS)
- Edge 90+

### Hardware Requirements

- Microphone for STT functionality
- Speakers/headphones for TTS and audio feedback
- Mouse/touchscreen for whiteboard tracing
- Stable internet connection for Firebase and APIs

### Test Data Requirements

- Firebase authentication credentials
- Test user accounts with various progress states
- Network simulation tools for error testing
- Multiple device types for responsive testing

---

## Expected Results Summary

### Success Criteria in this current version 1.0

- All authentication methods function correctly
- Both Journey Mode and Module Mode complete successfully
- STT and whiteboard recognition achieve >85% accuracy with dyslexia-friendly fuzzy matching
- Progress persistence works across sessions
- Accessibility features enhance usability for dyslexic users
- Error handling provides clear, helpful feedback
- Performance meets target benchmarks (loading <2s, 60fps animations)

### Key Metrics

- User completion rates for each module
- Recognition accuracy for STT and whiteboard inputs
- Time to complete learning activities
- User engagement and retention metrics
- Error frequency and resolution rates

---

_This documentation covers comprehensive testing scenarios for Lexia: A Gamified Web for Dyslexia Children, ensuring all functionality is validated for optimal user experience._
