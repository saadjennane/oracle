# Oracle App — Test Plan

## 1. SETTINGS

### 1.1 Assistant Mode
- [ ] Assistant ID auto-generated at first launch
- [ ] Edit Assistant ID (tap crayon) → only lowercase, numbers, -, _
- [ ] Copy URL (tap URL) → clipboard contains https://oass.app/{id}
- [ ] Open URL in browser → shows "Waiting for session..."

### 1.2 Acrostic Word Bank
- [ ] Open config screen → FR language tab selected, 500+ words loaded
- [ ] Add language (tap +) → new empty tab created
- [ ] Remove language (long press) → confirmation dialog
- [ ] Info button (i) → shows explanation modal
- [ ] Add words (+ in AppBar) → paste multiple words, one per line
- [ ] Position 1-6 sections → show correct coverage (green/orange)
- [ ] Open position → 26 letters with count and status
- [ ] Open letter → words listed with highlighted letter at position
- [ ] Remove word → updates all positions
- [ ] Add word from letter view → word appears in correct positions

### 1.3 Bluetooth Remote
- [ ] Toggle Enable Remote ON
- [ ] Tap UP field → "Press a button..." → press remote → key registered
- [ ] Tap DOWN field → register second key
- [ ] 2 keys only → shows "2-button remote (Volume only)"
- [ ] Add LEFT + RIGHT → shows "4-button remote (Volume + ClockSwipe)"
- [ ] Clear a key (X button) → field resets

### 1.4 Free Text Assistant
- [ ] Set Redirect URL → saved
- [ ] Set Transform Prompt with {value} → saved
- [ ] Test: enter input + tap Test → OpenAI response shown
- [ ] Acrostic Mode toggle → saved

### 1.5 External APIs
- [ ] Set Inject ID → green indicator
- [ ] Set Elips ID + API Key → green indicator
- [ ] Set HighScore API Key → green indicator
- [ ] Clear a field → indicator disappears

### 1.6 Other Settings
- [ ] Haptic Feedback toggle
- [ ] Haptic Intensity selector
- [ ] Test Mode toggle
- [ ] Visual Feedback toggle
- [ ] Auto-Copy Narrative toggle
- [ ] Shortcut Name field
- [ ] OpenAI API Key field
- [ ] Reveal Theme Mode (Light/Dark/System)
- [ ] Pre-Screen toggle

---

## 2. HOME SCREEN

### 2.1 Preset Management
- [ ] "+Add Preset" → modal with 5 types (Choices, Duel, Free Will, Multiple Out, Confabulation)
- [ ] Import button (I) → paste single JSON → preset imported
- [ ] Import button (I) → paste JSON array → multiple presets imported
- [ ] Export button (E) → all presets copied as JSON array
- [ ] Assistant Free Text button → launches free text mode

### 2.2 Preset Cards
- [ ] Each preset shows name, type, color, input method icon
- [ ] Tap → plays preset
- [ ] Edit (pencil) → opens preset builder
- [ ] Delete → confirmation dialog
- [ ] Export (per preset) → copies single JSON

---

## 3. PRESET BUILDER — CHOICES

### 3.1 Basic Config
- [ ] Name field required
- [ ] Language selector (FR/EN)
- [ ] Options 2-6 with labels
- [ ] Rounds 1-5
- [ ] Input mode: Preprogrammed / Two Inputs

### 3.2 Stealth Input
- [ ] All methods shown (Assistant, Volume, Tap, Audio, ClockSwipe hidden)
- [ ] Volume selected → volume help panel shown
- [ ] Tap selected → layout options (2: top/bottom or left/right, 4: corners or stripes)
- [ ] Audio selected → start/stop sentence fields

### 3.3 API Variables
- [ ] Section visible only if API configured in settings
- [ ] Toggle Inject ON → success/fallback fields + variable chips
- [ ] Toggle Elips ON → success/fallback fields + chips ({elips_artist}, {elips_song}, etc.)
- [ ] Toggle HighScore ON → chips + 3 conditional fields (< 7, 7-20, > 20)
- [ ] Transform prompt field + test button (Inject, Elips only)

### 3.4 Appellation
- [ ] Narrator Voice: First Person / Third Person
- [ ] Address Mode: You / By Name
- [ ] Custom names fields

