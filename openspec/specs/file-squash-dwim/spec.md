## ADDED Requirements

### Requirement: File sections support squash via s key
When point is on a `jj-file` section, pressing s SHALL squash the changes for that file into the parent commit after user confirmation.

#### Scenario: Squash a modified file
- **WHEN** point is on a `jj-file` section representing a modified file and the user presses s
- **THEN** Majutsu prompts for confirmation and, if confirmed, runs `jj squash <file>` to squash the file's changes

#### Scenario: Cancel squash
- **WHEN** the user presses s on a `jj-file` section and then cancels the confirmation prompt
- **THEN** no `jj squash` command is executed
