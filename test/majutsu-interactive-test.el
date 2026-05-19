;;; majutsu-interactive-test.el --- Tests for majutsu-interactive -*- lexical-binding: t; -*-

;; Copyright (C) 2026 0WD0

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Focused tests for helper logic in `majutsu-interactive.el'.

;;; Code:

(require 'ert)
(require 'majutsu-interactive)

(defun majutsu-interactive-test--faces-in-region (beg end)
  "Return overlay faces between BEG and END."
  (let (faces)
    (dolist (ov (overlays-in beg end))
      (when-let* ((face (overlay-get ov 'face)))
        (push face faces)))
    faces))

(ert-deftest majutsu-interactive--build-tool-config/strips-tramp-prefix ()
  "Tool config should pass local remote paths to jj merge-tool args."
  (let ((config
         (cl-letf (((symbol-function 'majutsu-interactive--write-applypatch-script)
                    (lambda (_reverse) "/ssh:demo:/tmp/applypatch.sh"))
                   ((symbol-function 'majutsu-convert-filename-for-jj)
                    (lambda (path)
                      (pcase path
                        ("/ssh:demo:/tmp/applypatch.sh" "/tmp/applypatch.sh")
                        ("/ssh:demo:/tmp/patch.diff" "/tmp/patch.diff")
                        (_ path)))))
           (majutsu-interactive--build-tool-config "/ssh:demo:/tmp/patch.diff" nil))))
    (should (equal (length config) 4))
    (should (string-match-p "merge-tools\\.majutsu-applypatch\\.program=/tmp/applypatch\\.sh"
                            (nth 1 config)))
    (should (string-match-p "\\\"/tmp/patch\\.diff\\\"" (nth 3 config)))
    (should-not (string-match-p "/ssh:demo:" (nth 1 config)))
    (should-not (string-match-p "/ssh:demo:" (nth 3 config)))))

(ert-deftest majutsu-interactive--temp-dir/uses-nearby-temp-file ()
  "Temp dir helper should allocate directories near current workspace."
  (let ((majutsu-interactive--temp-dir nil)
        (majutsu-interactive--temp-dir-remote nil)
        seen)
    (cl-letf (((symbol-function 'file-directory-p)
               (lambda (_path) nil))
              ((symbol-function 'make-nearby-temp-file)
               (lambda (prefix dir-flag &optional suffix)
                 (setq seen (list prefix dir-flag suffix))
                 "/tmp/majutsu-interactive-dir")))
      (should (equal (majutsu-interactive--temp-dir)
                     "/tmp/majutsu-interactive-dir"))
      (should (equal seen '("majutsu-interactive-" t nil))))))

(ert-deftest majutsu-interactive--temp-dir/recreates-when-remote-prefix-changes ()
  "Temp dir cache should be invalidated when host context changes."
  (let ((default-directory "/tmp/")
        (majutsu-interactive--temp-dir nil)
        (majutsu-interactive--temp-dir-remote nil)
        seen)
    (cl-letf (((symbol-function 'file-directory-p)
               (lambda (_path) t))
              ((symbol-function 'file-remote-p)
               (lambda (path &optional identification _connected)
                 (when (and (equal path default-directory)
                            (null identification))
                   (if (string-prefix-p "/ssh:demo:" default-directory)
                       "/ssh:demo:"
                     nil))))
              ((symbol-function 'make-nearby-temp-file)
               (lambda (_prefix _dir-flag &optional _suffix)
                 (let ((value (format "/tmp/majutsu-interactive-%d" (length seen))))
                   (push value seen)
                   value))))
      (let ((local (majutsu-interactive--temp-dir)))
        (setq default-directory "/ssh:demo:/tmp/")
        (let ((remote (majutsu-interactive--temp-dir)))
          (should (not (equal local remote)))
          (should (equal (length seen) 2)))))))

(ert-deftest majutsu-interactive-toggle-hunk/marks-header-not-body ()
  "Whole-hunk selection should mark the hunk header without recoloring its body."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let (file-section hunk-section)
      (magit-insert-section (jj-file "src/a.el" nil)
        (magit-insert-heading "M src/a.el")
        (setq file-section magit-insert-section--current)
        (magit-insert-section (jj-hunk '("src/a.el" 1) nil)
          (magit-insert-heading "@@ -1 +1 @@")
          (setq hunk-section magit-insert-section--current)
          (insert "-old\n+new\n")))
      (goto-char (oref hunk-section start))
      (majutsu-interactive-toggle-hunk)
      (should (seq-some (lambda (ov)
                          (string-match-p "\\[x\\]"
                                          (or (overlay-get ov 'before-string) "")))
                        (overlays-at (oref hunk-section start))))
      (should-not (memq 'majutsu-interactive-selected-hunk
                        (majutsu-interactive-test--faces-in-region
                         (oref hunk-section content)
                         (oref hunk-section end))))
      (should (seq-some (lambda (ov)
                          (string-match-p "\\[~\\]"
                                          (or (overlay-get ov 'before-string) "")))
                        (overlays-at (oref file-section start)))))))

(ert-deftest majutsu-interactive--build-file-patch/renamed-hunk-only-omits-rename ()
  "Hunk-only selection in a renamed file should not move the rename metadata."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let* ((header (string-join
                    '("diff --git a/old.txt b/new.txt"
                      "similarity index 88%"
                      "rename from old.txt"
                      "rename to new.txt"
                      "--- a/old.txt"
                      "+++ b/new.txt"
                      "")
                    "\n"))
           file-section
           hunk-section)
      (magit-insert-section (jj-file "new.txt" nil :header header)
        (magit-insert-heading "R old.txt => new.txt")
        (setq file-section magit-insert-section--current)
        (magit-insert-section (jj-hunk '("new.txt" 1) nil)
          (magit-insert-heading "@@ -1 +1 @@")
          (setq hunk-section magit-insert-section--current)
          (insert "-old\n+new\n")))
      (let ((patch (majutsu-interactive--build-file-patch
                    file-section
                    (list (list hunk-section :all)))))
        (should (string-prefix-p "diff --git a/old.txt b/old.txt\n" patch))
        (should (string-match-p "^--- a/old\\.txt$" patch))
        (should (string-match-p "^+++ b/old\\.txt$" patch))
        (should-not (string-match-p "^rename from " patch))
        (should-not (string-match-p "^rename to " patch))))))

(ert-deftest majutsu-interactive--build-patch/pure-rename-file-selection ()
  "A file-level selection should support pure rename patches without hunks."
  (with-temp-buffer
    (magit-section-mode)
    (setq buffer-read-only nil)
    (let ((header (string-join
                   '("diff --git a/old.txt b/new.txt"
                     "similarity index 100%"
                     "rename from old.txt"
                     "rename to new.txt"
                     "")
                   "\n"))
          file-section)
      (magit-insert-section (jj-file "new.txt" nil :header header)
        (magit-insert-heading "R old.txt => new.txt")
        (setq file-section magit-insert-section--current))
      (majutsu-interactive--set-file-selection file-section t)
      (should (equal (majutsu-interactive--build-patch)
                     header)))))

(provide 'majutsu-interactive-test)
;;; majutsu-interactive-test.el ends here