### 3.5 Narrative Banks
- [ ] Custom template editor with variable chips
- [ ] Chips: per-round choices, win/loss/tie variables
- [ ] API marker chips: ((INJECT)), ((ELIPS)), ((HIGHSCORE)), ((ACROSTICHE_INJECT)), ((ACROSTICHE_ELIPS))
- [ ] Template preview with sample data

---

## 4. PRESET BUILDER — DUEL

### 4.1 Duel Mode
- [ ] Fixed Rounds: 1-5 rounds
- [ ] First To: target score 1-5

### 4.2 Participants
- [ ] S vs P (default): standard performer vs spectator
- [ ] S vs S: hides preprogrammed option, shows name fields for S1/S2

### 4.3 Fixed Rounds Specific
- [ ] Input mode: Preprogrammed / Two Inputs
- [ ] Performer sequence editor
- [ ] Bank editor with Fixed Rounds variables only (choixS, choixP, winChoice, etc.)
- [ ] round1OutcomeText chips
- [ ] NO First To variables (nbRounds, spectatorSequence, HowManyTies, etc.)

### 4.4 First To Specific
- [ ] Input mode: Preprogrammed / Two Inputs (hidden if S vs S)
- [ ] Performer sequence (min length = targetScore*2 - 1)
- [ ] Tie strategy: Repeat / Cycle
- [ ] Bank editor with First To variables (nbRounds, nbRounds+1, nbTies, nbTies+1, etc.)
- [ ] Conditional variables chips: tieTextOrNoTieText, whoScoresFirst, remontadaText, etc.

---

## 5. PRESET BUILDER — FREE WILL

- [ ] 3 objects (customizable labels)
- [ ] Input mode: By Action / By Object
- [ ] Action order configurable
- [ ] Object order configurable
- [ ] Change of mind toggle + custom texts
- [ ] Tap orientation: Horizontal / Vertical
- [ ] Custom bank templates (6 permutations)

---

## 6. PRESET BUILDER — MULTIPLE OUT

### 6.1 Input Methods
- [ ] Volume (max 6 texts)
- [ ] Clock Swipe (max 16 texts)
- [ ] Audio (max 12 texts) → keyword fields per text + start/stop sentences

### 6.2 Text Configuration
- [ ] Add/Remove texts (min 1)
- [ ] Title field (optional) per text
- [ ] Keyword field (audio only) per text
- [ ] Gesture hint shown per text ([↑ →] for clock swipe, [UP x1] for volume)
- [ ] API marker chips: ((INJECT)), ((ELIPS)), ((HIGHSCORE)), ((ACROSTICHE_INJECT)), ((ACROSTICHE_ELIPS))

---

## 7. CONFABULATION

### 7.1 Editor
- [ ] Add slots (1-10) with labels
- [ ] Options per slot (2-16)
- [ ] Text template with {{slot:id}} tokens
- [ ] Input methods: Volume, Tap, Audio, Clock Swipe
- [ ] Tap/Volume greyed out when a slot has > 6 options
- [ ] Audio start/stop sentences

### 7.2 Run
- [ ] Slot-by-slot input
- [ ] Volume: controller updates per slot
- [ ] Clock Swipe: swipe detection on black screen
- [ ] Audio: keyword detection per slot options
- [ ] Tap: visible buttons
- [ ] Complete → shows result text with filled slots

---

## 8. PERFORMANCE — STEALTH INPUT

### 8.1 Volume Input
- [ ] Black screen → UP/DOWN multi-taps → correct option selected
- [ ] Undo: 3 rapid presses same direction
- [ ] Reset: 2 consecutive undos
- [ ] Haptic feedback per selection
- [ ] Test mode: mapping display, commit history, round info

### 8.2 Tap Input
- [ ] Black screen with invisible zones
- [ ] 2 options: top/bottom or left/right
- [ ] 3 options: 3 horizontal bands
- [ ] 4 options: corners or stripes
- [ ] 5 options: 2x3 grid with one disabled
- [ ] 6 options: 2x3 grid

### 8.3 Clock Swipe
- [ ] 2 swipes → correct position (1-16)
- [ ] Mapping: ↑→=1, →↑=2, →→=3, ..., ↑↑=12, ↑↓=13, →←=14, ↓↑=15, ←→=16
- [ ] Timeout 1.5s if no 2nd swipe → reset
- [ ] Undo: 3 rapid swipes same direction

