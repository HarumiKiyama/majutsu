;;; majutsu-squash-test.el --- Tests for squash transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for squash argument parsing and command assembly.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'majutsu-squash)

(ert-deftest majutsu-squash-transient/selection-hides-toggle-at-point-suffixes ()
  "Squash transient should not show duplicate no-dash selection toggles."
  (dolist (key '("r" "f" "t" "o" "a" "b"))
    (should-error (transient-get-suffix 'majutsu-squash key)))
  (dolist (key '("-r" "-f" "-t" "-o" "-A" "-B"))
    (should (transient-get-suffix 'majutsu-squash key))))

(ert-deftest majutsu-squash-arguments-normalizes-fileset-args ()
  "Move selection options before fileset delimiter."
  (let ((transient-current-command 'majutsu-squash))
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest _) '(("--" "src/a.el") "--into=main" "--from=@"))))
      (should (equal (majutsu-squash-arguments)
                     '("--into=main" "--from=@" "--" "src/a.el"))))))

(ert-deftest majutsu-squash-execute-normalizes-patch-flow-args ()
  "Patch-based squash should receive normalized args."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) "patch"))
              ((symbol-function 'majutsu-interactive-run-with-patch)
               (lambda (&rest args)
                 (setq called args)))
              ((symbol-function 'majutsu-interactive-clear)
               (lambda () nil)))
      (majutsu-squash-execute '(("--" "src/a.el") "--into=main" "--from=@"))
      (should (equal called
                     '("squash" ("--into=main" "--from=@" "--" "src/a.el") "patch" t))))))

(ert-deftest majutsu-squash--initial-args/defaults-to-interactive ()
  "Squash transient should start in Majutsu interactive selection mode."
  (cl-letf (((symbol-function 'majutsu-squash--default-args)
             (lambda () nil)))
    (should (equal (majutsu-squash--initial-args) '("--interactive")))))

(ert-deftest majutsu-squash-execute/default-opens-selection-page ()
  "Default squash execution should open a Majutsu file-list selection page."
  (let (selection-called squash-called run-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-squash--setup-selection-buffer)
               (lambda (range filesets)
                 (setq selection-called (list range filesets))
                 (get-buffer-create " *majutsu-squash-selection-test*")))
              ((symbol-function 'majutsu-squash)
               (lambda ()
                 (setq squash-called t)))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest args)
                 (setq run-called args))))
      (unwind-protect
          (progn
            (majutsu-squash-execute '("--interactive" "--revision=abc"))
            (should (equal selection-called '(("--revisions=abc") nil)))
            (should squash-called)
            (should-not run-called))
        (when-let* ((buf (get-buffer " *majutsu-squash-selection-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-squash-execute/interactive-uses-from-revisions-for-selection ()
  "`--interactive' should show source changes from repeated --from args."
  (let (selection-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-squash--setup-selection-buffer)
               (lambda (range filesets)
                 (setq selection-called (list range filesets))
                 (get-buffer-create " *majutsu-squash-selection-test*")))
              ((symbol-function 'majutsu-squash)
               (lambda () nil))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest _) nil)))
      (unwind-protect
          (progn
            (majutsu-squash-execute
             '("--interactive" "--from=abc" "--from=def" "--into=main" "--" "src/a.el"))
            (should (equal selection-called
                           '(("--revisions=abc" "--revisions=def") ("src/a.el")))))
        (when-let* ((buf (get-buffer " *majutsu-squash-selection-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-squash--read-files/completes-changed-files-for-revision ()
  "Squash path completion should use files changed by --revision."
  (let ((transient-current-command 'majutsu-squash)
        seen-revsets
        seen-collection)
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest _) '("--revision=abc")))
              ((symbol-function 'majutsu-file-changed-list)
               (lambda (rev)
                 (push rev seen-revsets)
                 '("src/a.el")))
              ((symbol-function 'majutsu-completing-read-multiple)
               (lambda (_prompt collection _predicate _require-match
                        _initial-input _hist &optional _def _category)
                 (setq seen-collection collection)
                 '("src/a.el"))))
      (should (equal (majutsu-squash--read-files "Limit" nil nil)
                     '("src/a.el")))
      (should (equal (nreverse seen-revsets) '("abc")))
      (should (equal seen-collection '("src/a.el"))))))

(ert-deftest majutsu-squash--read-files/completes-union-for-from-revisions ()
  "Squash path completion should merge files changed by repeated --from args."
  (let ((transient-current-command 'majutsu-squash)
        seen-revsets
        seen-collection)
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest _) '("--from=abc" "--from=def")))
              ((symbol-function 'majutsu-file-changed-list)
               (lambda (rev)
                 (push rev seen-revsets)
                 (pcase rev
                   ("abc" '("src/a.el" "shared.el"))
                   ("def" '("test/a-test.el" "shared.el")))))
              ((symbol-function 'majutsu-completing-read-multiple)
               (lambda (_prompt collection _predicate _require-match
                        _initial-input _hist &optional _def _category)
                 (setq seen-collection collection)
                 '("shared.el"))))
      (should (equal (majutsu-squash--read-files "Limit" nil nil)
                     '("shared.el")))
      (should (equal (nreverse seen-revsets) '("abc" "def")))
      (should (equal seen-collection
                     '("src/a.el" "shared.el" "test/a-test.el"))))))

(ert-deftest majutsu-file-squash/uses-operation-fileset ()
  "File-level squash should honor a section-specific operation fileset."
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
        (majutsu-file-squash))
      (should (equal called
                     '("squash" "file:\"old.txt\"|file:\"new.txt\""))))))

(ert-deftest majutsu-file-squash/uses-region-file-sections ()
  "File-level squash should squash all jj-file sections in the active region."
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
        (majutsu-file-squash))
      (should (equal called
                     '("squash" "--"
                       "file:\"a.el\""
                       "file:\"old.el\"|file:\"b.el\""))))))

(provide 'majutsu-squash-test)
;;; majutsu-squash-test.el ends here
