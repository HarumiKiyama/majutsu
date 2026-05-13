# transient-fileset-arguments

## Purpose

Commands that combine transient options with path/fileset limits produce `jj` argv in an order that preserves option parsing. In `jj`, `--` ends option parsing for the command, so any later value is treated as a fileset. Majutsu must normalize transient arguments so that all command options appear before `--` and all path/fileset values appear after it, regardless of the order in which the user selected them in the transient UI.

## Requirements

### Requirement: Canonical fileset delimiter ordering
Majutsu commands that combine transient options with path/fileset limits SHALL pass all command options before the `--` delimiter and all path/fileset values after the delimiter when invoking `jj`.

#### Scenario: Option selected after a path limit
- **WHEN** a command transient returns a path/fileset delimiter before a later command option
- **THEN** Majutsu invokes `jj` with that command option before `--` and the path/fileset values after `--`

#### Scenario: Multiple path limits are preserved
- **WHEN** a command transient contains multiple selected path/fileset values
- **THEN** Majutsu preserves their order after a single `--` delimiter

### Requirement: Structured transient values drive normalization
Majutsu MUST identify path/fileset limits from the structured `transient-files` value whose key is `--`, rather than by treating every string that starts with `--` as an option.

#### Scenario: Path resembles an option
- **WHEN** a selected path/fileset value begins with `--`
- **THEN** Majutsu keeps that value after the `--` delimiter as a path/fileset value

### Requirement: Affected execution commands are normalized
The `majutsu-absorb`, `majutsu-restore`, `majutsu-squash`, and `majutsu-split` execution paths SHALL normalize transient path/fileset arguments before invoking `jj` or a patch-based helper that will invoke `jj`.

#### Scenario: Absorb normalizes destination option
- **WHEN** `majutsu-absorb` receives a path limit followed by a destination option
- **THEN** it invokes `jj absorb` with the destination option before `--`

#### Scenario: Restore normalizes revision options
- **WHEN** `majutsu-restore` receives a path limit followed by revision options
- **THEN** it invokes `jj restore` with the revision options before `--`

#### Scenario: Squash normalizes selection options
- **WHEN** `majutsu-squash` receives a path limit followed by selection options
- **THEN** it invokes `jj squash` with the selection options before `--`

#### Scenario: Split normalizes placement options
- **WHEN** `majutsu-split` receives a path limit followed by placement options
- **THEN** it invokes `jj split` with the placement options before `--`

#### Scenario: Patch-based execution receives normalized args
- **WHEN** restore, squash, or split uses a selected patch flow
- **THEN** the patch-based helper receives normalized command arguments with options before `--`
