# Functional Test Document - Frontend Testing Requirements

## Overview

This document outlines comprehensive functional testing requirements for the Godot Dyslexia Learning Game's frontend user interface and user experience features. Tests focus on navigation, input validation, visual feedback, and educational module functionality.

---

## 1. SPLASH SCREEN AND AUTHENTICATION

### Test Case 1.1: Splash Screen Loading

**Run**: Splash Screen Navigation (Splash Screen) - 1
**Expected Results**: The Godot native progress bar loading with LEXIA logo displays which navigates to authentication screen after 3-second animation with fade-out effect.

### Test Case 1.2: Authentication Screen Display

**Run**: Authentication Scene UI Display (Authentication) - 2
**Expected Results**: Authentication screen shows login/signup forms, Google authentication button, settings button, and proper dyslexia-friendly font rendering with fade-in animation.

### Test Case 1.3: Email Login Validation

**Run**: Email Login Input Validation (Authentication) - 3
**Expected Results**: Email field validates proper email format, shows error messages for invalid inputs in red text, and prevents submission with invalid email formats.

### Test Case 1.4: Password Field Security

**Run**: Password Input Security (Authentication) - 4
**Expected Results**: Password field masks input characters, shows/hides password toggle works, minimum 6 character validation displays appropriate error messages.

### Test Case 1.5: Google Authentication

**Run**: Google Authentication Button (Authentication) - 5
**Expected Results**: Google auth button opens web authentication flow, handles success/failure responses, displays loading state during authentication process.

### Test Case 1.6: Registration Form Validation

**Run**: New User Registration (Authentication) - 6
**Expected Results**: Registration form validates username uniqueness, password confirmation matching, email format, and displays appropriate success/error messages.

### Test Case 1.7: Settings Access from Authentication

**Run**: Settings Button Access (Authentication) - 7
**Expected Results**: Settings button opens settings popup with volume controls, tutorial toggles, and accessibility options without requiring authentication.

---

## 2. MAIN MENU NAVIGATION

### Test Case 2.1: Main Menu Display

**Run**: Main Menu Scene Loading (Main Menu) - 8
**Expected Results**: Main menu displays character animation, navigation buttons (Journey Mode, Learning Modules, Character Selection, Leaderboard), user profile info, and energy display.

### Test Case 2.2: Journey Mode Navigation

**Run**: Journey Mode Button Click (Main Menu) - 9
**Expected Results**: Journey Mode button click plays sound effect, shows fade-out animation, and navigates to Dungeon Selection screen.

### Test Case 2.3: Learning Modules Navigation

**Run**: Learning Modules Button Click (Main Menu) - 10
**Expected Results**: Learning Modules button click plays sound effect, shows fade-out animation, and navigates to Module Selection screen.

### Test Case 2.4: Character Selection Navigation

**Run**: Character Selection Button Click (Main Menu) - 11
**Expected Results**: Character button click plays sound effect, shows fade-out animation, and navigates to Character Selection screen.

### Test Case 2.5: Leaderboard Navigation

**Run**: Leaderboard Button Click (Main Menu) - 12
**Expected Results**: Leaderboard button click plays sound effect, shows fade-out animation, and navigates to Leaderboard screen.

### Test Case 2.6: Profile Popup Display

**Run**: Profile Picture Click (Main Menu) - 13
**Expected Results**: Profile picture click opens profile popup showing username, level, stats, logout option, and profile picture selection.

### Test Case 2.7: Button Hover Effects

**Run**: Button Hover Interactions (Main Menu) - 14
**Expected Results**: Hovering over buttons plays hover sound, shows label text, and provides visual feedback for better accessibility.

---

## 3. CHARACTER SELECTION SYSTEM

### Test Case 3.1: Character Carousel Display

**Run**: Character Selection Screen Loading (Character Selection) - 15
**Expected Results**: Character carousel displays 3 characters (Lexia, Ragna, Magi) with circular navigation, unlock status indicators, and selection highlighting.

### Test Case 3.2: Character Navigation Controls

**Run**: Next/Previous Button Navigation (Character Selection) - 16
**Expected Results**: Next/Previous buttons enable circular character navigation, play sound effects, and smooth animation transitions between characters.

### Test Case 3.3: Character Lock Status Display

**Run**: Locked Character Interaction (Character Selection) - 17
**Expected Results**: Locked characters show lock icon, display "Character Locked!" notification with unlock requirements when clicked.

