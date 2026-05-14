# File Visit Blob

## Description

On a `jj-file` section, pressing `b` visits that file as a read-only blob, bypassing any workspace-file logic.

## Behavior

1. The user presses `b` while point is on a `jj-file` section.
2. The command extracts the file path from the section value.
3. The target revision is determined by context:
   - In a `majutsu-diff-mode` buffer: use the "to" revision from `majutsu-buffer-diff-range`.
   - Otherwise (e.g., log buffer's Working Copy Changes): use `@` (working copy).
4. The file is opened via `majutsu-find-file` with the resolved revision, automatically activating `majutsu-blob-mode`.

## Preconditions

- Point must be on a `jj-file` section.

## Postconditions

- A new buffer `*majutsu-blob: <rev>:<path>*` is opened.
- `majutsu-blob-mode` is active in the buffer.

## Error Handling

- If point is not on a `jj-file` section, signal a `user-error`.

## Related

- `majutsu-blob-mode`
- `majutsu-find-file`
- `majutsu-commit-visit-blob`
