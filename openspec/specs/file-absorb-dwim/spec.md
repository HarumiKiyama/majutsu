## ADDED Requirements

### Requirement: File sections support absorb via a key
When point is on a `jj-file` section, pressing a SHALL absorb the changes for that file into the parent commit after user confirmation.

#### Scenario: Absorb a modified file
- **WHEN** point is on a `jj-file` section representing a modified file and the user presses a
- **THEN** Majutsu prompts for confirmation and, if confirmed, runs `jj absorb <file>` to absorb the file's changes

#### Scenario: Cancel absorb
- **WHEN** the user presses a on a `jj-file` section and then cancels the confirmation prompt
- **THEN** no `jj absorb` command is executed
