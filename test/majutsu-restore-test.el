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
