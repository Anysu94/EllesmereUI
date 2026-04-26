# Confirmed Bugs From Current Test Work

This file tracks product bugs that were actively confirmed while writing or
running the current test suite expansion. It is not a changelog and it is not
meant to list every historical flaky or failing test forever.

## Quest Tracker

### Disabled mouseover tracker still registers for shared mouseover fades

- Area: `EllesmereUIQuestTracker/EllesmereUIQuestTracker_Visibility.lua`
- Confirming spec: `Testing/Tests/Modules/QuestTracker/visibility_spec.lua`
- Status: confirmed by an intentionally red test

Observed behavior:

- A tracker whose effective visibility is already `false` can still return
  `true` from the mouseover registration predicate when its saved config keeps
  `visibility = "mouseover"`.
- This means a tracker that should stay hidden can remain eligible for shared
  mouseover fade-ins.

Likely cause:

- `InitVisibility()` registers a mouseover predicate that checks the saved mode
  string but does not also gate on the effective visibility result.

Repro path used in tests:

1. Configure the tracker with `enabled = false` and `visibility = "mouseover"`.
2. Make `EllesmereUI.EvalVisibility(cfg)` return `false`.
3. Initialize visibility.
4. Observe that the mouseover predicate still returns `true`.

---

### Multi-quest gossip state blocks later single-quest auto-accept on the same NPC

- Area: `EllesmereUIQuestTracker/EllesmereUIQuestTracker_QoL.lua`
- Confirming spec: `Testing/Tests/Modules/QuestTracker/qol_spec.lua`
- Status: confirmed by an intentionally red test

Observed behavior:

- If an NPC first offers multiple quests and `autoAcceptPreventMulti` is
  enabled, later single available quests from that same NPC are still not
  auto-accepted after the earlier manual choice has been resolved.

Likely cause:

- `autoPreventNPCGUID` is set during the multi-quest case and is not cleared on
  the later single-quest case.

Repro path used in tests:

1. Open gossip on an NPC with two available quests.
2. Confirm that auto-accept is intentionally suppressed.
3. Re-open gossip on the same NPC when only one quest is now available.
4. Observe that the quest is still not auto-accepted.

---

### Missing NPC GUID can permanently block later single-quest auto-accepts

- Area: `EllesmereUIQuestTracker/EllesmereUIQuestTracker_QoL.lua`
- Confirming spec: `Testing/Tests/Modules/QuestTracker/qol_spec.lua`
- Status: confirmed by an intentionally red test

Observed behavior:

- When `UnitGUID("npc")` returns `nil` during a multi-quest gossip event, the
  same guard path can continue blocking later single-quest auto-accept logic.

Likely cause:

- The prevent-multi state uses the NPC GUID as its identity key, but the code
  path does not recover cleanly when that GUID is unavailable.

Repro path used in tests:

1. Open gossip where two quests are available and `UnitGUID("npc")` is `nil`.
2. Confirm that auto-accept is suppressed.
3. Re-open gossip when only one quest is available.
4. Observe that auto-accept is still blocked.

## Action Bars

### Legacy mouseover normalization drops the saved visible alpha

- Area: `EllesmereUIActionBars/EllesmereUIActionBars.lua`
- Confirming spec: `Testing/Tests/Modules/ActionBars/visibility_compat_spec.lua`
- Status: confirmed by an intentionally red test when run in isolation

Observed behavior:

- Legacy settings with `mouseoverEnabled = true` and a non-zero
  `mouseoverAlpha` lose the previous visible alpha during normalization.

Likely cause:

- `VisibilityCompat.ApplyMode(..., "mouseover")` only snapshots
  `_savedBarAlpha` when `wasMouseover` was previously `false`.

---

### Copying legacy mouseover settings can zero the destination visible alpha

- Area: `EllesmereUIActionBars/EllesmereUIActionBars.lua`
- Confirming spec: `Testing/Tests/Modules/ActionBars/visibility_compat_spec.lua`
- Status: confirmed by an intentionally red test when run in isolation

Observed behavior:

- Copying legacy mouseover settings can leave the destination with a saved
  alpha of `0` instead of the source bar's real visible alpha.

Likely cause:

- The source settings are normalized in place before the copy reads the old
  visible alpha, so the original value is already lost.

## Cooldown Manager

### Bar glow fallback uses a different default bar shape than persisted storage

- Area: `EllesmereUICooldownManager/EllesmereUICdmBarGlows.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/bar_glows_spec.lua`
- Status: confirmed by an existing red test

Observed behavior:

- Lazy-created persisted glow data defaults `selectedBar` to `"cooldowns"`, but
  the no-DB / no-spec fallback path returns `selectedBar = 1`.
- This means read-only fallback behavior does not match the shape later stored
  in SavedVariables.

Likely cause:

- `GetBarGlows()` uses numeric fallback returns for the early exits but seeds a
  string key when persistence is available.

---

### Adding a tracked buff bar resets threshold fields to the wrong values

