;;; majutsu-restore-test.el --- Tests for restore transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for restore argument parsing and command assembly.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'majutsu-restore)

(ert-deftest majutsu-restore-execute-normalizes-fileset-args ()
  "Move revision options before fileset delimiter for direct restore."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-run-jj)
               (lambda (&rest args)
                 (setq called args)
                 0))
              ((symbol-function 'message)
               (lambda (&rest _) nil)))
      (majutsu-restore-execute '(("--" "src/a.el") "--from=main" "--to=@"))
      (should (equal called
                     '("restore" "--from=main" "--to=@" "--" "src/a.el"))))))

(ert-deftest majutsu-restore-execute-normalizes-patch-flow-args ()
  "Patch-based restore should receive normalized args."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) "patch"))
              ((symbol-function 'majutsu-interactive-run-with-patch)
               (lambda (&rest args)
                 (setq called args)))
              ((symbol-function 'majutsu-interactive-clear)
               (lambda () nil)))
      (majutsu-restore-execute '(("--" "src/a.el") "--from=main" "--to=@"))
      (should (equal called
                     '("restore" ("--from=main" "--to=@" "--" "src/a.el") "patch"))))))

(ert-deftest majutsu-hunk-discard/restores-file-when-no-hunks-remain ()
  "Hunk discard should restore the file directly when no hunks remain."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let* ((header (string-join
                    '("diff --git a/src/a.el b/src/a.el"
                      "--- a/src/a.el"
                      "+++ b/src/a.el"
                      "")
                    "\n"))
           called
           hunk-section)
      (magit-insert-section (jj-file "src/a.el" nil :header header)
        (magit-insert-heading "M src/a.el")
        (magit-insert-section (jj-hunk '("src/a.el" 1) nil)
          (magit-insert-heading "@@ -1 +1 @@")
          (setq hunk-section magit-insert-section--current)
          (insert "-old\n+new\n")))
      (goto-char (oref hunk-section start))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-hunk-discard))
      (should (equal called '("restore" "file:\"src/a.el\""))))))

(ert-deftest majutsu-hunk-discard/preserves-unselected-hunks ()
  "Hunk discard should patch restore with the file's remaining hunks."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let* ((header (string-join
                    '("diff --git a/src/a.el b/src/a.el"
                      "--- a/src/a.el"
                      "+++ b/src/a.el"
                      "")
                    "\n"))
           called
           first-hunk)
      (magit-insert-section (jj-file "src/a.el" nil :header header)
        (magit-insert-heading "M src/a.el")
        (magit-insert-section (jj-hunk '("src/a.el" 1) nil)
          (magit-insert-heading "@@ -1 +1 @@")
          (setq first-hunk magit-insert-section--current)
          (insert "-old\n+new\n"))
        (magit-insert-section (jj-hunk '("src/a.el" 5) nil)
          (magit-insert-heading "@@ -5 +5 @@")
          (insert "-keep-old\n+keep-new\n")))
      (goto-char (oref first-hunk start))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-interactive-run-with-patch)
                 (lambda (&rest args)
                   (setq called args))))
        (majutsu-hunk-discard))
      (should (equal (car called) "restore"))
      (should (equal (cadr called) '("file:\"src/a.el\"")))
      (should-not (string-match-p "^+new$" (nth 2 called)))
      (should (string-match-p "^-keep-old$" (nth 2 called)))
      (should (string-match-p "^+keep-new$" (nth 2 called)))
      (should-not (nth 3 called)))))

(ert-deftest majutsu-hunk-discard/uses-operation-fileset ()
  "Hunk discard should honor a file section's operation fileset."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let* ((header (string-join
                    '("diff --git a/old.txt b/new.txt"
                      "copy from old.txt"
                      "copy to new.txt"
                      "--- a/old.txt"
                      "+++ b/new.txt"
                      "")
                    "\n"))
           called
           hunk-section)
      (magit-insert-section (jj-file "new.txt" nil
                                     :header header
                                     :operation-fileset
                                     "file:\"old.txt\"|file:\"new.txt\"")
        (magit-insert-heading "C {old.txt => new.txt}")
        (magit-insert-section (jj-hunk '("new.txt" 1) nil)
          (magit-insert-heading "@@ -1 +1 @@")
          (setq hunk-section magit-insert-section--current)
          (insert "-old\n+new\n")))
      (goto-char (oref hunk-section start))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-hunk-discard))
      (should (equal called
                     '("restore" "file:\"old.txt\"|file:\"new.txt\""))))))

(ert-deftest majutsu-hunk-discard/targets-log-change ()
  "Hunk discard in an expanded change should restore that change."
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t)
          called hunk-section)
      (magit-insert-section (jj-commit "change-a")
        (magit-insert-heading "change-a")
        (magit-insert-section (changed-files "change-a")
          (magit-insert-heading "Changed files")
          (magit-insert-section (jj-file "src/a.el" nil
                                         :header "diff --git a/src/a.el b/src/a.el\n")
            (magit-insert-heading "M src/a.el")
            (magit-insert-section (jj-hunk '("src/a.el" 1) nil)
              (magit-insert-heading "@@ -1 +1 @@")
              (setq hunk-section magit-insert-section--current)
              (insert "-old\n+new\n")))))
      (goto-char (oref hunk-section start))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-restore--hunk-discard-patch)
                 (lambda (&rest _) nil))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-hunk-discard))
      (should (equal called
                     '("restore" "--changes-in=change-a" "file:\"src/a.el\""))))))

(ert-deftest majutsu-restore-file-at-point/uses-operation-fileset ()
  "File-level restore should honor a section-specific operation fileset."
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t)
          called)
      (magit-insert-section (jj-file "new.txt" nil
                                     :operation-fileset "file:\"old.txt\"|file:\"new.txt\"")
        (magit-insert-heading "R {old.txt => new.txt}"))
      (goto-char (point-min))
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-restore-file-at-point))
      (should (equal called
                     '("restore" "file:\"old.txt\"|file:\"new.txt\""))))))

(ert-deftest majutsu-restore-file-at-point/targets-log-change ()
  "File discard in an expanded change should restore that change."
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t)
          called)
      (magit-insert-section (jj-commit "change-a")
        (magit-insert-heading "change-a")
        (magit-insert-section (changed-files "change-a")
          (magit-insert-heading "Changed files")
          (magit-insert-section (jj-file "src/a.el")
            (magit-insert-heading "M src/a.el"))))
      (goto-char (point-min))
      (search-forward "M src/a.el")
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-restore-file-at-point))
      (should (equal called
                     '("restore" "--changes-in=change-a" "file:\"src/a.el\""))))))

(ert-deftest majutsu-restore-file-at-point/rejects-mixed-changes ()
  "A region spanning changesets must not restore against one revision."
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t)
          first last)
      (magit-insert-section (lograph)
        (dolist (rev '("change-a" "change-b"))
          (magit-insert-section (jj-commit rev)
            (magit-insert-heading rev)
            (magit-insert-section (changed-files rev)
              (magit-insert-heading "Changed files")
              (magit-insert-section (jj-file (concat rev ".el"))
                (magit-insert-heading (concat "M " rev ".el")))))))
      (goto-char (point-min))
      (search-forward "M change-a.el")
      (setq first (line-beginning-position))
      (search-forward "M change-b.el")
      (setq last (line-end-position))
      (setq-local transient-mark-mode t)
      (goto-char last)
      (push-mark first t t)
      (should-error (majutsu-restore-file-at-point) :type 'user-error))))

(ert-deftest majutsu-restore-file-at-point/uses-region-file-sections ()
  "File-level restore should discard all jj-file sections in the active region."
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t)
          section-a section-b
          pos-a pos-b
          called)
      (magit-insert-section (status)
        (magit-insert-section (jj-file "a.el")
          (setq section-a (magit-current-section))
          (magit-insert-heading "M a.el"))
        (magit-insert-section (jj-file "b.el" nil
                                       :operation-fileset "file:\"old.el\"|file:\"b.el\"")
          (setq section-b (magit-current-section))
          (magit-insert-heading "R {old.el => b.el}")))
      (goto-char (point-min))
      (search-forward "M a.el")
      (setq pos-a (line-beginning-position))
      (search-forward "R {old.el => b.el}")
      (setq pos-b (line-beginning-position))
      (setq-local transient-mark-mode t)
      (goto-char pos-b)
      (push-mark pos-a t t)
      (cl-letf (((symbol-function 'yes-or-no-p)
                 (lambda (&rest _) t))
                ((symbol-function 'majutsu-run-jj)
                 (lambda (&rest args)
                   (setq called args)
                   0)))
        (majutsu-restore-file-at-point))
      (should (equal called
                     '("restore" "--"
                       "file:\"a.el\""
                       "file:\"old.el\"|file:\"b.el\""))))))

(provide 'majutsu-restore-test)
;;; majutsu-restore-test.el ends here
