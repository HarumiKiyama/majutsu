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

(provide 'majutsu-restore-test)
;;; majutsu-restore-test.el ends here
