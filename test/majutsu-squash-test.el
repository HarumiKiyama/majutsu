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

(provide 'majutsu-squash-test)
;;; majutsu-squash-test.el ends here