### 8.4 Audio Input
- [ ] Speech recognition starts
- [ ] Start sentence detection (if configured)
- [ ] Keyword matching against options
- [ ] Stop sentence detection
- [ ] Volume buttons toggle listening
- [ ] Visual pixel indicators (if Visual Feedback enabled)

### 8.5 Assistant Mode
- [ ] Firebase session pushed on play
- [ ] Webapp shows preset options
- [ ] Assistant clicks → app receives choice
- [ ] Round advances → Firebase updated → webapp updates
- [ ] All rounds done → navigates to preview/chain

### 8.6 Bluetooth Remote
- [ ] Mapped keys trigger volume UP/DOWN in volume mode
- [ ] Mapped keys trigger swipe directions in clock swipe mode
- [ ] Works on stealth volume screen
- [ ] Works on multiple out screen

---

## 9. PERFORMANCE FLOW

### 9.1 Pre-Screen
- [ ] Fake Notes screen (if pre-screen enabled)
- [ ] Transition to stealth input (volume down or gesture)

### 9.2 Reveal
- [ ] Narration preview screen shows generated text
- [ ] Copy to clipboard works
- [ ] Reveal in note transitions to fake note display
- [ ] Theme respects Light/Dark/System setting
- [ ] Fake timestamp shown (if enabled)

---

## 10. ROUTINES

### 10.1 Routine Builder
- [ ] "Add Routine" button visible only if ≥2 presets exist
- [ ] Create routine: name + select presets
- [ ] Input order: drag & drop to reorder
- [ ] Output order: drag & drop to reorder (can differ from input order)
- [ ] Save routine → appears on home screen
- [ ] Edit routine → opens builder with existing data
- [ ] Delete routine → confirmation dialog

### 10.2 Routine Playback
- [ ] Play routine → starts first preset in input order
- [ ] After each preset input → chains to next in input order
- [ ] Final text = narratives concatenated in OUTPUT order with \n\n
- [ ] Auto-copy + shortcut only at chain end
- [ ] Chain progress pixels on stealth screens (dim = done, bright = current, hidden = not done)
- [ ] 3+ presets in routine works
- [ ] Mixed types in routine (Choices → Duel → Multiple Out)
- [ ] Assistant mode: webapp shows chain progress bar (Which Hand > **Duel** > Couleurs)

### 10.3 Routine Integrity
- [ ] Delete a preset used in a routine → routine auto-updates (or deleted if < 2 presets left)
- [ ] Routine with missing preset → error shown on play
- [ ] Output order ≠ Input order → text assembled in correct output order

---

## 11. API VARIABLES

### 11.1 Inject
- [ ] ((INJECT)) replaced by success text with {inject_text} resolved
- [ ] API failure → fallback text used
- [ ] Empty fallback → block removed cleanly
- [ ] Transform prompt: value transformed by GPT-4o-mini before injection
- [ ] ((ACROSTICHE_INJECT)) → generates word column from inject value

### 11.2 Elips
- [ ] ((ELIPS)) replaced by success text with {elips_artist}, {elips_song}, {elips_outputWord}
- [ ] Transform prompt → result in {elips_transformed}
- [ ] ((ACROSTICHE_ELIPS_ARTIST)) → generates acrostic from artist name
- [ ] ((ACROSTICHE_ELIPS_SONG)) → generates acrostic from song name
- [ ] ((ACROSTICHE_ELIPS_WORD)) → generates acrostic from output word

### 11.3 HighScore
- [ ] ((HIGHSCORE)) with {highscore_score}, {highscore_score+1}, {highscore_ranking}
- [ ] {HowManyPoints} → conditional text based on score (< 7 / 7-20 / > 20)

### 11.4 Free Text Variable
- [ ] {free_text} in preset text → replaced by raw free text value from assistant
- [ ] ((ACROSTICHE_FREE)) in preset text → replaced by acrostic of free text word

---

## 12. ACROSTIC

- [ ] ((ACROSTICHE_INJECT)) in text → generates acrostic from inject value
- [ ] ((ACROSTICHE_ELIPS_ARTIST)) in text → generates acrostic from artist
- [ ] ((ACROSTICHE_ELIPS_SONG)) in text → generates acrostic from song
- [ ] ((ACROSTICHE_ELIPS_WORD)) in text → generates acrostic from output word
- [ ] ((ACROSTICHE_FREE)) in text → generates acrostic from assistant free text
- [ ] Free Text mode + Acrostic enabled in settings → received word converted to word column
- [ ] Result: one word per line, Nth letter spells secret word
- [ ] Different result each time (random selection)
- [ ] No duplicate words in a column
- [ ] Position variable (1-6) chosen automatically

