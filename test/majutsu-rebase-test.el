;;; majutsu-rebase-test.el --- Tests for rebase transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for rebase transient layout.

;;; Code:

(require 'ert)
(require 'majutsu-rebase)

(ert-deftest majutsu-rebase-transient/selection-hides-toggle-at-point-suffixes ()
  "Rebase transient should not show duplicate no-dash selection toggles."
  (dolist (key '("s" "b" "r" "o" "a" "B"))
    (should-error (transient-get-suffix 'majutsu-rebase key)))
  (dolist (key '("-s" "-b" "-r" "-o" "-A" "-B"))
    (should (transient-get-suffix 'majutsu-rebase key))))

(provide 'majutsu-rebase-test)
;;; majutsu-rebase-test.el ends here
