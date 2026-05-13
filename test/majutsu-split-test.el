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

(provide 'majutsu-split-test)
;;; majutsu-split-test.el ends here
