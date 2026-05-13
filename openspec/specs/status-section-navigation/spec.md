# status-section-navigation

## Purpose

The Working Copy Status section in Majutsu renders `jj status` output. This capability adds structured file sections within that output, allowing users to navigate changed files as first-class magit-section elements with RET-to-open behavior.

## Requirements

### Requirement: Working Copy Status section renders changed files as structured sections
Majutsu SHALL parse the `jj status` output within the Working Copy Status section and create a `jj-file` section for each changed file listed under `Working copy changes:`.

#### Scenario: Single changed file
- **WHEN** `jj status` output contains one changed file under `Working copy changes:`
- **THEN** the Working Copy Status section contains one `jj-file` section whose value is that file's path

#### Scenario: Multiple changed files
- **WHEN** `jj status` output contains multiple changed files under `Working copy changes:`
- **THEN** each file appears as a separate `jj-file` section in the order returned by `jj status`

#### Scenario: Files with various status codes
- **WHEN** `jj status` output contains files with status codes `M`, `A`, `D`, or `?`
- **THEN** each file is rendered as a `jj-file` section regardless of its status code

### Requirement: File sections support RET navigation to workspace files
When point is on a `jj-file` section within the Working Copy Status section, pressing RET SHALL open the corresponding file in the workspace.

#### Scenario: RET on a modified file
- **WHEN** point is on a `jj-file` section representing a modified file and the user presses RET
- **THEN** Majutsu opens that file in the workspace using `find-file`

#### Scenario: RET on an added file
- **WHEN** point is on a `jj-file` section representing a newly added file and the user presses RET
- **THEN** Majutsu opens that file in the workspace using `find-file`

#### Scenario: RET on a deleted file
- **WHEN** point is on a `jj-file` section representing a deleted file and the user presses RET
- **THEN** Majutsu attempts to open the file path; if the file no longer exists in the workspace, it SHALL signal an appropriate error

### Requirement: File sections support standard section navigation
The `jj-file` sections within the Working Copy Status section SHALL support standard magit-section navigation commands.

#### Scenario: Navigate to next file with `n`
- **WHEN** point is on a `jj-file` section and the user invokes `magit-section-forward` (typically bound to `n`)
- **THEN** point moves to the next `jj-file` section or the next section of any type

#### Scenario: Navigate to previous file with `p`
- **WHEN** point is on a `jj-file` section and the user invokes `magit-section-backward` (typically bound to `p`)
- **THEN** point moves to the previous `jj-file` section or the previous section of any type

#### Scenario: Toggle section visibility
- **WHEN** point is on a `jj-file` section and the user invokes the section visibility toggle
- **THEN** the section collapses or expands according to magit-section behavior

### Requirement: Commit summary information is preserved
The Working Copy Status section SHALL continue to display commit metadata from `jj status` (such as `Working copy (@)` and `Parent commit (@-)`) as plain text.

#### Scenario: Summary lines remain visible
- **WHEN** the Working Copy Status section is rendered with structured file sections
- **THEN** the commit summary lines appear as plain text, not as `jj-file` sections

#### Scenario: No changes in working copy
- **WHEN** `jj status` reports no working copy changes
- **THEN** the Working Copy Status section displays the summary text without creating any `jj-file` sections

### Requirement: Unparseable output falls back gracefully
If `jj status` output does not match the expected format, Majutsu SHALL display the raw output without attempting to create sections.

#### Scenario: Unexpected status output format
- **WHEN** `jj status` produces output that does not contain a recognizable `Working copy changes:` section
- **THEN** the entire output is displayed as plain text, preserving the original behavior