### Test Case 3.4: Character Stats Popup

**Run**: Character Stats Display (Character Selection) - 18
**Expected Results**: Clicking unlocked characters opens stats popup showing weapon, counter attack, health/damage/durability bonuses, and character description.

### Test Case 3.5: Character Selection Confirmation

**Run**: Select Button Character Confirmation (Character Selection) - 19
**Expected Results**: Select button saves character choice to Firebase, applies stat bonuses, shows confirmation, and returns to main menu.

### Test Case 3.6: Character Unlock Progression

**Run**: Character Unlock System (Character Selection) - 20
**Expected Results**: Characters unlock based on dungeon completion (Ragna after Dungeon 1, Magi after Dungeon 2) with proper visual feedback.

---

## 4. JOURNEY MODE - DUNGEON SELECTION

### Test Case 4.1: Dungeon Selection Display

**Run**: Dungeon Selection Screen Loading (Dungeon Selection) - 21
**Expected Results**: Dungeon selection screen displays 3 dungeons (Plains, Forest, Mountain) with completion status, accessibility indicators, and navigation options.

### Test Case 4.2: Dungeon Access Control

**Run**: Locked Dungeon Access Attempt (Dungeon Selection) - 22
**Expected Results**: Attempting to access locked dungeons shows notification with unlock requirements and prevents navigation to inaccessible content.

### Test Case 4.3: Dungeon Map Navigation

**Run**: Available Dungeon Selection (Dungeon Selection) - 23
**Expected Results**: Selecting available dungeon plays sound effect, fade transition, and navigates to corresponding dungeon map with stage selection.

---

## 5. JOURNEY MODE - DUNGEON MAPS

### Test Case 5.1: Stage Selection Display

**Run**: Dungeon Map Stage Display (Dungeon Map) - 24
**Expected Results**: Dungeon map shows 5 stages with completion status, enemy previews, difficulty indicators, and current progress visualization.

### Test Case 5.2: Stage Navigation Controls

**Run**: Stage Selection Navigation (Dungeon Map) - 25
**Expected Results**: Stage selection updates UI highlighting, shows enemy information, enables/disables fight button based on stage accessibility.

### Test Case 5.3: Energy Consumption Check

**Run**: Battle Energy Validation (Dungeon Map) - 26
**Expected Results**: Fight button checks energy (2 required), shows notification if insufficient energy with recovery information, or proceeds to battle.

### Test Case 5.4: Battle Scene Transition

**Run**: Fight Button Battle Start (Dungeon Map) - 27
**Expected Results**: Fight button click consumes energy, saves progress to Firebase, shows fade transition, and loads battle scene with correct stage data.

---

## 6. JOURNEY MODE - BATTLE SYSTEM

### Test Case 6.1: Battle Scene Initialization

**Run**: Battle Scene Loading (Battle Scene) - 28
**Expected Results**: Battle scene loads with player/enemy sprites, UI elements (health bars, stage progress), battle log, and properly positioned interface elements.

### Test Case 6.2: Stage Progress Display

**Run**: Stage Progress UI Display (Battle Scene) - 29
**Expected Results**: Stage progress bar shows current stage (1-5), player head icon positioned correctly, enemy icons with completion status, no visual overlap issues.

### Test Case 6.3: Battle Controls Interface

**Run**: Battle Action Buttons (Battle Scene) - 30
**Expected Results**: Attack, Special, Engage buttons function correctly, show appropriate enabled/disabled states, and provide audio feedback on interaction.

### Test Case 6.4: Word Challenge Triggers

**Run**: Enemy Skill Challenge Activation (Battle Scene) - 31
**Expected Results**: Enemy skills trigger word challenges (STT or Whiteboard), display challenge interface, pause battle until challenge completion.

### Test Case 6.5: Speech-to-Text Challenge

**Run**: STT Word Challenge Interface (Battle Scene) - 32
**Expected Results**: STT challenge shows word to pronounce, microphone activation, visual feedback during recording, transcript display with confirm/retry options.

### Test Case 6.6: Whiteboard Challenge Interface

**Run**: Whiteboard Drawing Challenge (Battle Scene) - 33
**Expected Results**: Whiteboard challenge displays word to write, drawing canvas, clear/undo functionality, submit button, and proper touch/mouse input handling.

### Test Case 6.7: Challenge Success Feedback

