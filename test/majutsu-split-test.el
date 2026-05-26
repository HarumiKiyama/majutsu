;;; majutsu-split-test.el --- Tests for split transient  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for split argument parsing and command assembly.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'majutsu-split)

(ert-deftest majutsu-split-transient/selection-hides-toggle-at-point-suffixes ()
  "Split transient should not show duplicate no-dash selection toggles."
  (dolist (key '("r" "o" "a" "b"))
    (should-error (transient-get-suffix 'majutsu-split key)))
  (dolist (key '("-r" "-o" "-A" "-B"))
    (should (transient-get-suffix 'majutsu-split key))))

(ert-deftest majutsu-split-execute-normalizes-fileset-args-for-selection-page ()
  "Move placement options before fileset delimiter before opening selection."
  (let (selection-called split-called run-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-interactive--selection-buffer)
               (lambda () (current-buffer)))
              ((symbol-function 'majutsu-split--setup-selection-buffer)
               (lambda (range filesets)
                 (setq selection-called (list range filesets))
                 (get-buffer-create " *majutsu-split-selection-test*")))
              ((symbol-function 'majutsu-split)
               (lambda ()
                 (setq split-called t)))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest args)
                 (setq run-called args))))
      (unwind-protect
          (with-temp-buffer
            (majutsu-split-execute '(("--" "src/a.el") "--insert-after=main"))
            (should (equal selection-called
                           '(("--revisions=@") ("src/a.el"))))
            (should split-called)
            (should-not run-called))
        (when-let* ((buf (get-buffer " *majutsu-split-selection-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-split-execute-normalizes-patch-flow-args ()
  "Patch-based split should receive normalized non-interactive args."
  (let (called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) "patch"))
              ((symbol-function 'majutsu-interactive-run-with-patch)
               (lambda (&rest args)
                 (setq called args)))
              ((symbol-function 'majutsu-interactive-clear)
               (lambda () nil)))
      (majutsu-split-execute
       '(("--" "src/a.el")
         "--insert-after=main"
         "--interactive"
         "-i"
         "--tool=meld"
         "--tool" "vimdiff"))
      (should (equal called
                     '("split" ("--insert-after=main" "--" "src/a.el") "patch" t))))))

(ert-deftest majutsu-split-execute/default-opens-selection-page ()
  "Default split execution should open a Majutsu file-list selection page."
  (let (selection-called split-called run-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-interactive--selection-buffer)
               (lambda () (current-buffer)))
              ((symbol-function 'majutsu-split--setup-selection-buffer)
               (lambda (range filesets)
                 (setq selection-called (list range filesets))
                 (get-buffer-create " *majutsu-split-selection-test*")))
              ((symbol-function 'majutsu-split)
               (lambda ()
                 (setq split-called t)))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest args)
                 (setq run-called args))))
      (unwind-protect
          (with-temp-buffer
            (majutsu-split-execute '("--revision=abc"))
            (should (equal selection-called '(("--revisions=abc") nil)))
            (should split-called)
            (should-not run-called))
        (when-let* ((buf (get-buffer " *majutsu-split-selection-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-split-execute/interactive-opens-diff-selection-from-log ()
  "Split without selections should open a Majutsu diff selection flow."
  (let (diff-called split-called run-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-interactive--selection-buffer)
               (lambda () (current-buffer)))
              ((symbol-function 'majutsu-split--setup-selection-buffer)
               (lambda (range filesets)
                 (setq diff-called (list nil range filesets))
                 (get-buffer-create " *majutsu-split-diff-test*")))
              ((symbol-function 'majutsu-split)
               (lambda ()
                 (setq split-called t)))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest args)
                 (setq run-called args))))
      (unwind-protect
          (with-temp-buffer
            (majutsu-split-execute '("--revision=abc"))
            (should (equal diff-called '(nil ("--revisions=abc") nil)))
            (should split-called)
            (should-not run-called))
        (when-let* ((buf (get-buffer " *majutsu-split-diff-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-split-execute/interactive-preserves-filesets-for-diff ()
  "Split should pass filesets to the Majutsu diff buffer."
  (let (diff-called)
    (cl-letf (((symbol-function 'majutsu-interactive-build-patch-if-selected)
               (lambda (&rest _) nil))
              ((symbol-function 'majutsu-interactive--selection-buffer)
               (lambda () (current-buffer)))
              ((symbol-function 'majutsu-split--setup-selection-buffer)
               (lambda (range filesets)
                 (setq diff-called (list nil range filesets))
                 (get-buffer-create " *majutsu-split-diff-test*")))
              ((symbol-function 'majutsu-split)
               (lambda () nil))
              ((symbol-function 'majutsu-run-jj-with-editor)
               (lambda (&rest _)
                 (ert-fail "Native jj split should not run"))))
      (unwind-protect
          (with-temp-buffer
            (majutsu-split-execute
             '(("--" "src/a.el") "--revision=abc"))
            (should (equal diff-called
                           '(nil ("--revisions=abc") ("src/a.el")))))
        (when-let* ((buf (get-buffer " *majutsu-split-diff-test*")))
          (kill-buffer buf))))))

(ert-deftest majutsu-split--read-files/completes-changed-files-for-revision ()
  "Split path completion should use files changed by the selected revision."
  (let ((transient-current-command 'majutsu-split)
        seen-rev
        seen-collection)
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest _) '("--revision=abc")))
              ((symbol-function 'majutsu-file-changed-list)
               (lambda (rev)
                 (setq seen-rev rev)
                 '("src/a.el" "test/a-test.el")))
              ((symbol-function 'majutsu-completing-read-multiple)
               (lambda (_prompt collection _predicate _require-match
                        _initial-input _hist &optional _def _category)
                 (setq seen-collection collection)
                 '("src/a.el"))))
      (should (equal (majutsu-split--read-files "Limit" nil nil)
                     '("src/a.el")))
      (should (equal seen-rev "abc"))
      (should (equal seen-collection '("src/a.el" "test/a-test.el"))))))

(ert-deftest majutsu-file-split/uses-region-file-sections ()
  "File-level split should split all jj-file sections in the active region."
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
      (cl-letf (((symbol-function 'majutsu-run-jj-with-editor)
                 (lambda (args)
                   (setq called args)
                   0)))
        (majutsu-file-split))
      (should (equal called
                     '("split" "--"
                       "file:\"a.el\""
                       "file:\"old.el\"|file:\"b.el\""))))))

(ert-deftest majutsu-file-section-map-has-split-binding ()
  "`S' should be bound to `majutsu-file-split' in file section map."
  (should (eq (lookup-key majutsu-file-section-map "S")
              #'majutsu-file-split)))

(provide 'majutsu-split-test)
;;; majutsu-split-test.el ends here
