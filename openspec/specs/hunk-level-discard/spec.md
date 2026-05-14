# Purpose

TBD

## Requirements

### Requirement: Hunk sections support discard via k key
When point is on a `jj-hunk` section, pressing k SHALL discard the changes in that hunk after user confirmation.

#### Scenario: Discard a single hunk
- **WHEN** point is on a `jj-hunk` section and the user presses k
- **THEN** Majutsu prompts for confirmation and, if confirmed, applies the hunk's patch in reverse to restore those lines

#### Scenario: Discard an added hunk
- **WHEN** point is on a `jj-hunk` section containing only added lines and the user presses k
- **THEN** Majutsu removes those added lines from the working copy

#### Scenario: Discard a removed hunk
- **WHEN** point is on a `jj-hunk` section containing only removed lines and the user presses k
- **THEN** Majutsu restores those removed lines to the working copy

#### Scenario: Discard a mixed hunk
- **WHEN** point is on a `jj-hunk` section containing both added and removed lines and the user presses k
- **THEN** Majutsu reverts both additions and removals in that hunk

### Requirement: Hunk discard requires confirmation
Discarding changes via k on a `jj-hunk` section SHALL require explicit user confirmation before applying the reverse patch.

#### Scenario: User cancels hunk discard
- **WHEN** the user presses k on a `jj-hunk` section and then cancels the confirmation prompt
- **THEN** no patch is applied and the working copy remains unchanged

### Requirement: Hunk discard refreshes the buffer
After a successful hunk discard operation, Majutsu SHALL refresh the current buffer to reflect the updated working copy state.

#### Scenario: Buffer refreshes after hunk discard
- **WHEN** a hunk discard operation completes successfully
- **THEN** the current buffer is refreshed to show the updated diff