- Area: `EllesmereUICooldownManager/EllesmereUICdmBuffBars.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/buff_bars_spec.lua`
- Status: confirmed by an existing red test

Observed behavior:

- When a new tracked buff bar is cloned from the previous one, spell-specific
  threshold fields are reset to `stackThresholdEnabled = true` and
  `stackThreshold = true` instead of the default disabled / numeric settings.

Likely cause:

- `AddTrackedBuffBar()` marks `stackThresholdEnabled` and `stackThreshold` as
  reset keys, but the reset logic pulls from `TBB_DEFAULT_BAR`; the test shows
  the resulting behavior does not match the expected default shape used by the
  rest of the bar model.

Note:

- The coded defaults in `TBB_DEFAULT_BAR` are currently `false` and `5`, so
  either the clone/reset logic or the product expectation has drifted. The red
  test currently treats this as a product bug.

---

### Switching cdStateEffect away from hidden modes can leave icons permanently hidden

- Area: `EllesmereUICooldownManager/EllesmereUICdmHooks.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/hooks_resolution_spec.lua`
- Status: confirmed by an intentionally red test

Observed behavior:

- An icon hidden via `hiddenOnCD` or `hiddenReady` can stay at alpha `0` after
  the spell setting is switched to a non-hide effect such as `pixelGlowReady`.
- The new effect logic may start the glow, but the icon opacity is not restored
  to the bar's configured visible alpha.

Likely cause:

- The `SetDesaturated` cd-state hook clears `_cdStateHidden` when no hide mode
  is active, but it does not restore `frame:SetAlpha(barOpacity)` on that
  transition path.

Repro path used in tests:

1. Apply `hiddenOnCD` to a spell and simulate an active non-GCD cooldown.
2. Trigger the desaturation hook and confirm the icon alpha becomes `0`.
3. Switch the same spell to `pixelGlowReady` and simulate the cooldown ending.
4. Trigger the desaturation hook again.
5. Observe that the icon remains at alpha `0` instead of returning to the
   configured bar opacity.

---

### Replacing a tracked spell does not collapse duplicate variant-family entries

- Area: `EllesmereUICooldownManager/EllesmereUICdmSpellPicker.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/spell_picker_spec.lua`
- Status: confirmed by an existing red test

Observed behavior:

- Replacing an existing tracked spell with another spell from the same variant
  family can leave both family members in `assignedSpells` instead of collapsing
  the bar back to a single canonical entry.

Likely cause:

- `ReplaceTrackedSpell()` only removes an exact `existing == newID` duplicate.
  It does not use the variant-aware duplicate logic that other add/remove paths
  use through `FindVariantIndex()` and related helpers.

---

### Custom buff preset adds only store the primary spell ID

- Area: `EllesmereUICooldownManager/EllesmereUICdmSpellPicker.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/spell_picker_spec.lua`
- Status: confirmed by an existing red test

Observed behavior:

- Adding a preset to a `custom_buff` bar stores only `preset.spellIDs[1]` plus a
  single duration entry, even though the aura-bar system expects every preset
  member to be stored independently so each aura variant can activate.

Likely cause:

- The `isCustomBuff` branch in `AddPresetToBar()` still inserts only the first
  spell ID instead of expanding the full preset spell list.

---

### Custom buff preset duplicate detection is not atomic across all preset members

- Area: `EllesmereUICooldownManager/EllesmereUICdmSpellPicker.lua`
- Confirming spec: `Testing/Tests/Modules/CooldownManager/spell_picker_spec.lua`
- Status: confirmed by an existing red test

Observed behavior:

- On `custom_buff` bars, adding a preset succeeds unless the exact primary ID is
  already present. If another member of the preset already exists, the add is
  not rejected atomically.

Likely cause:

- The duplicate guard in the `isCustomBuff` branch checks only the primary ID
  instead of scanning all preset members before mutating bar state.

## Resource Bars

### Narrow pip bars can generate inverted slot geometry

- Area: `EllesmereUIResourceBars/EllesmereUIResourceBars.lua`
- Confirming spec: `Testing/Tests/Modules/ResourceBars/resource_bars_spec.lua`
- Status: confirmed by an intentionally red test

Observed behavior:

- `CalcPipGeometry()` can emit pip slots whose right edge is left of their
  left edge once the configured total bar width is smaller than the cumulative
  inter-pip spacing.
- The focused test reproduced this with `totalW = 5`, `numPips = 6`, and
  `pipSp = 2`, where pip 2 was emitted as `x0 = 2`, `x1 = 1`.

Likely cause:

- The helper subtracts total gap pixels from total bar width without clamping
  the remaining per-pip width to a non-negative value.

Repro path used in tests:

1. Load the `ResourceBars` module and export `_ERB_CalcPipGeometry`.
2. Call `_ERB_CalcPipGeometry(5, 6, 2, frame)` with a unit effective scale.
3. Observe that later pip slots have `x1 < x0`.

## Untriaged Failures

None currently listed in this file.