# Purpose

TBD

## Requirements

### Requirement: File sections support inline diff expansion via TAB
When point is on a `jj-file` section in the Working Copy Status section, pressing TAB SHALL expand the section to show inline diff hunks for that file.

#### Scenario: Expand a file with changes
- **WHEN** point is on a `jj-file` section representing a modified file and the user presses TAB
- **THEN** Majutsu runs `jj diff --git <file>`, parses the output into `jj-hunk` sections as children of the `jj-file` section, and expands the section to show them

#### Scenario: Collapse an expanded file
- **WHEN** point is on an expanded `jj-file` section with visible diff hunks and the user presses TAB
- **THEN** Majutsu collapses the section, hiding the diff hunks

#### Scenario: Re-expand after collapse
- **WHEN** point is on a collapsed `jj-file` section that previously had diff hunks loaded and the user presses TAB
- **THEN** Majutsu re-expands the section without re-running `jj diff`

#### Scenario: No changes to expand
- **WHEN** point is on a `jj-file` section for a file with no diff content (e.g., a conflict marker file)
- **THEN** pressing TAB toggles visibility normally without creating children

### Requirement: Diff expansion uses standard unified diff format
Majutsu SHALL run `jj diff --git` to produce standard unified diff output when loading inline diffs.

#### Scenario: Unified diff format is parsed correctly
- **WHEN** `jj diff --git <file>` produces output with `diff --git`, `---`, `+++`, and `@@` headers
- **THEN** Majutsu correctly parses the hunks into `jj-hunk` sections with proper line ranges and faces
