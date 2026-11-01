# Fit every main screen on one phone screen: remaining work

Habits and Streaks screens are converted to `FitGrid` tiles (2-column, paged
horizontally) with a Pixel 6a widget test (`test/screens/fit_to_screen_test.dart`).

## what
Two items are left.
- Long-press sheet has only "Archive habit". An "Edit habit" action needs a
  decision: the app has no edit flow or storage update today, and this task
  said not to change storage code. Decide: edit-in-place via `HabitFormScreen`
  (new edit mode + `HabitStorageService.updateHabit`), or no edit.
- Phone check of the two screens (release build, one screenshot each).

## done
`flutter test --reporter=compact` exits 0, and the Edit decision is made and
implemented or dropped here, and screenshots of both screens were looked at.

## verify
Pixel 6a 23181JEGR08034: `~/.claude/scripts/phone_deploy.sh /home/kuhy/src/habit_stack`,
then a screenshot per screen from `~/.claude/scripts/phone_vd.sh`. Needs kuhy.

## read first
- ~/.claude/skills/build-mobile-app/SKILL.md (R7)

REMOVE ME AFTER FINISH
