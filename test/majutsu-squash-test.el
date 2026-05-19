;;; majutsu-squash-test.el --- Tests for squash transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for squash argument parsing and command assembly.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'majutsu-squash)

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

(provide 'majutsu-squash-test)
;;; majutsu-squash-test.el ends here
