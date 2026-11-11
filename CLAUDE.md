## Commands

- run: `flutter run`
- test: `flutter test --reporter=compact`
- test-changed: `scripts/test_changed.sh`
- lint: `flutter analyze`
- coverage: `flutter test --reporter=compact --coverage`
- coverage-gaps: `coverage-gaps coverage/lcov.info`
- deploy: `git -C ~/src/habit_stack pull --ff-only && ~/.claude/scripts/phone_deploy.sh ~/src/habit_stack --release`