**Run**: Successful Challenge Completion (Battle Scene) - 34
**Expected Results**: Successful challenges award bonus damage, play victory sound, show damage numbers, and resume battle flow smoothly.

### Test Case 6.8: Challenge Failure Handling

**Run**: Failed Challenge Consequences (Battle Scene) - 35
**Expected Results**: Failed/cancelled challenges trigger enemy skill damage, play skill animation/SFX, show damage to player, and continue battle flow.

### Test Case 6.9: Victory Condition Display

**Run**: Battle Victory Screen (Battle Scene) - 36
**Expected Results**: Victory displays endgame screen with experience gained, progression options (continue/quit), and proper scene cleanup.

### Test Case 6.10: Defeat Condition Display

**Run**: Battle Defeat Screen (Battle Scene) - 37
**Expected Results**: Defeat displays endgame screen with retry option, return to dungeon map, and proper battle state reset.

### Test Case 6.11: Settings Access During Battle

**Run**: Battle Settings Popup (Battle Scene) - 38
**Expected Results**: Settings button opens popup with audio controls, battle-specific options (engage button visibility), and background click to close.

---

## 7. MODULE MODE - MODULE SELECTION

### Test Case 7.1: Module Selection Display

**Run**: Module Selection Screen Loading (Module Selection) - 39
**Expected Results**: Module selection displays 3 educational modules (Phonics, Flip Quiz, Read-Aloud) with progress indicators and accessibility features.

### Test Case 7.2: Phonics Module Navigation

**Run**: Phonics Module Button Click (Module Selection) - 40
**Expected Results**: Phonics button click plays sound effect, shows fade transition, and navigates to Phonics module with letter/sight word options.

### Test Case 7.3: Flip Quiz Module Navigation

**Run**: Flip Quiz Module Button Click (Module Selection) - 41
**Expected Results**: Flip Quiz button click plays sound effect, shows fade transition, and navigates to Flip Quiz module with category selection.

### Test Case 7.4: Read-Aloud Module Navigation

**Run**: Read-Aloud Module Button Click (Module Selection) - 42
**Expected Results**: Read-Aloud button click plays sound effect, shows fade transition, and navigates to Read-Aloud module with story selection.

---

## 8. MODULE MODE - PHONICS INTERACTIVE

### Test Case 8.1: Phonics Category Selection

**Run**: Phonics Category Display (Phonics Module) - 43
**Expected Results**: Phonics module shows Letters and Sight Words categories with progress indicators, completion status, and TTS preview functionality.

### Test Case 8.2: Letter Learning Interface

**Run**: Individual Letter Practice (Phonics Letters) - 44
**Expected Results**: Letter practice displays letter with tracing guide, phoneme audio playback, visual feedback for correct/incorrect tracing.

### Test Case 8.3: Letter Tracing Validation

**Run**: Letter Tracing Input Recognition (Phonics Letters) - 45
**Expected Results**: Tracing system recognizes letter formation, provides generous tolerance, shows directional guidance, and validates completion.

### Test Case 8.4: Sight Words Practice

**Run**: Sight Words Recognition (Phonics Sight Words) - 46
**Expected Results**: Sight words display with audio playback, visual recognition exercises, progress tracking, and completion celebration.

### Test Case 8.5: Phonics Progress Tracking

**Run**: Phonics Progress Calculation (Phonics Module) - 47
**Expected Results**: Progress bar updates after letter/sight word completion, shows percentage (completed items / 46 \* 100), saves to Firebase.

### Test Case 8.6: Phonics Completion Celebration

**Run**: Phonics Achievement Display (Phonics Module) - 48
**Expected Results**: Completing letters/sight words triggers celebration popup with progress feedback, encouragement message, and continue options.

---

## 9. MODULE MODE - FLIP QUIZ

### Test Case 9.1: Flip Quiz Category Selection

**Run**: Flip Quiz Category Display (Flip Quiz Module) - 49
**Expected Results**: Flip Quiz module shows Animals and Vehicles categories with preview functionality and progress indicators.

### Test Case 9.2: Card Matching Interface

**Run**: Card Flip Matching Game (Flip Quiz) - 50
**Expected Results**: Card matching displays grid of face-down cards, allows card flipping, matches pairs, tracks attempts, and provides audio feedback.

### Test Case 9.3: Card Flip Animation

**Run**: Card Flip Visual Effects (Flip Quiz) - 51
**Expected Results**: Card flips show smooth animation, reveal images/text, maintain state during matching attempts, and provide visual feedback.

