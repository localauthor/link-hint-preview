;;; link-hint-preview.el --- Preview link contents in a pop-up frame with link-hint -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Grant Rosson

;; Author: Grant Rosson <https://github.com/localauthor>
;; Created: May 31, 2022
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Homepage: https://github.com/localauthor/link-hint-preview
;; Package-Requires: ((emacs "24.3") (link-hint "0.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Preview link contents in a pop-up frame with link-hint.

;; Set frame parameters in the alist 'link-hint-preview-frame-parameters'.

;; Set additional configurations by adding to 'link-hint-preview-mode-hook'.
;; For example, to remove mode-line and tab-bar from the pop-up frame, evaluate:

;; (add-hook 'link-hint-preview-mode-hook 'link-hint-preview-toggle-frame-mode-line)
;; (add-hook 'link-hint-preview-mode-hook 'toggle-frame-tab-bar)

;; Pop-up frame opens in 'view-mode', which see for mode-specific keybindings.

;; Pressing 'q' closes the pop-up frame and returns point to previous window.


;;; Code:

(require 'link-hint)
(require 'zk-link-hint)

;;; Variables

(defgroup link-hint-preview nil
  "Preview link contents in pop-up frame with link-hint."
  :group 'convenience
  :prefix "link-hint-preview-")

(defcustom link-hint-preview-frame-parameters
  '((width . 90)
    (height . 30)
    (undecorated . t)
    (left-fringe . 0)
    (right-fringe . 0)
    (tool-bar-lines . 0)
    (line-spacing . 0)
    (no-special-glyphs . t)
    (inhibit-double-buffering . t)
    (tool-bar-lines . 0)
    (vertical-scroll-bars . nil)
    (menu-bar-lines . 0)
    (title . "link-hint-preview"))
  "Parameters for pop-up frame called by 'link-hint-preview'."
  :type 'list)

(defvar link-hint-preview--kill-last nil)
(defvar-local link-hint-preview--origin-frame nil)


;;; Minor Mode

(define-minor-mode link-hint-preview-mode
  "Minor mode for link-hint-preview buffers."
  :init-value nil
  :keymap '(((kbd "q") . link-hint-preview-close-frame)
            ([return] . link-hint-preview-open))
  (if link-hint-preview-mode
      (progn
        (read-only-mode)
        (scroll-lock-mode 1)
        (setq-local show-paren-mode nil)
        (setq cursor-type nil))
    (read-only-mode -1)
    (scroll-lock-mode -1)
    (setq-local show-paren-mode t)
    (setq cursor-type t)))

(defun link-hint-preview-close-frame ()
  "Close frame opened with 'link-hint-preview'."
  (interactive)
  (let ((frame link-hint-preview--origin-frame))
    (link-hint-preview-mode -1)
    (read-only-mode -1)
    (if link-hint-preview--kill-last
        (kill-buffer)
      (delete-frame))
    (select-frame-set-input-focus frame)))

(defun link-hint-preview-open ()
  "Open previewed buffer normally in original frame."
  (interactive)
  (let ((frame link-hint-preview--origin-frame)
        (file (buffer-file-name))
        (pos (point)))
    (link-hint-preview-close-frame)
    (find-file file)
    (goto-char pos)))


;;; General Command

;;;###autoload
(defun link-hint-preview ()
  "Use avy to view link contents in a pop-up frame.
Set frame parameters in 'link-hint-preview-frame-parameters'."
  (interactive)
  (avy-with link-hint-preview
    (link-hint--one :preview)))


;;; Helper Functions

(defun link-hint-preview-toggle-frame-mode-line ()
  "Remove mode-line from buffers during preview.
Intended to be added to 'link-hint-preview-mode-hook'."
  (if link-hint-preview-mode
      (setq mode-line-format nil)
    (setq mode-line-format (default-value 'mode-line-format))))

(defun link-hint-preview--params (param value)
  "Generate 'pop-up-frame-parameters' dynamically."
  (cons `(,param . ,value) link-hint-preview-frame-parameters))


;;; file-link support

(link-hint-define-type 'file-link
  :preview #'link-hint-preview-file-link)

(defun link-hint-preview-file-link (link)
  "Popup a frame containing file at LINK.
Set popup frame parameters in 'link-hint-preview-frame-parameters'."
  (interactive)
  (let* ((buffer (get-file-buffer link))
         (frame (selected-frame)))
    (setq link-hint-preview--origin-frame (selected-frame))
    (if (get-file-buffer link)
        (setq link-hint-preview--kill-last nil)
      (setq buffer (find-file-noselect link))
      (setq link-hint-preview--kill-last t))
    (display-buffer-pop-up-frame
     buffer
     `((pop-up-frame-parameters . ,(link-hint-preview--params 'delete-before frame))
       (dedicated . t)))
    (with-current-buffer buffer
      (setq-local link-hint-preview--origin-frame frame)
      (link-hint-preview-mode))))


;;; org-link support

(link-hint-define-type 'org-link
  :preview #'link-hint-preview-org-link)

(defun link-hint-preview-org-link ()
  "Popup a frame containing file of org-link.
Set popup frame parameters in 'link-hint-preview-frame-parameters'."
  (interactive)
  (let* ((file (org-element-property :path (org-element-context)))
         (buffer (get-file-buffer file))
         (frame (selected-frame)))
    (setq link-hint-preview--origin-frame (selected-frame))
    (if (get-file-buffer file)
        (setq link-hint-preview--kill-last nil)
      (setq buffer (find-file-noselect file))
      (setq link-hint-preview--kill-last t))
    (display-buffer-pop-up-frame
     buffer
     `((pop-up-frame-parameters . ,(link-hint-preview--params 'delete-before frame))
       (dedicated . t)))
    (with-current-buffer buffer
      (setq-local link-hint-preview--origin-frame frame)
      (link-hint-preview-mode))))


;;; button support

(link-hint-define-type 'button
  :preview #'link-hint-preview-button)

(defun link-hint-preview-button (_link)
  (with-demoted-errors "%s"
    (let ((buffer (current-buffer))
          (frame (selected-frame))
          (new-buffer))
      (push-button)
      (setq new-buffer
            (current-buffer))
      (switch-to-buffer buffer)
      (display-buffer-pop-up-frame
       new-buffer
       `((pop-up-frame-parameters . ,(link-hint-preview--params 'delete-before frame))
         (dedicated . t)))
      (with-current-buffer new-buffer
        (setq-local link-hint-preview--origin-frame frame)
        (link-hint-preview-mode)))))

(provide 'link-hint-preview)

;;; link-hint-preview.el ends here
