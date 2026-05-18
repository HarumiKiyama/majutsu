;;; majutsu-split-test.el --- Tests for split transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for split argument parsing and command assembly.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'majutsu-split)

(ert-deftest majutsu-split-execute-normalizes-fileset-args ()
  "Move placement options before fileset delimiter for direct split."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (args)
                 (setq called args)
                 0)))
      (majutsu-split-execute '(("--" "src/a.el") "--insert-after=main"))
      (should (equal called
                     '("split" "--insert-after=main" "--" "src/a.el"))))))

(ert-deftest majutsu-split-execute-normalizes-patch-flow-args ()
  "Patch-based split should receive normalized args."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) "patch"))
              ((symbol-function 'majutsu-interactive-run-with-patch)
               (lambda (&rest args)
                 (setq called args)))
              ((symbol-function 'majutsu-interactive-clear)
               (lambda () nil)))
      (majutsu-split-execute '(("--" "src/a.el") "--insert-after=main"))
      (should (equal called
                     '("split" ("--insert-after=main" "--" "src/a.el") "patch" t))))))

(ert-deftest majutsu-split-execute/interactive-opens-diff-selection-from-log ()
  "`--interactive' without selections should open a Majutsu diff selection flow."
  (let (diff-called split-called run-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-diff-setup-buffer)
               (lambda (args range filesets &optional _locked)
                 (setq diff-called (list args range filesets))
                 (get-buffer-create " *majutsu-split-diff-test*")))
              ((symbol-function 'majutsu-split)
               (lambda ()
                 (setq split-called t)))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest args)
                 (setq run-called args))))
      (unwind-protect
          (progn
            (majutsu-split-execute '("--interactive" "--revision=abc"))
            (should (equal diff-called '(nil ("--revisions=abc") nil)))
            (should split-called)
            (should-not run-called))
        (when-let* ((buf (get-buffer " *majutsu-split-diff-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-split-execute/interactive-preserves-filesets-for-diff ()
  "`--interactive' should pass split filesets to the Majutsu diff buffer."
  (let (diff-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-diff-setup-buffer)
               (lambda (args range filesets &optional _locked)
                 (setq diff-called (list args range filesets))
                 (get-buffer-create " *majutsu-split-diff-test*")))
              ((symbol-function 'majutsu-split)
               (lambda () nil))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest _)
                 (ert-fail "Native jj split should not run"))))
      (unwind-protect
          (progn
            (majutsu-split-execute
             '(("--" "src/a.el") "--interactive" "--revision=abc"))
            (should (equal diff-called
                           '(nil ("--revisions=abc") ("src/a.el")))))
        (when-let* ((buf (get-buffer " *majutsu-split-diff-test*")))
          (kill-buffer buf))))))

(provide 'majutsu-split-test)
;;; majutsu-split-test.el ends here