### Test Case 9.4: Match Success Feedback

**Run**: Successful Card Match (Flip Quiz) - 52
**Expected Results**: Successful matches keep cards revealed, play success sound, update score, and provide positive reinforcement.

### Test Case 9.5: Match Failure Handling

**Run**: Failed Card Match (Flip Quiz) - 53
**Expected Results**: Failed matches flip cards back after brief display, provide gentle feedback, increment attempt counter, maintain encouraging tone.

### Test Case 9.6: Quiz Completion Tracking

**Run**: Flip Quiz Progress Saving (Flip Quiz) - 54
**Expected Results**: Completed sets save progress to Firebase, update module progress bar, trigger celebration, and unlock new content.

---

## 10. MODULE MODE - READ-ALOUD

### Test Case 10.1: Story Selection Interface

**Run**: Read-Aloud Story Menu (Read-Aloud Module) - 55
**Expected Results**: Story selection displays available passages, reading levels, completion status, and preview functionality.

### Test Case 10.2: Guided Reading Display

**Run**: Interactive Reading Interface (Read-Aloud Guided) - 56
**Expected Results**: Reading interface shows text with highlighting, playback controls, word-by-word navigation, and adjustable reading speed.

### Test Case 10.3: Text Highlighting System

**Run**: Reading Progress Highlighting (Read-Aloud Guided) - 57
**Expected Results**: Text highlighting follows audio playback, shows current word/sentence, provides visual reading guidance, and maintains synchronization.

### Test Case 10.4: Word Interaction Features

**Run**: Individual Word Selection (Read-Aloud Guided) - 58
**Expected Results**: Clicking words provides pronunciation, definition popup, syllable breakdown, and individual word replay functionality.

### Test Case 10.5: Reading Speed Controls

**Run**: Playback Speed Adjustment (Read-Aloud Guided) - 59
**Expected Results**: Speed controls (80-180 WPM) adjust reading pace, maintain audio clarity, update highlighting timing, and provide smooth transitions.

### Test Case 10.6: Reading Completion Tracking

**Run**: Story Completion Progress (Read-Aloud Module) - 60
**Expected Results**: Completing stories saves progress, updates module progress bar, provides completion feedback, and unlocks new content.

---

## 11. SETTINGS AND PREFERENCES

### Test Case 11.1: Settings Popup Display

**Run**: Settings Menu Access (Settings) - 61
**Expected Results**: Settings popup displays audio controls, gameplay preferences, accessibility options, and context-appropriate features.

### Test Case 11.2: Volume Control Functionality

**Run**: Audio Volume Adjustment (Settings) - 62
**Expected Results**: SFX and Music volume sliders adjust audio levels in real-time, show percentage values, and persist settings across sessions.

### Test Case 11.3: Tutorial Toggle Options

**Run**: Tutorial Preference Toggle (Settings) - 63
**Expected Results**: Tutorial toggle controls instruction display, saves preference to settings manager, and affects tutorial visibility across game sessions.

### Test Case 11.4: Settings Persistence

**Run**: Settings Data Persistence (Settings) - 64
**Expected Results**: Settings changes save automatically, persist across game sessions, sync with SettingsManager, and restore on game restart.

### Test Case 11.5: Battle Context Settings

**Run**: Battle-Specific Settings (Settings) - 65
**Expected Results**: Settings in battle context show additional options (engage button toggle), battle state controls, and context-sensitive features.

---

## 12. LEADERBOARD SYSTEM

### Test Case 12.1: Leaderboard Tab Navigation

**Run**: Leaderboard Tab Switching (Leaderboard) - 66
**Expected Results**: Tab container allows switching between Dungeon Rankings, Power Scale, and Word Masters with visual feedback and data loading.

### Test Case 12.2: Dungeon Rankings Display

**Run**: Dungeon Progress Leaderboard (Leaderboard) - 67
**Expected Results**: Dungeon rankings show players sorted by highest dungeon and stages completed, with medals, profile pictures, and progress indicators.

### Test Case 12.3: Power Scale Rankings

**Run**: Player Stats Leaderboard (Leaderboard) - 68
**Expected Results**: Power scale shows players sorted by combined stats (health + damage + durability), with level information and stat breakdowns.

### Test Case 12.4: Word Masters Rankings