---

## 13. ASSISTANT FREE TEXT

### 13.1 Standalone Free Text Mode
- [ ] Tap "Assistant Free Text" on home screen
- [ ] Firebase receives free_text state
- [ ] Webapp shows text input + Send button
- [ ] Type text + Send → app receives it
- [ ] Transform prompt applied (if configured)
- [ ] Acrostic generated (if Acrostic Mode enabled in settings)
- [ ] Text copied to clipboard
- [ ] Shortcut launched (if configured)
- [ ] Webapp redirects (if redirect URL set)

### 13.2 Inline Free Text (within preset)
- [ ] Preset text contains {free_text} or ((ACROSTICHE_FREE))
- [ ] Assistant webapp shows option buttons + free text field below (separator line)
- [ ] Assistant sends free text → app stores value
- [ ] Assistant clicks options for rounds as usual
- [ ] On completion: {free_text} replaced by raw text, ((ACROSTICHE_FREE)) replaced by acrostic
- [ ] Works with preset chaining

---

## 14. DUEL TIE HANDLING (First To)

### 14.1 Repeat Strategy
- [ ] Tie → performer replays same preprogrammed choice
- [ ] Point scored → advances to next in sequence
- [ ] Multiple consecutive ties → same choice repeated

### 14.2 Cycle Strategy
- [ ] Tie on Pierre → next plays Feuille
- [ ] Tie on Feuille → next plays Ciseaux
- [ ] Tie on Ciseaux → next plays Pierre
- [ ] Point scored → resets cycle, advances sequence
- [ ] Double tie → cycles twice

---

## 15. EXPORT / IMPORT

- [ ] Export single preset → valid JSON in clipboard
- [ ] Export all → JSON array in clipboard
- [ ] Import single JSON → preset created with new ID
- [ ] Import JSON array → all presets created
- [ ] Smart quotes sanitized on import
- [ ] Invalid JSON → error message shown
- [ ] Existing preset edited → re-export reflects changes

---

## 16. NARRATIVE VARIABLES

### 16.1 Fixed Rounds Only
- [ ] {choixS1}, {choixP1} → per-round choices
- [ ] {winChoiceS1}, {winChoiceP1} → win/loss choices
- [ ] {whenWinS1}, {whenWinP1} → round name of win
- [ ] {tiePosition1}, {tieChoice1} → tie info
- [ ] {round1OutcomeText} → per-round conditional text
- [ ] {nameS1}, {nameS2} → S vs S names

### 16.2 First To Only
- [ ] {nbRounds}, {nbRounds+1} → round count
- [ ] {nbTies}, {nbTies+1} → tie count
- [ ] {spectatorSequence} → full sequence
- [ ] {HowManyTies} → conditional text
- [ ] {tieTextOrNoTieText}, {whoScoresFirst}, {remontadaText}
- [ ] {earlyRoundsText}, {lastRoundOutcomeText}
- [ ] {1stNoTieSpectator}, {lastWinSpectator}, {1stTie}, {lastTie}
- [ ] NOT applied in Fixed Rounds mode

---

## 17. OUTPUT MODES (IMAGE)

### 17.1 Output Mode Selector
- [ ] Notes / Image / Both buttons in preset builder
- [ ] Notes greyed out if not all texts filled
- [ ] Image greyed out if not all images uploaded
- [ ] Both greyed out if either condition missing

### 17.2 Image Upload
- [ ] Image upload button per bank entry (Choices: HMH patterns, Duel: score buckets, Free Will: permutations, Multiple Out: per text)
- [ ] Thumbnail preview when image uploaded
- [ ] Remove/Replace image
- [ ] Images persist with preset (saved locally)

### 17.3 Image Output Flow
- [ ] Image mode: image saved to gallery → black screen with green pixel indicator
- [ ] Image mode + "Open Photos": image saved → Photos app opens automatically
- [ ] Both mode: image saved to gallery → text copied → shortcut launches
- [ ] Notes mode: unchanged (text preview + copy + shortcut)
- [ ] Timestamp offset: image backdated by configured minutes

### 17.4 After Save Options
- [ ] Black Screen: stay on black screen after save (stealth)
- [ ] Open Photos: automatically open Photos app to show saved image
