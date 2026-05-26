;;; majutsu-selection-test.el --- Tests for selection  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for selection overlays and option helpers.

;;; Code:

(require 'ert)
(require 'majutsu-selection)
(require 'transient)
(require 'magit-section)

(defclass majutsu-test-option (majutsu-selection-option)
  ())

(ert-deftest majutsu-selection-render-test ()
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t))
      (insert "1234567890")
        (let* ((session (majutsu-selection-session-begin))
               (obj (make-instance 'majutsu-test-option
                                   :command 'ignore
                                   :key "a"
                                   :argument "--a="
                                   :selection-label "A"
                                   :locate-fn (lambda (val)
                                                (if (equal val "1")
                                                    (cons 1 3)
                                                  (cons 4 6)))))
               (transient--suffixes (list obj)))
        (oset obj value "1")
        (majutsu-selection-render session)
        (let ((ovs (overlays-at 1)))
          (should ovs)
          (let ((ov (seq-find (lambda (o) (overlay-get o 'majutsu-selection)) ovs)))
            (should ov)
            (should (= (overlay-start ov) 1))
            (should (= (overlay-end ov) 3))
            (should (string-match-p "A" (overlay-get ov 'before-string)))))
        (oset obj value "2")
        (majutsu-selection-render session)
        (let ((ovs (overlays-at 4)))
          (should ovs)
          (let ((ov (seq-find (lambda (o) (overlay-get o 'majutsu-selection)) ovs)))
            (should ov)
            (should (= (overlay-start ov) 4))
            (should (= (overlay-end ov) 6))))
        (oset obj value nil)
        (majutsu-selection-render session)
        (should-not (seq-find (lambda (o) (overlay-get o 'majutsu-selection))
                              (overlays-in (point-min) (point-max))))))))

(ert-deftest majutsu-selection-shared-locate-fn-test ()
  (with-temp-buffer
    (magit-section-mode)
    (let ((inhibit-read-only t))
      (insert "1234567890")
      (let* ((session (majutsu-selection-session-begin))
             (locator (lambda (val)
                        (if (equal val "1")
                            (cons 1 3)
                          (cons 4 6))))
             (provider (make-instance 'majutsu-test-option
                                      :command 'ignore
                                      :key "a"
                                      :argument "--a="
                                      :selection-label "A"
                                      :locate-fn locator))
             (consumer (make-instance 'majutsu-test-option
                                      :command 'ignore
                                      :key "b"
                                      :argument "--a="
                                      :selection-label "B"))
             (transient--suffixes (list provider consumer)))
        (oset consumer value "1")
        (majutsu-selection-render session)
        (let ((ovs (overlays-at 1)))
          (should ovs)
          (let ((ov (seq-find (lambda (o) (overlay-get o 'majutsu-selection)) ovs)))
            (should ov)
            (should (= (overlay-start ov) 1))
            (should (= (overlay-end ov) 3))
            (should (string-match-p "B" (overlay-get ov 'before-string)))))))))

(ert-deftest majutsu-selection-shared-targets-fn-test ()
  (with-temp-buffer
    (magit-section-mode)
    (let* ((provider (make-instance 'majutsu-test-option
                                    :command 'ignore
                                    :key "a"
                                    :argument "--a="
                                    :multi-value 'repeat
                                    :targets-fn (lambda () '("1"))))
           (consumer (make-instance 'majutsu-test-option
                                    :command 'ignore
                                    :key "b"
                                    :argument "--a="))
           (transient--suffixes (list consumer provider)))
      (should (majutsu-selection--selection-multi-p consumer))
      (let* ((fn (majutsu-selection--resolve-targets-fn consumer))
             (values (funcall fn))
             (current (majutsu-selection--toggle-current
                       (oref consumer value)
                       values
                       (majutsu-selection--selection-multi-p consumer))))
        (oset consumer value current)
        (should (equal (oref consumer value) '("1")))
        (should (listp (oref consumer value)))))))

(ert-deftest majutsu-selection-incompatible-clears-synced-options-test ()
  "Clearing an incompatible option should also clear its toggle counterpart."
  (let* ((revision (make-instance 'majutsu-test-option
                                  :command 'ignore
                                  :key "-r"
                                  :argument "--revision="))
         (from (make-instance 'majutsu-test-option
                              :command 'ignore
                              :key "-f"
                              :argument "--from="
                              :multi-value 'repeat))
         (revision-toggle (make-instance 'majutsu-selection-toggle-option
                                         :command 'ignore
                                         :key "r"
                                         :argument "--revision="))
         (from-toggle (make-instance 'majutsu-selection-toggle-option
                                     :command 'ignore
                                     :key "f"
                                     :argument "--from="
                                     :multi-value 'repeat))
         (transient--suffixes (list revision from revision-toggle from-toggle))
         (transient--prefix
          (make-instance 'transient-prefix
                         :command 'ignore
                         :incompatible '(("--revision=" "--from=")))))
    (transient-infix-set revision-toggle "abc")
    (should (equal (oref revision value) "abc"))
    (transient-infix-set from-toggle '("abc"))
    (should-not (oref revision value))
    (should-not (oref revision-toggle value))
    (transient-infix-set revision-toggle "abc")
    (should-not (oref from value))
    (should-not (oref from-toggle value))))

(ert-deftest majutsu-selection-repeat-option-init-strips-argument-prefix ()
  "Repeat options should store raw values after transient initialization."
  (let* ((prefix (make-instance 'transient-prefix
                                :command 'ignore
                                :incompatible nil))
         (from (make-instance 'majutsu-test-option
                              :command 'ignore
                              :key "-f"
                              :argument "--from="
                              :multi-value 'repeat))
         (transient--prefix prefix))
    (oset prefix value '("--from=abc" "--from=def"))
    (transient-init-value from)
    (should (equal (oref from value) '("abc" "def")))
    (should (equal (transient-infix-value from)
                   '("--from=abc" "--from=def")))))

(ert-deftest majutsu-selection-repeat-option-set-strips-argument-prefix ()
  "Repeat options should not double-prefix values passed to infix set."
  (let* ((prefix (make-instance 'transient-prefix
                                :command 'ignore
                                :incompatible nil))
         (from (make-instance 'majutsu-test-option
                              :command 'ignore
                              :key "-f"
                              :argument "--from="
                              :multi-value 'repeat))
         (transient--prefix prefix)
         (transient--suffixes (list from)))
    (transient-infix-set from '("--from=abc" "--from=def"))
    (should (equal (oref from value) '("abc" "def")))
    (should (equal (transient-infix-value from)
                   '("--from=abc" "--from=def")))))

(provide 'majutsu-selection-test)
;;; majutsu-selection-test.el ends here
