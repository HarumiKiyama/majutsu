;;; majutsu-section-test.el --- Tests for section helpers  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 0WD0

;; Author: 0WD0 <wd.1105848296@gmail.com>
;; Maintainer: 0WD0 <wd.1105848296@gmail.com>
;; Keywords: tools, vc
;; URL: https://github.com/0WD0/majutsu

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for Majutsu section visibility wrappers.

;;; Code:

(require 'ert)
(require 'majutsu-log)
(require 'majutsu-section)

(defun majutsu-section-test--log-entry (&rest kvs)
  "Build a log entry plist from KVS."
  kvs)

(ert-deftest majutsu-section-hide/preserves-final-newline-for-commit-sections ()
  "Hiding a commit section should keep the final newline visible."
  (let* ((compiled (majutsu-log--compile-columns
                    '((:field change-id :module heading :face t)
                      (:field description :module heading :face t)
                      (:field long-desc :module body :face t)
                      (:field id :module metadata :face nil))))
         (entry-1 (majutsu-section-test--log-entry
                   :id "id-1"
                   :indent 2
                   :columns '((change-id . "chg1")
                              (description . "Title")
                              (long-desc . "Body line 1\nBody line 2"))
                   :heading-prefixes '("○ ")))
         (entry-2 (majutsu-section-test--log-entry
                   :id "id-2"
                   :indent 2
                   :columns '((change-id . "chg2")
                              (description . "Next"))
                   :heading-prefixes '("○ "))))
    (with-temp-buffer
      (majutsu-log-mode)
      (setq buffer-read-only nil)
      (magit-insert-section (lograph)
        (majutsu-log--insert-entry entry-1 compiled)
        (majutsu-log--insert-entry entry-2 compiled))
      (goto-char (point-min))
      (search-forward "chg1")
      (let* ((section (magit-current-section))
             (content (oref section content)))
        (majutsu-section-show section)
        (should (eq (char-before (oref section end)) ?\n))
        (majutsu-section-hide section)
        (should (get-char-property (1- content) 'invisible))
        (should-not (get-char-property (1- (oref section end)) 'invisible))
        (search-forward "chg2")
        (beginning-of-line)
        (should (stringp (get-text-property (point) 'line-prefix)))))))

(ert-deftest majutsu-section-command-remaps-magit-commands ()
  "Majutsu modes should remap Magit section commands to wrappers."
  (with-temp-buffer
    (majutsu-log-mode)
    (should (eq (command-remapping 'magit-section-toggle) 'majutsu-section-toggle))
    (should (eq (command-remapping 'magit-section-cycle) 'majutsu-section-cycle))
    (should (eq (command-remapping 'magit-section-show-level-1-all)
                'majutsu-section-show-level-1-all))
    (should (eq (command-remapping 'magit-mouse-toggle-section)
                'majutsu-mouse-toggle-section))))

(ert-deftest majutsu-section-hide/prefixes-visibility-indicator ()
  "Visibility indicators should follow display-only section indentation."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let ((magit-section-visibility-indicators
           '(nil (?+ . ?-)))
          section)
      (magit-insert-section (status)
        (magit-insert-heading "Status")
        (magit-insert-section (jj-file "src/a.el")
          (let ((start (point)))
            (magit-insert-heading "M src/a.el")
            (majutsu-log--apply-line-prefix-span start (point) "  "))
          (magit-insert-section-body
            (insert "@@ -1 +1 @@\n-old\n+new\n"))))
      (setq section (car (oref magit-root-section children)))
      (majutsu-section-hide section)
      (let* ((indicator
              (seq-find (lambda (overlay)
                          (overlay-get overlay 'magit-vis-indicator))
                        (overlays-in (oref section start)
                                     (1+ (line-end-position)))))
             (before (and indicator
                          (overlay-get indicator 'before-string))))
        (should before)
        (should (string-prefix-p "  " before)))
      (majutsu-section-show section)
      (majutsu-section-hide section)
      (let* ((indicator
              (seq-find (lambda (overlay)
                          (overlay-get overlay 'magit-vis-indicator))
                        (overlays-in (oref section start)
                                     (1+ (line-end-position)))))
             (before (and indicator
                          (substring-no-properties
                           (overlay-get indicator 'before-string)))))
        (should (string-prefix-p "  " before))
        (should-not (string-prefix-p "    " before))))))

(ert-deftest majutsu-section-hide/does-not-prefix-graph-indicator ()
  "Visibility indicators should not duplicate log graph prefixes."
  (let* ((compiled (majutsu-log--compile-columns
                    '((:field change-id :module heading :face t)
                      (:field description :module heading :face t)
                      (:field long-desc :module body :face t)
                      (:field id :module metadata :face nil))))
         (entry (majutsu-section-test--log-entry
                 :id "id-1"
                 :indent 2
                 :columns '((change-id . "chg1")
                            (description . "Title")
                            (long-desc . "Body line"))
                 :heading-prefixes '("○ "))))
    (with-temp-buffer
      (let ((magit-section-visibility-indicators
             '(nil (?+ . ?-))))
        (majutsu-log-mode)
        (setq buffer-read-only nil)
        (magit-insert-section (lograph)
          (majutsu-log--insert-entry entry compiled))
        (goto-char (point-min))
        (let ((section (magit-current-section)))
          (majutsu-section-show section)
          (majutsu-section-hide section)
          (let* ((indicator
                  (seq-find (lambda (overlay)
                              (overlay-get overlay 'magit-vis-indicator))
                            (overlays-in (oref section start)
                                         (1+ (line-end-position)))))
                 (before (and indicator
                              (substring-no-properties
                               (overlay-get indicator 'before-string)))))
            (should (equal (substring-no-properties
                            (get-text-property (oref section start)
                                               'line-prefix))
                           "○ "))
            (should before)
            (should-not (string-prefix-p "○ " before))
            (majutsu-section-show section)
            (majutsu-section-hide section)
            (setq before
                  (substring-no-properties
                   (overlay-get indicator 'before-string)))
            (should-not (string-prefix-p "○ " before))))))))

(provide 'majutsu-section-test)
;;; majutsu-section-test.el ends here
