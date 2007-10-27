;;; copyright.el --- update the copyright notice in current buffer

;; Copyright (C) 1991, 1992, 1993, 1994, 1995, 1998, 2001, 2002, 2003,
;;   2004, 2005, 2006, 2007 Free Software Foundation, Inc.

;; Author: Daniel Pfeiffer <occitan@esperanto.org>
;; Keywords: maint, tools

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Allows updating the copyright year and above mentioned GPL version manually
;; or when saving a file.
;; Do (add-hook 'before-save-hook 'copyright-update), or use
;; M-x customize-variable RET before-save-hook RET.

;;; Code:

(defgroup copyright nil
  "Update the copyright notice in current buffer."
  :group 'tools)

(defcustom copyright-limit 2000
  "Don't try to update copyright beyond this position unless interactive.
A value of nil means to search whole buffer."
  :group 'copyright
  :type '(choice (integer :tag "Limit")
		 (const :tag "No limit")))

;; The character classes have the Latin-1 version and the Latin-9
;; version, which is probably enough.
(defcustom copyright-regexp
 "\\([����]\\|@copyright{}\\|[Cc]opyright\\s *:?\\s *\\(?:(C)\\)?\
\\|[Cc]opyright\\s *:?\\s *[����]\\)\
\\s *\\([1-9]\\([-0-9, ';/*%#\n\t]\\|\\s<\\|\\s>\\)*[0-9]+\\)"
  "What your copyright notice looks like.
The second \\( \\) construct must match the years."
  :group 'copyright
  :type 'regexp)

(defcustom copyright-names-regexp ""
  "Regexp matching the names which correspond to the user.
Only copyright lines where the name matches this regexp will be updated.
This allows you to avoid adding years to a copyright notice belonging to
someone else or to a group for which you do not work."
  :group 'copyright
  :type 'regexp)

(defcustom copyright-years-regexp
 "\\(\\s *\\)\\([1-9]\\([-0-9, ';/*%#\n\t]\\|\\s<\\|\\s>\\)*[0-9]+\\)"
  "Match additional copyright notice years.
The second \\( \\) construct must match the years."
  :group 'copyright
  :type 'regexp)


(defcustom copyright-query 'function
  "If non-nil, ask user before changing copyright.
When this is `function', only ask when called non-interactively."
  :group 'copyright
  :type '(choice (const :tag "Do not ask")
		 (const :tag "Ask unless interactive" function)
		 (other :tag "Ask" t)))


;; when modifying this, also modify the comment generated by autoinsert.el
(defconst copyright-current-gpl-version "3"
  "String representing the current version of the GPL or nil.")

(defvar copyright-update t)

;; This is a defvar rather than a defconst, because the year can
;; change during the Emacs session.
(defvar copyright-current-year (substring (current-time-string) -4)
  "String representing the current year.")

(defsubst copyright-limit ()            ; re-search-forward BOUND
  (and copyright-limit (+ (point) copyright-limit)))

(defun copyright-update-year (replace noquery)
  (when
      (condition-case err
	  (re-search-forward (concat "\\(" copyright-regexp
				     "\\)\\([ \t]*\n\\)?.*\\(?:"
				     copyright-names-regexp "\\)")
			     (copyright-limit)
			     t)
	;; In case the regexp is rejected.  This is useful because
	;; copyright-update is typically called from before-save-hook where
	;; such an error is very inconvenient for the user.
	(error (message "Can't update copyright: %s" err) nil))
    (goto-char (match-end 1))
    ;; If the years are continued onto multiple lined
    ;; that are marked as comments, skip to the end of the years anyway.
    (while (save-excursion
	     (and (eq (following-char) ?,)
		  (progn (forward-char 1) t)
		  (progn (skip-chars-forward " \t") (eolp))
		  comment-start-skip
		  (save-match-data
		    (forward-line 1)
		    (and (looking-at comment-start-skip)
			 (goto-char (match-end 0))))
		  (save-match-data
		    (looking-at copyright-years-regexp))))
      (forward-line 1)
      (re-search-forward comment-start-skip)
      (re-search-forward copyright-years-regexp))

    ;; Note that `current-time-string' isn't locale-sensitive.
    (setq copyright-current-year (substring (current-time-string) -4))
    (unless (string= (buffer-substring (- (match-end 3) 2) (match-end 3))
		     (substring copyright-current-year -2))
      (if (or noquery
	      (y-or-n-p (if replace
			    (concat "Replace copyright year(s) by "
				    copyright-current-year "? ")
			  (concat "Add " copyright-current-year
				  " to copyright? "))))
	  (if replace
	      (replace-match copyright-current-year t t nil 2)
	    (let ((size (save-excursion (skip-chars-backward "0-9"))))
	      (if (and (eq (% (- (string-to-number copyright-current-year)
				 (string-to-number (buffer-substring
						    (+ (point) size)
						    (point))))
			      100)
			   1)
		       (or (eq (char-after (+ (point) size -1)) ?-)
			   (eq (char-after (+ (point) size -2)) ?-)))
		  ;; This is a range so just replace the end part.
		  (delete-char size)
		;; Insert a comma with the preferred number of spaces.
		(insert
		 (save-excursion
		   (if (re-search-backward "[0-9]\\( *, *\\)[0-9]"
					   (line-beginning-position) t)
		       (match-string 1)
		     ", ")))
		;; If people use the '91 '92 '93 scheme, do that as well.
		(if (eq (char-after (+ (point) size -3)) ?')
		    (insert ?')))
	      ;; Finally insert the new year.
	      (insert (substring copyright-current-year size))))))))

;;;###autoload
(defun copyright-update (&optional arg interactivep)
  "Update copyright notice at beginning of buffer to indicate the current year.
With prefix ARG, replace the years in the notice rather than adding
the current year after them.  If necessary, and
`copyright-current-gpl-version' is set, any copying permissions
following the copyright are updated as well.
If non-nil, INTERACTIVEP tells the function to behave as when it's called
interactively."
  (interactive "*P\nd")
  (when (or copyright-update interactivep)
    (let ((noquery (or (not copyright-query)
		       (and (eq copyright-query 'function) interactivep))))
      (save-excursion
	(save-restriction
	  (widen)
	  (goto-char (point-min))
	  (copyright-update-year arg noquery)
	  (goto-char (point-min))
	  (and copyright-current-gpl-version
	       ;; match the GPL version comment in .el files, including the
	       ;; bilingual Esperanto one in two-column, and in texinfo.tex
	       (re-search-forward
                "\\(the Free Software Foundation;\
 either \\|; a\\^u eldono \\([0-9]+\\)a, ? a\\^u (la\\^u via	 \\)\
version \\([0-9]+\\), or (at"
                (copyright-limit) t)
               ;; Don't update if the file is already using a more recent
               ;; version than the "current" one.
               (< (string-to-number (match-string 3))
                  (string-to-number copyright-current-gpl-version))
	       (or noquery
		   (y-or-n-p (format "Replace GPL version by %s? "
				     copyright-current-gpl-version)))
	       (progn
		 (if (match-end 2)
		     ;; Esperanto bilingual comment in two-column.el
		     (replace-match copyright-current-gpl-version t t nil 2))
		 (replace-match copyright-current-gpl-version t t nil 3))))
	(set (make-local-variable 'copyright-update) nil)))
    ;; If a write-file-hook returns non-nil, the file is presumed to be written.
    nil))


;;;###autoload
(defun copyright-fix-years ()
  "Convert 2 digit years to 4 digit years.
Uses heuristic: year >= 50 means 19xx, < 50 means 20xx."
  (interactive)
  (widen)
  (goto-char (point-min))
  (if (re-search-forward copyright-regexp (copyright-limit) t)
      (let ((s (match-beginning 2))
	    (e (copy-marker (1+ (match-end 2))))
	    (p (make-marker))
	    last)
	(goto-char s)
	(while (re-search-forward "[0-9]+" e t)
	  (set-marker p (point))
	  (goto-char (match-beginning 0))
	  (let ((sep (char-before))
		(year (string-to-number (match-string 0))))
	    (when (and sep
		       (/= (char-syntax sep) ?\s)
		       (/= sep ?-))
	      (insert " "))
	    (when (< year 100)
	      (insert (if (>= year 50) "19" "20"))))
	  (goto-char p)
	  (setq last p))
	(when last
	  (goto-char last)
	  ;; Don't mess up whitespace after the years.
	  (skip-chars-backward " \t")
	  (save-restriction
	    (narrow-to-region (point-min) (point))
	    (let ((fill-prefix "     "))
	      (fill-region s last))))
	(set-marker e nil)
	(set-marker p nil)
	(copyright-update nil t))
    (message "No copyright message")))

;;;###autoload
(define-skeleton copyright
  "Insert a copyright by $ORGANIZATION notice at cursor."
  "Company: "
  comment-start
  "Copyright (C) " `(substring (current-time-string) -4) " by "
  (or (getenv "ORGANIZATION")
      str)
  '(if (and copyright-limit (> (point) (+ (point-min) copyright-limit)))
       (message "Copyright extends beyond `copyright-limit' and won't be updated automatically."))
  comment-end \n)

(provide 'copyright)

;; For the copyright sign:
;; Local Variables:
;; coding: emacs-mule
;; End:

;; arch-tag: b4991afb-b6b1-4590-bebe-e076d9d4aee8
;;; copyright.el ends here
