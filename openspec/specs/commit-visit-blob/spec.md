# Commit Visit Blob

## Description

On a `jj-commit` section in the Majutsu log buffer, pressing `f` opens a prompt to select a file from that commit and visits it as a read-only blob.

## Behavior

1. The user presses `f` while point is on a `jj-commit` section.
2. The command extracts the commit's revision identifier.
3. By default, it lists only the files changed in that commit via `jj diff --name-only -r <rev>`.
4. With a prefix argument (C-u), it lists all files in the revision via `jj file list -r <rev>`.
5. The user selects a file through `completing-read`.
6. The selected file is opened via `majutsu-find-file`, which automatically activates `majutsu-blob-mode`.

## Preconditions

- Point must be on a `jj-commit` section.
- The commit must exist in the jj repository.

## Postconditions

- A new buffer `*majutsu-blob: <rev>:<path>*` is opened.
- `majutsu-blob-mode` is active in the buffer.

## Error Handling

- If point is not on a `jj-commit` section, signal a `user-error`.
- If the file list is empty, signal a `user-error`.

## Related

- `majutsu-blob-mode`
- `majutsu-find-file`
- `majutsu-file-visit-blob`
