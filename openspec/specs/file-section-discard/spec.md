# File Section Discard

## Purpose

TBD

## Requirements

### Requirement: File sections support discard via `k` key
When point is on a `jj-file` section, pressing `k` SHALL discard the working copy changes for that file after user confirmation.

#### Scenario: Discard a modified file
- **WHEN** point is on a `jj-file` section representing a modified file and the user presses `k`
- **THEN** Majutsu prompts for confirmation and, if confirmed, runs `jj restore <file>` to discard the changes

#### Scenario: Discard an added file
- **WHEN** point is on a `jj-file` section representing a newly added file and the user presses `k`
- **THEN** Majutsu prompts for confirmation and, if confirmed, runs `jj restore <file>` to remove the file from the working copy

#### Scenario: Discard a deleted file
- **WHEN** point is on a `jj-file` section representing a deleted file and the user presses `k`
- **THEN** Majutsu prompts for confirmation and, if confirmed, runs `jj restore <file>` to restore the file in the working copy

#### Scenario: Discard in status buffer
- **WHEN** point is on a `jj-file` section within the Working Copy Status section and the user presses `k`
- **THEN** the file's changes are discarded and the buffer is refreshed

#### Scenario: Discard in diff buffer
- **WHEN** point is on a `jj-file` section within a diff buffer and the user presses `k`
- **THEN** the file's changes are discarded and the buffer is refreshed

### Requirement: Discard requires confirmation
Discarding changes via `k` on a `jj-file` section SHALL require explicit user confirmation before executing `jj restore`.

#### Scenario: User cancels discard
- **WHEN** the user presses `k` on a `jj-file` section and then cancels the confirmation prompt
- **THEN** no `jj restore` command is executed and the working copy remains unchanged

#### Scenario: User confirms discard
- **WHEN** the user presses `k` on a `jj-file` section and confirms the prompt
- **THEN** `jj restore` is executed for that file

### Requirement: Discard refreshes the buffer
After a successful discard operation initiated from a `jj-file` section, Majutsu SHALL refresh the current buffer to reflect the updated working copy state.

#### Scenario: Buffer refreshes after discard
- **WHEN** a discard operation completes successfully
- **THEN** the current buffer is refreshed to show the updated file list