**Run**: Word Challenge Leaderboard (Leaderboard) - 69
**Expected Results**: Word Masters shows players sorted by total word challenges completed (STT + Whiteboard), with individual category breakdowns.

### Test Case 12.5: Current User Highlighting

**Run**: Personal Rank Identification (Leaderboard) - 70
**Expected Results**: Current user's entry highlighted with golden tint, "\* Username (You)" format, and prominent positioning in rankings.

### Test Case 12.6: Medal System Display

**Run**: Achievement Medal Display (Leaderboard) - 71
**Expected Results**: Medal system shows bronze/silver/gold medals based on progress, with appropriate visual styling and rank indicators.

---

## 13. PROFILE AND USER MANAGEMENT

### Test Case 13.1: Profile Popup Display

**Run**: User Profile Information (Profile Popup) - 72
**Expected Results**: Profile popup shows username, level, character stats, profile picture, and account management options.

### Test Case 13.2: Profile Picture Selection

**Run**: Avatar Selection Interface (Profile Popup) - 73
**Expected Results**: Profile picture button opens avatar selection with multiple portrait options, preview functionality, and save confirmation.

### Test Case 13.3: User Statistics Display

**Run**: Player Stats Information (Profile Popup) - 74
**Expected Results**: Profile displays current level, health, damage, durability, experience points, and character-specific bonuses.

### Test Case 13.4: Logout Functionality

**Run**: Account Logout Process (Profile Popup) - 75
**Expected Results**: Logout button confirms action, clears authentication state, prevents auto-login, and returns to authentication screen.

---

## 14. ACCESSIBILITY AND USER EXPERIENCE

### Test Case 14.1: Dyslexia Font Rendering

**Run**: Dyslexia-Friendly Font Display (All Screens) - 76
**Expected Results**: All text uses OpenDyslexic font, maintains readability, proper spacing, and consistent sizing across all game screens.

### Test Case 14.2: Button Hover Feedback

**Run**: Interactive Element Feedback (All Screens) - 77
**Expected Results**: Buttons provide hover sound effects, visual feedback, label display, and clear interaction states for accessibility.

### Test Case 14.3: Fade Transition Effects

**Run**: Scene Transition Animations (All Screens) - 78
**Expected Results**: All scene changes use fade-in/fade-out transitions, consistent timing, smooth animations, and no jarring visual changes.

### Test Case 14.4: Audio Feedback System

**Run**: Sound Effect Consistency (All Screens) - 79
**Expected Results**: Consistent button click sounds, hover effects, success/failure audio feedback, and proper volume level management.

### Test Case 14.5: Visual Error Handling

**Run**: User Error Communication (All Screens) - 80
**Expected Results**: Error messages display in dyslexia-friendly format, clear language, appropriate colors, and actionable guidance.

---

## 15. OFFLINE AND ERROR HANDLING

### Test Case 15.1: Connection Loss Handling

**Run**: Network Disconnection Response (All Screens) - 81
**Expected Results**: Game gracefully handles connection loss, provides offline functionality where possible, and clear connectivity status indicators.

### Test Case 15.2: Firebase Authentication Errors

**Run**: Authentication Failure Handling (Authentication) - 82
**Expected Results**: Authentication errors display user-friendly messages, provide retry options, and maintain form data where appropriate.

### Test Case 15.3: Data Loading Error States

**Run**: Data Fetch Error Handling (All Screens) - 83
**Expected Results**: Failed data loading shows appropriate error messages, retry mechanisms, and fallback functionality where applicable.

### Test Case 15.4: Input Validation Error Display

**Run**: Form Validation Error Messages (Authentication/Settings) - 84
**Expected Results**: Input validation errors display immediately, use clear language, show field-specific guidance, and maintain accessibility standards.

---

## TESTING NOTES

- All tests should verify dyslexia-friendly design principles
- Verify consistent audio feedback across all interactions
- Ensure fade transitions work smoothly on all scene changes
- Validate proper cleanup of UI elements and memory management
- Test keyboard navigation and accessibility features
- Verify proper handling of edge cases and error conditions
- Ensure consistent visual styling and font usage throughout

## BROWSER COMPATIBILITY

Tests should be performed across:

- Chrome (latest version)
- Firefox (latest version)
- Safari (latest version)
- Edge (latest version)

## ACCESSIBILITY COMPLIANCE

- Screen reader compatibility
- Keyboard-only navigation
- Motor accessibility considerations
