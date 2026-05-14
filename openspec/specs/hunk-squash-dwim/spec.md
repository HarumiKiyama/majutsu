## ADDED Requirements

### Requirement: Hunk sections support squash via s key
When point is on a `jj-hunk` section, pressing s SHALL squash the changes in that hunk into the parent commit after user confirmation.

#### Scenario: Squash a single hunk
- **WHEN** point is on a `jj-hunk` section and the user presses s
- **THEN** Majutsu prompts for confirmation and, if confirmed, builds a patch for the hunk and applies it via `jj squash -i` to squash only that hunk

#### Scenario: Cancel hunk squash
- **WHEN** the user presses s on a `jj-hunk` section and then cancels the confirmation prompt
- **THEN** no patch is applied
