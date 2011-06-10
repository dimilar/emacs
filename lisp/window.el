;;; window.el --- GNU Emacs window commands aside from those written in C

;; Copyright (C) 1985, 1989, 1992-1994, 2000-2011
;;   Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: internal
;; Package: emacs

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Window tree functions.

;;; Code:

(eval-when-compile (require 'cl))

(defmacro save-selected-window (&rest body)
  "Execute BODY, then select the previously selected window.
The value returned is the value of the last form in BODY.

This macro saves and restores the selected window, as well as the
selected window in each frame.  If the previously selected window
is no longer live, then whatever window is selected at the end of
BODY remains selected.  If the previously selected window of some
frame is no longer live at the end of BODY, that frame's selected
window is left alone.

This macro saves and restores the current buffer, since otherwise
its normal operation could make a different buffer current.  The
order of recently selected windows and the buffer list ordering
are not altered by this macro (unless they are altered in BODY)."
  (declare (indent 0) (debug t))
  `(let ((save-selected-window-window (selected-window))
	 ;; It is necessary to save all of these, because calling
	 ;; select-window changes frame-selected-window for whatever
	 ;; frame that window is in.
	 (save-selected-window-alist
	  (mapcar (lambda (frame) (cons frame (frame-selected-window frame)))
		  (frame-list))))
     (save-current-buffer
       (unwind-protect
	   (progn ,@body)
	 (dolist (elt save-selected-window-alist)
	   (and (frame-live-p (car elt))
		(window-live-p (cdr elt))
		(set-frame-selected-window (car elt) (cdr elt) 'norecord)))
	 (when (window-live-p save-selected-window-window)
	   (select-window save-selected-window-window 'norecord))))))

;; The following two functions are like `window-next' and `window-prev'
;; but the WINDOW argument is _not_ optional (so they don't substitute
;; the selected window for nil), and they return nil when WINDOW doesn't
;; have a parent (like a frame's root window or a minibuffer window).
(defsubst window-right (window)
  "Return WINDOW's right sibling.
Return nil if WINDOW is the root window of its frame.  WINDOW can
be any window."
  (and window (window-parent window) (window-next window)))

(defsubst window-left (window)
  "Return WINDOW's left sibling.
Return nil if WINDOW is the root window of its frame.  WINDOW can
be any window."
  (and window (window-parent window) (window-prev window)))

(defsubst window-child (window)
  "Return WINDOW's first child window."
  (or (window-vchild window) (window-hchild window)))

(defun window-child-count (window)
  "Return number of WINDOW's child windows."
  (let ((count 0))
    (when (and (windowp window) (setq window (window-child window)))
      (while window
	(setq count (1+ count))
	(setq window (window-next window))))
    count))

(defun window-last-child (window)
  "Return last child window of WINDOW."
  (when (and (windowp window) (setq window (window-child window)))
    (while (window-next window)
      (setq window (window-next window))))
  window)

(defsubst window-any-p (object)
  "Return t if OBJECT denotes a live or internal window."
  (and (windowp object)
       (or (window-buffer object) (window-child object))
       t))

;; The following four functions should probably go to subr.el.
(defsubst normalize-live-buffer (buffer-or-name)
  "Return buffer specified by BUFFER-OR-NAME.
BUFFER-OR-NAME must be either a buffer or a string naming a live
buffer and defaults to the current buffer."
  (cond
   ((not buffer-or-name)
    (current-buffer))
   ((bufferp buffer-or-name)
    (if (buffer-live-p buffer-or-name)
	buffer-or-name
      (error "Buffer %s is not a live buffer" buffer-or-name)))
   ((get-buffer buffer-or-name))
   (t
    (error "No such buffer %s" buffer-or-name))))

(defsubst normalize-live-frame (frame)
  "Return frame specified by FRAME.
FRAME must be a live frame and defaults to the selected frame."
  (if frame
      (if (frame-live-p frame)
	  frame
	(error "%s is not a live frame" frame))
    (selected-frame)))

(defsubst normalize-any-window (window)
  "Return window specified by WINDOW.
WINDOW must be a window that has not been deleted and defaults to
the selected window."
  (if window
      (if (window-any-p window)
	  window
	(error "%s is not a window" window))
    (selected-window)))

(defsubst normalize-live-window (window)
  "Return live window specified by WINDOW.
WINDOW must be a live window and defaults to the selected one."
  (if window
      (if (and (windowp window) (window-buffer window))
	  window
	(error "%s is not a live window" window))
    (selected-window)))

(defvar ignore-window-parameters nil
  "If non-nil, standard functions ignore window parameters.
The functions currently affected by this are `split-window',
`delete-window', `delete-other-windows' and `other-window'.

An application may bind this to a non-nil value around calls to
these functions to inhibit processing of window parameters.")

(defconst window-safe-min-height 1
  "The absolut minimum number of lines of a window.
Anything less might crash Emacs.")

(defcustom window-min-height 4
  "The minimum number of lines of any window.
The value has to accomodate a mode- or header-line if present.  A
value less than `window-safe-min-height' is ignored.  The value
of this variable is honored when windows are resized or split.

Applications should never rebind this variable.  To resize a
window to a height less than the one specified here, an
application should instead call `resize-window' with a non-nil
IGNORE argument.  In order to have `split-window' make a window
shorter, explictly specify the SIZE argument of that function."
  :type 'integer
  :version "24.1"
  :group 'windows)

(defconst window-safe-min-width 2
  "The absolut minimum number of columns of a window.
Anything less might crash Emacs.")

(defcustom window-min-width 10
  "The minimum number of columns of any window.
The value has to accomodate margins, fringes, or scrollbars if
present.  A value less than `window-safe-min-width' is ignored.
The value of this variable is honored when windows are resized or
split.

Applications should never rebind this variable.  To resize a
window to a width less than the one specified here, an
application should instead call `resize-window' with a non-nil
IGNORE argument.  In order to have `split-window' make a window
narrower, explictly specify the SIZE argument of that function."
  :type 'integer
  :version "24.1"
  :group 'windows)

(defun window-iso-combination-p (&optional window horizontal)
  "If WINDOW is a vertical combination return WINDOW's first child.
WINDOW can be any window and defaults to the selected one.
Optional argument HORIZONTAL non-nil means return WINDOW's first
child if WINDOW is a horizontal combination."
  (setq window (normalize-any-window window))
  (if horizontal
      (window-hchild window)
    (window-vchild window)))

(defsubst window-iso-combined-p (&optional window horizontal)
  "Return non-nil if and only if WINDOW is vertically combined.
WINDOW can be any window and defaults to the selected one.
Optional argument HORIZONTAL non-nil means return non-nil if and
only if WINDOW is horizontally combined."
  (setq window (normalize-any-window window))
  (let ((parent (window-parent window)))
    (and parent (window-iso-combination-p parent horizontal))))

(defun window-iso-combinations (&optional window horizontal)
  "Return largest number of vertically arranged subwindows of WINDOW.
WINDOW can be any window and defaults to the selected one.
Optional argument HORIZONTAL non-nil means to return the largest
number of horizontally arranged subwindows of WINDOW."
  (setq window (normalize-any-window window))
  (cond
   ((window-live-p window)
    ;; If WINDOW is live, return 1.
    1)
   ((window-iso-combination-p window horizontal)
    ;; If WINDOW is iso-combined, return the sum of the values for all
    ;; subwindows of WINDOW.
    (let ((child (window-child window))
	  (count 0))
      (while child
	(setq count
	      (+ (window-iso-combinations child horizontal)
		 count))
	(setq child (window-right child)))
      count))
   (t
    ;; If WINDOW is not iso-combined, return the maximum value of any
    ;; subwindow of WINDOW.
    (let ((child (window-child window))
	  (count 1))
      (while child
	(setq count
	      (max (window-iso-combinations child horizontal)
		   count))
	(setq child (window-right child)))
      count))))

(defun walk-window-tree-1 (proc walk-window-tree-window any &optional sub-only)
  "Helper function for `walk-window-tree' and `walk-window-subtree'."
  (let (walk-window-tree-buffer)
    (while walk-window-tree-window
      (setq walk-window-tree-buffer
	    (window-buffer walk-window-tree-window))
      (when (or walk-window-tree-buffer any)
	(funcall proc walk-window-tree-window))
      (unless walk-window-tree-buffer
	(walk-window-tree-1
	 proc (window-hchild walk-window-tree-window) any)
	(walk-window-tree-1
	 proc (window-vchild walk-window-tree-window) any))
      (if sub-only
	  (setq walk-window-tree-window nil)
	(setq walk-window-tree-window
	      (window-right walk-window-tree-window))))))

(defun walk-window-tree (proc &optional frame any)
  "Run function PROC on each live window of FRAME.
PROC must be a function with one argument - a window.  FRAME must
be a live frame and defaults to the selected one.  ANY, if
non-nil means to run PROC on all live and internal windows of
FRAME.

This function performs a pre-order, depth-first traversal of the
window tree.  If PROC changes the window tree, the result is
unpredictable."
  (let ((walk-window-tree-frame (normalize-live-frame frame)))
    (walk-window-tree-1
     proc (frame-root-window walk-window-tree-frame) any)))

(defun walk-window-subtree (proc &optional window any)
  "Run function PROC on each live subwindow of WINDOW.
WINDOW defaults to the selected window.  PROC must be a function
with one argument - a window.  ANY, if non-nil means to run PROC
on all live and internal subwindows of WINDOW.

This function performs a pre-order, depth-first traversal of the
window tree rooted at WINDOW.  If PROC changes that window tree,
the result is unpredictable."
  (setq window (normalize-any-window window))
  (walk-window-tree-1 proc window any t))

(defun windows-with-parameter (parameter &optional value frame any values)
  "Return a list of all windows on FRAME with PARAMETER non-nil.
FRAME defaults to the selected frame.  Optional argument VALUE
non-nil means only return windows whose window-parameter value of
PARAMETER equals VALUE \(comparison is done using `equal').
Optional argument ANY non-nil means consider internal windows
too.  Optional argument VALUES non-nil means return a list of cons
cells whose car is the value of the parameter and whose cdr is
the window."
  (let (this-value windows)
    (walk-window-tree
     (lambda (window)
       (when (and (setq this-value (window-parameter window parameter))
		  (or (not value) (or (equal value this-value))))
	   (setq windows
		 (if values
		     (cons (cons this-value window) windows)
		   (cons window windows)))))
     frame any)

    (nreverse windows)))

(defun window-with-parameter (parameter &optional value frame any)
  "Return first window on FRAME with PARAMETER non-nil.
FRAME defaults to the selected frame.  Optional argument VALUE
non-nil means only return a window whose window-parameter value
for PARAMETER equals VALUE \(comparison is done with `equal').
Optional argument ANY non-nil means consider internal windows
too."
  (let (this-value windows)
    (catch 'found
      (walk-window-tree
       (lambda (window)
	 (when (and (setq this-value (window-parameter window parameter))
		    (or (not value) (equal value this-value)))
	   (throw 'found window)))
       frame any))))

;;; Atomic windows.
(defun window-atom-root (&optional window)
  "Return root of atomic window WINDOW is a part of.
WINDOW can be any window and defaults to the selected one.
Return nil if WINDOW is not part of a atomic window."
  (setq window (normalize-any-window window))
  (let (root)
    (while (and window (window-parameter window 'window-atom))
      (setq root window)
      (setq window (window-parent window)))
    root))

(defun make-window-atom (window)
  "Make WINDOW an atomic window.
WINDOW must be an internal window.  Return WINDOW."
  (if (not (window-child window))
      (error "Window %s is not an internal window" window)
    (walk-window-subtree
     (lambda (window)
       (set-window-parameter window 'window-atom t))
     window t)
    window))

(defun window-atom-check-1 (window)
  "Subroutine of `window-atom-check'."
  (when window
    (if (window-parameter window 'window-atom)
	(let ((count 0))
	  (when (or (catch 'reset
		      (walk-window-subtree
		       (lambda (window)
			 (if (window-parameter window 'window-atom)
			     (setq count (1+ count))
			   (throw 'reset t)))
		       window t))
		    ;; count >= 1 must hold here.  If there's no other
		    ;; window around dissolve this atomic window.
		    (= count 1))
	    ;; Dissolve atomic window.
	    (walk-window-subtree
	     (lambda (window)
	       (set-window-parameter window 'window-atom nil))
	     window t)))
      ;; Check children.
      (unless (window-buffer window)
	(window-atom-check-1 (window-hchild window))
	(window-atom-check-1 (window-vchild window))))
    ;; Check right sibling
    (window-atom-check-1 (window-right window))))

(defun window-atom-check (&optional frame)
  "Check atomicity of all windows on FRAME.
FRAME defaults to the selected frame.  If an atomic window is
wrongly configured, reset the atomicity of all its subwindows to
nil.  An atomic window is wrongly configured if it has no
subwindows or one of its subwindows is not atomic."
  (window-atom-check-1 (frame-root-window frame)))

;; Side windows.
(defvar window-sides '(left top right bottom)
  "Window sides.")

(defcustom window-sides-vertical nil
  "If non-nil, left and right side windows are full height.
Otherwise, top and bottom side windows are full width."
  :type 'boolean
  :group 'windows
  :version "24.1")

(defcustom window-sides-slots '(nil nil nil nil)
  "Maximum number of side window slots.
The value is a list of four elements specifying the number of
side window slots on \(in this order) the left, top, right and
bottom side of each frame.  If an element is a number, this means
to display at most that many side windows on the corresponding
side.  If an element is nil, this means there's no bound on the
number of slots on that side."
  :risky t
  :type
  '(list
    :value (nil nil nil nil)
    (choice
     :tag "Left"
     :help-echo "Maximum slots of left side window."
     :value nil
     :format "%[Left%] %v\n"
     (const :tag "Unlimited" :format "%t" nil)
     (integer :tag "Number" :value 2 :size 5))
    (choice
     :tag "Top"
     :help-echo "Maximum slots of top side window."
     :value nil
     :format "%[Top%] %v\n"
     (const :tag "Unlimited" :format "%t" nil)
     (integer :tag "Number" :value 3 :size 5))
    (choice
     :tag "Right"
     :help-echo "Maximum slots of right side window."
     :value nil
     :format "%[Right%] %v\n"
     (const :tag "Unlimited" :format "%t" nil)
     (integer :tag "Number" :value 2 :size 5))
    (choice
     :tag "Bottom"
     :help-echo "Maximum slots of bottom side window."
     :value nil
     :format "%[Bottom%] %v\n"
     (const :tag "Unlimited" :format "%t" nil)
     (integer :tag "Number" :value 3 :size 5)))
  :group 'windows)

(defun window-side-check (&optional frame)
  "Check the window-side parameter of all windows on FRAME.
FRAME defaults to the selected frame.  If the configuration is
invalid, reset all window-side parameters to nil.

A valid configuration has to preserve the following invariant:

- If a window has a non-nil window-side parameter, it must have a
  parent window and the parent window's window-side parameter
  must be either nil or the same as for window.

- If windows with non-nil window-side parameters exist, there
  must be at most one window of each side and non-side with a
  parent whose window-side parameter is nil and there must be no
  leaf window whose window-side parameter is nil."
  (let (normal none left top right bottom
	side parent parent-side code)
    (when (or (catch 'reset
		(walk-window-tree
		 (lambda (window)
		   (setq side (window-parameter window 'window-side))
		   (setq parent (window-parent window))
		   (setq parent-side
			 (and parent (window-parameter parent 'window-side)))
		   ;; The following `cond' seems a bit tedious, but I'd
		   ;; rather stick to using just the stack.
		   (cond
		    (parent-side
		     (when (not (eq parent-side side))
		       ;; A parent whose window-side is non-nil must
		       ;; have a child with the same window-side.
		       (throw 'reset t)))
		    ;; Now check that there's more than one main window
		    ;; for any of none, left, top, right and bottom.
		    ((eq side 'none)
		     (if none
			 (throw 'reset t)
		       (setq none t)))
		    ((eq side 'left)
		     (if left
			 (throw 'reset t)
		       (setq left t)))
		    ((eq side 'top)
		     (if top
			 (throw 'reset t)
		       (setq top t)))
		    ((eq side 'right)
		     (if right
			 (throw 'reset t)
		       (setq right t)))
		    ((eq side 'bottom)
		     (if bottom
			 (throw 'reset t)
		       (setq bottom t)))
		    ((window-buffer window)
		     ;; A leaf window without window-side parameter,
		     ;; record its existence.
		     (setq normal t))))
		 frame t))
	      (if none
		  ;; At least one non-side window exists, so there must
		  ;; be at least one side-window and no normal window.
		  (or (not (or left top right bottom)) normal)
		;; No non-side window exists, so there must be no side
		;; window either.
		(or left top right bottom)))
      (walk-window-tree
       (lambda (window)
	 (set-window-parameter window 'window-side nil))
       frame t))))

(defun window-check (&optional frame)
  "Check atomic and side windows on FRAME.
FRAME defaults to the selected frame."
  (window-side-check frame)
  (window-atom-check frame))

;;; Window sizes.
(defvar window-size-fixed nil
  "Non-nil in a buffer means windows displaying the buffer are fixed-size.
If the value is `height', then only the window's height is fixed.
If the value is `width', then only the window's width is fixed.
Any other non-nil value fixes both the width and the height.

Emacs won't change the size of any window displaying that buffer,
unless it has no other choice \(like when deleting a neighboring
window).")
(make-variable-buffer-local 'window-size-fixed)

(defsubst window-size-ignore (window ignore)
  "Return non-nil if IGNORE says to ignore size restrictions for WINDOW."
  (if (window-any-p ignore) (eq window ignore) ignore))

(defun window-min-size (&optional window horizontal ignore)
  "Return the minimum number of lines of WINDOW.
WINDOW can be an arbitrary window and defaults to the selected
one.  Optional argument HORIZONTAL non-nil means return the
minimum number of columns of WINDOW.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE equal `safe' means live
windows may get as small as `window-safe-min-height' lines and
`window-safe-min-width' columns.  IGNORE a window means ignore
restrictions for that window only."
  (window-min-size-1
   (normalize-any-window window) horizontal ignore))

(defun window-min-size-1 (window horizontal ignore)
  "Internal function of `window-min-size'."
  (let ((sub (window-child window)))
    (if sub
	(let ((value 0))
	  ;; WINDOW is an internal window.
	  (if (window-iso-combined-p sub horizontal)
	      ;; The minimum size of an iso-combination is the sum of
	      ;; the minimum sizes of its subwindows.
	      (while sub
		(setq value (+ value
			       (window-min-size-1 sub horizontal ignore)))
		(setq sub (window-right sub)))
	    ;; The minimum size of an ortho-combination is the maximum of
	    ;; the minimum sizes of its subwindows.
	    (while sub
	      (setq value (max value
			       (window-min-size-1 sub horizontal ignore)))
	      (setq sub (window-right sub))))
	  value)
      (with-current-buffer (window-buffer window)
	(cond
	 ((and (not (window-size-ignore window ignore))
	       (window-size-fixed-p window horizontal))
	  ;; The minimum size of a fixed size window is its size.
	  (window-total-size window horizontal))
	 ((or (eq ignore 'safe) (eq ignore window))
	  ;; If IGNORE equals `safe' or WINDOW return the safe values.
	  (if horizontal window-safe-min-width window-safe-min-height))
	 (horizontal
	  ;; For the minimum width of a window take fringes and
	  ;; scroll-bars into account.  This is questionable and should
	  ;; be removed as soon as we are able to split (and resize)
	  ;; windows such that the new (or resized) windows can get a
	  ;; size less than the user-specified `window-min-height' and
	  ;; `window-min-width'.
	  (let ((frame (window-frame window))
		(fringes (window-fringes window))
		(scroll-bars (window-scroll-bars window)))
	    (max
	     (+ window-safe-min-width
		(ceiling (car fringes) (frame-char-width frame))
		(ceiling (cadr fringes) (frame-char-width frame))
		(cond
		 ((memq (nth 2 scroll-bars) '(left right))
		  (nth 1 scroll-bars))
		 ((memq (frame-parameter frame 'vertical-scroll-bars)
			'(left right))
		  (ceiling (or (frame-parameter frame 'scroll-bar-width) 14)
			   (frame-char-width)))
		 (t 0)))
	     (if (and (not (window-size-ignore window ignore))
		      (numberp window-min-width))
		 window-min-width
	       0))))
	 (t
	  ;; For the minimum height of a window take any mode- or
	  ;; header-line into account.
	  (max (+ window-safe-min-height
		  (if header-line-format 1 0)
		  (if mode-line-format 1 0))
	       (if (and (not (window-size-ignore window ignore))
			(numberp window-min-height))
		   window-min-height
		 0))))))))

(defun window-sizable (window delta &optional horizontal ignore)
  "Return DELTA if DELTA lines can be added to WINDOW.
Optional argument HORIZONTAL non-nil means return DELTA if DELTA
columns can be added to WINDOW.  A return value of zero means
that no lines (or columns) can be added to WINDOW.

This function looks only at WINDOW and its subwindows.  The
function `window-resizable' looks at other windows as well.

DELTA positive means WINDOW shall be enlarged by DELTA lines or
columns.  If WINDOW cannot be enlarged by DELTA lines or columns
return the maximum value in the range 0..DELTA by which WINDOW
can be enlarged.

DELTA negative means WINDOW shall be shrunk by -DELTA lines or
columns.  If WINDOW cannot be shrunk by -DELTA lines or columns,
return the minimum value in the range DELTA..0 by which WINDOW
can be shrunk.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE equal `safe' means live
windows may get as small as `window-safe-min-height' lines and
`window-safe-min-width' columns.  IGNORE any window means ignore
restrictions for that window only."
  (setq window (normalize-any-window window))
  (cond
   ((< delta 0)
    (max (- (window-min-size window horizontal ignore)
	    (window-total-size window horizontal))
	 delta))
   ((window-size-ignore window ignore)
    delta)
   ((> delta 0)
    (if (window-size-fixed-p window horizontal)
	0
      delta))
   (t 0)))

(defsubst window-sizable-p (window delta &optional horizontal ignore)
  "Return t if WINDOW can be resized by DELTA lines.
For the meaning of the arguments of this function see the
doc-string of `window-sizable'."
  (setq window (normalize-any-window window))
  (if (> delta 0)
      (>= (window-sizable window delta horizontal ignore) delta)
    (<= (window-sizable window delta horizontal ignore) delta)))

(defun window-size-fixed-1 (window horizontal)
  "Internal function for `window-size-fixed-p'."
  (let ((sub (window-child window)))
    (catch 'fixed
      (if sub
	  ;; WINDOW is an internal window.
	  (if (window-iso-combined-p sub horizontal)
	      ;; An iso-combination is fixed size if all its subwindows
	      ;; are fixed-size.
	      (progn
		(while sub
		  (unless (window-size-fixed-1 sub horizontal)
		    ;; We found a non-fixed-size subwindow, so WINDOW's
		    ;; size is not fixed.
		    (throw 'fixed nil))
		  (setq sub (window-right sub)))
		;; All subwindows are fixed-size, so WINDOW's size is
		;; fixed.
		(throw 'fixed t))
	    ;; An ortho-combination is fixed-size if at least one of its
	    ;; subwindows is fixed-size.
	    (while sub
	      (when (window-size-fixed-1 sub horizontal)
		;; We found a fixed-size subwindow, so WINDOW's size is
		;; fixed.
		(throw 'fixed t))
	      (setq sub (window-right sub))))
	;; WINDOW is a live window.
	(with-current-buffer (window-buffer window)
	  (if horizontal
	      (memq window-size-fixed '(width t))
	    (memq window-size-fixed '(height t))))))))

(defun window-size-fixed-p (&optional window horizontal)
  "Return non-nil if WINDOW's height is fixed.
WINDOW can be an arbitrary window and defaults to the selected
window.  Optional argument HORIZONTAL non-nil means return
non-nil if WINDOW's width is fixed.

If this function returns nil, this does not necessarily mean that
WINDOW can be resized in the desired direction.  The functions
`window-resizable' and `window-resizable-p' will tell that."
  (window-size-fixed-1
   (normalize-any-window window) horizontal))

(defun window-min-delta-1 (window delta &optional horizontal ignore trail noup)
  "Internal function for `window-min-delta'."
  (if (not (window-parent window))
      ;; If we can't go up, return zero.
      0
    ;; Else try to find a non-fixed-size sibling of WINDOW.
    (let* ((parent (window-parent window))
	   (sub (window-child parent)))
      (catch 'done
	(if (window-iso-combined-p sub horizontal)
	    ;; In an iso-combination throw DELTA if we find at least one
	    ;; subwindow and that subwindow is either not of fixed-size
	    ;; or we can ignore fixed-sizeness.
	    (let ((skip (eq trail 'after)))
	      (while sub
		(cond
		 ((eq sub window)
		  (setq skip (eq trail 'before)))
		 (skip)
		 ((and (not (window-size-ignore window ignore))
		       (window-size-fixed-p sub horizontal)))
		 (t
		  ;; We found a non-fixed-size subwindow.
		  (throw 'done delta)))
		(setq sub (window-right sub))))
	  ;; In an ortho-combination set DELTA to the minimum value by
	  ;; which other subwindows can shrink.
	  (while sub
	    (unless (eq sub window)
	      (setq delta
		    (min delta
			 (- (window-total-size sub horizontal)
			    (window-min-size sub horizontal ignore)))))
	    (setq sub (window-right sub))))
	(if noup
	    delta
	  (window-min-delta-1 parent delta horizontal ignore trail))))))

(defun window-min-delta (&optional window horizontal ignore trail noup nodown)
  "Return number of lines by which WINDOW can be shrunk.
WINDOW can be an arbitrary window and defaults to the selected
window.  Return zero if WINDOW cannot be shrunk.

Optional argument HORIZONTAL non-nil means return number of
columns by which WINDOW can be shrunk.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE a window means ignore
restrictions for that window only.  IGNORE equal `safe' means
live windows may get as small as `window-safe-min-height' lines
and `window-safe-min-width' columns.

Optional argument TRAIL `before' means only windows to the left
of or above WINDOW can be enlarged.  Optional argument TRAIL
`after' means only windows to the right of or below WINDOW can be
enlarged.

Optional argument NOUP non-nil means don't go up in the window
tree but try to enlarge windows within WINDOW's combination only.

Optional argument NODOWN non-nil means don't check whether WINDOW
itself \(and its subwindows) can be shrunk; check only whether at
least one other windows can be enlarged appropriately."
  (setq window (normalize-any-window window))
  (let ((size (window-total-size window horizontal))
	(minimum (window-min-size window horizontal ignore)))
    (cond
     (nodown
      ;; If NODOWN is t, try to recover the entire size of WINDOW.
      (window-min-delta-1 window size horizontal ignore trail noup))
     ((= size minimum)
      ;; If NODOWN is nil and WINDOW's size is already at its minimum,
      ;; there's nothing to recover.
      0)
     (t
      ;; Otherwise, try to recover whatever WINDOW is larger than its
      ;; minimum size.
      (window-min-delta-1
       window (- size minimum) horizontal ignore trail noup)))))

(defun window-max-delta-1 (window delta &optional horizontal ignore trail noup)
  "Internal function of `window-max-delta'."
  (if (not (window-parent window))
      ;; Can't go up.  Return DELTA.
      delta
    (let* ((parent (window-parent window))
	   (sub (window-child parent)))
      (catch 'fixed
	(if (window-iso-combined-p sub horizontal)
	    ;; For an iso-combination calculate how much we can get from
	    ;; other subwindows.
	    (let ((skip (eq trail 'after)))
	      (while sub
		(cond
		 ((eq sub window)
		  (setq skip (eq trail 'before)))
		 (skip)
		 (t
		  (setq delta
			(+ delta
			   (- (window-total-size sub horizontal)
			      (window-min-size sub horizontal ignore))))))
		(setq sub (window-right sub))))
	  ;; For an ortho-combination throw DELTA when at least one
	  ;; subwindow is fixed-size.
	  (while sub
	    (when (and (not (eq sub window))
		       (not (window-size-ignore sub ignore))
		       (window-size-fixed-p sub horizontal))
	      (throw 'fixed delta))
	    (setq sub (window-right sub))))
	(if noup
	    ;; When NOUP is nil, DELTA is all we can get.
	    delta
	  ;; Else try with parent of WINDOW, passing the DELTA we
	  ;; recovered so far.
	  (window-max-delta-1 parent delta horizontal ignore trail))))))

(defun window-max-delta (&optional window horizontal ignore trail noup nodown)
  "Return maximum number of lines WINDOW by which WINDOW can be enlarged.
WINDOW can be an arbitrary window and defaults to the selected
window.  The return value is zero if WINDOW cannot be enlarged.

Optional argument HORIZONTAL non-nil means return maximum number
of columns by which WINDOW can be enlarged.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE a window means ignore
restrictions for that window only.  IGNORE equal `safe' means
live windows may get as small as `window-safe-min-height' lines
and `window-safe-min-width' columns.

Optional argument TRAIL `before' means only windows to the left
of or below WINDOW can be shrunk.  Optional argument TRAIL
`after' means only windows to the right of or above WINDOW can be
shrunk.

Optional argument NOUP non-nil means don't go up in the window
tree but try to obtain the entire space from windows within
WINDOW's combination.

Optional argument NODOWN non-nil means do not check whether
WINDOW itself \(and its subwindows) can be enlarged; check only
whether other windows can be shrunk appropriately."
  (setq window (normalize-any-window window))
  (if (and (not (window-size-ignore window ignore))
	   (not nodown) (window-size-fixed-p window horizontal))
      ;; With IGNORE and NOWDON nil return zero if WINDOW has fixed
      ;; size.
      0
    ;; WINDOW has no fixed size.
    (window-max-delta-1 window 0 horizontal ignore trail noup)))

;; Make NOUP also inhibit the min-size check.
(defun window-resizable (window delta &optional horizontal ignore trail noup nodown)
  "Return DELTA if WINDOW can be resized vertically by DELTA lines.
Optional argument HORIZONTAL non-nil means return DELTA if WINDOW
can be resized horizontally by DELTA columns.  A return value of
zero means that WINDOW is not resizable.

DELTA positive means WINDOW shall be enlarged by DELTA lines or
columns.  If WINDOW cannot be enlarged by DELTA lines or columns
return the maximum value in the range 0..DELTA by which WINDOW
can be enlarged.

DELTA negative means WINDOW shall be shrunk by -DELTA lines or
columns.  If WINDOW cannot be shrunk by -DELTA lines or columns,
return the minimum value in the range DELTA..0 that can be used
for shrinking WINDOW.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE a window means ignore
restrictions for that window only.  IGNORE equal `safe' means
live windows may get as small as `window-safe-min-height' lines
and `window-safe-min-width' columns.

Optional argument TRAIL `before' means only windows to the left
of or below WINDOW can be shrunk.  Optional argument TRAIL
`after' means only windows to the right of or above WINDOW can be
shrunk.

Optional argument NOUP non-nil means don't go up in the window
tree but try to distribute the space among the other windows
within WINDOW's combination.

Optional argument NODOWN non-nil means don't check whether WINDOW
and its subwindows can be resized."
  (setq window (normalize-any-window window))
  (cond
   ((< delta 0)
    (max (- (window-min-delta window horizontal ignore trail noup nodown))
	 delta))
   ((> delta 0)
    (min (window-max-delta window horizontal ignore trail noup nodown)
	 delta))
   (t 0)))

(defun window-resizable-p (window delta &optional horizontal ignore trail noup nodown)
  "Return t if WINDOW can be resized vertically by DELTA lines.
For the meaning of the arguments of this function see the
doc-string of `window-resizable'."
  (setq window (normalize-any-window window))
  (if (> delta 0)
      (>= (window-resizable window delta horizontal ignore trail noup nodown)
	  delta)
    (<= (window-resizable window delta horizontal ignore trail noup nodown)
	delta)))

(defsubst window-total-height (&optional window)
  "Return the total number of lines of WINDOW.
WINDOW can be any window and defaults to the selected one.  The
return value includes WINDOW's mode line and header line, if any.
If WINDOW is internal the return value is the sum of the total
number of lines of WINDOW's child windows if these are vertically
combined and the height of WINDOW's first child otherwise.

Note: This function does not take into account the value of
`line-spacing' when calculating the number of lines in WINDOW."
  (window-total-size window))

;; Eventually we should make `window-height' obsolete.
(defalias 'window-height 'window-total-height)

;; See discussion in bug#4543.
(defsubst window-full-height-p (&optional window)
  "Return t if WINDOW is as high as the containing frame.
More precisely, return t if and only if the total height of
WINDOW equals the total height of the root window of WINDOW's
frame.  WINDOW can be any window and defaults to the selected
one."
  (setq window (normalize-any-window window))
  (= (window-total-size window)
     (window-total-size (frame-root-window window))))

(defsubst window-total-width (&optional window)
  "Return the total number of columns of WINDOW.
WINDOW can be any window and defaults to the selected one.  The
return value includes any vertical dividers or scrollbars of
WINDOW.  If WINDOW is internal, the return value is the sum of
the total number of columns of WINDOW's child windows if these
are horizontally combined and the width of WINDOW's first child
otherwise."
  (window-total-size window t))

(defsubst window-full-width-p (&optional window)
  "Return t if WINDOW is as wide as the containing frame.
More precisely, return t if and only if the total width of WINDOW
equals the total width of the root window of WINDOW's frame.
WINDOW can be any window and defaults to the selected one."
  (setq window (normalize-any-window window))
  (= (window-total-size window t)
     (window-total-size (frame-root-window window) t)))

(defsubst window-body-height (&optional window)
  "Return the number of lines of WINDOW's body.
WINDOW must be a live window and defaults to the selected one.

The return value does not include WINDOW's mode line and header
line, if any.  If a line at the bottom of the window is only
partially visible, that line is included in the return value.  If
you do not want to include a partially visible bottom line in the
return value, use `window-text-height' instead."
  (window-body-size window))

(defsubst window-body-width (&optional window)
  "Return the number of columns of WINDOW's body.
WINDOW must be a live window and defaults to the selected one.

The return value does not include any vertical dividers or scroll
bars owned by WINDOW.  On a window-system the return value does
not include the number of columns used for WINDOW's fringes or
display margins either."
  (window-body-size window t))

;; Eventually we should make `window-height' obsolete.
(defalias 'window-width 'window-body-width)

(defun window-current-scroll-bars (&optional window)
  "Return the current scroll bar settings for WINDOW.
WINDOW must be a live window and defaults to the selected one.

The return value is a cons cell (VERTICAL . HORIZONTAL) where
VERTICAL specifies the current location of the vertical scroll
bars (`left', `right', or nil), and HORIZONTAL specifies the
current location of the horizontal scroll bars (`top', `bottom',
or nil).

Unlike `window-scroll-bars', this function reports the scroll bar
type actually used, once frame defaults and `scroll-bar-mode' are
taken into account."
  (setq window (normalize-live-window window))
  (let ((vert (nth 2 (window-scroll-bars window)))
	(hor nil))
    (when (or (eq vert t) (eq hor t))
      (let ((fcsb (frame-current-scroll-bars (window-frame window))))
	(if (eq vert t)
	    (setq vert (car fcsb)))
	(if (eq hor t)
	    (setq hor (cdr fcsb)))))
    (cons vert hor)))

(defun walk-windows (proc &optional minibuf all-frames)
  "Cycle through all live windows, calling PROC for each one.
PROC must specify a function with a window as its sole argument.
The optional arguments MINIBUF and ALL-FRAMES specify the set of
windows to include in the walk.

MINIBUF t means include the minibuffer window even if the
minibuffer is not active.  MINIBUF nil or omitted means include
the minibuffer window only if the minibuffer is active.  Any
other value means do not include the minibuffer window even if
the minibuffer is active.

ALL-FRAMES nil or omitted means consider all windows on the
selected frame, plus the minibuffer window if specified by the
MINIBUF argument.  If the minibuffer counts, consider all windows
on all frames that share that minibuffer too.  The following
non-nil values of ALL-FRAMES have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Anything else means consider all windows on the selected frame
and no others.

This function changes neither the order of recently selected
windows nor the buffer list."
  ;; If we start from the minibuffer window, don't fail to come
  ;; back to it.
  (when (window-minibuffer-p (selected-window))
    (setq minibuf t))
  ;; Make sure to not mess up the order of recently selected
  ;; windows.  Use `save-selected-window' and `select-window'
  ;; with second argument non-nil for this purpose.
  (save-selected-window
    (when (framep all-frames)
      (select-window (frame-first-window all-frames) 'norecord))
    (dolist (walk-windows-window (window-list-1 nil minibuf all-frames))
      (funcall proc walk-windows-window))))

(defun window-in-direction-2 (window posn &optional horizontal)
  "Support function for `window-in-direction'."
  (if horizontal
      (let ((top (window-top-line window)))
	(if (> top posn)
	    (- top posn)
	  (- posn top (window-total-height window))))
    (let ((left (window-left-column window)))
      (if (> left posn)
	  (- left posn)
	(- posn left (window-total-width window))))))

(defun window-in-direction (direction &optional window ignore)
  "Return window in DIRECTION as seen from WINDOW.
DIRECTION must be one of `above', `below', `left' or `right'.
WINDOW must be a live window and defaults to the selected one.
IGNORE, when non-nil means a window can be returned even if its
`no-other-window' parameter is non-nil."
  (setq window (normalize-live-window window))
  (unless (memq direction '(above below left right))
    (error "Wrong direction %s" direction))
  (let* ((frame (window-frame window))
	 (hor (memq direction '(left right)))
	 (first (if hor
		    (window-left-column window)
		  (window-top-line window)))
	 (last (+ first (if hor
			    (window-total-width window)
			  (window-total-height window))))
	 (posn-cons (nth 6 (posn-at-point (window-point window) window)))
	 ;; The column / row value of `posn-at-point' can be nil for the
	 ;; mini-window, guard against that.
	 (posn (if hor
		   (+ (or (cdr posn-cons) 1) (window-top-line window))
		 (+ (or (car posn-cons) 1) (window-left-column window))))
	 (best-edge
	  (cond
	   ((eq direction 'below) (frame-height frame))
	   ((eq direction 'right) (frame-width frame))
	   (t -1)))
	 (best-edge-2 best-edge)
	 (best-diff-2 (if hor (frame-height frame) (frame-width frame)))
	 best best-2 best-diff-2-new)
    (walk-window-tree
     (lambda (w)
       (let* ((w-top (window-top-line w))
	      (w-left (window-left-column w)))
	 (cond
	  ((or (eq window w)
	       ;; Ignore ourselves.
	       (and (window-parameter w 'no-other-window)
		    ;; Ignore W unless IGNORE is non-nil.
		    (not ignore))))
	  (hor
	   (cond
	    ((and (<= w-top posn)
		  (< posn (+ w-top (window-total-height w))))
	     ;; W is to the left or right of WINDOW and covers POSN.
	     (when (or (and (eq direction 'left)
			    (<= w-left first) (> w-left best-edge))
		       (and (eq direction 'right)
			    (>= w-left last) (< w-left best-edge)))
	       (setq best-edge w-left)
	       (setq best w)))
	    ((and (or (and (eq direction 'left)
			   (<= (+ w-left (window-total-width w)) first))
		      (and (eq direction 'right) (<= last w-left)))
		  ;; W is to the left or right of WINDOW but does not
		  ;; cover POSN.
		  (setq best-diff-2-new
			(window-in-direction-2 w posn hor))
		  (or (< best-diff-2-new best-diff-2)
		      (and (= best-diff-2-new best-diff-2)
			   (if (eq direction 'left)
			       (> w-left best-edge-2)
			     (< w-left best-edge-2)))))
	     (setq best-edge-2 w-left)
	     (setq best-diff-2 best-diff-2-new)
	     (setq best-2 w))))
	  (t
	   (cond
	    ((and (<= w-left posn)
		  (< posn (+ w-left (window-total-width w))))
	     ;; W is above or below WINDOW and covers POSN.
	     (when (or (and (eq direction 'above)
			    (<= w-top first) (> w-top best-edge))
		       (and (eq direction 'below)
			    (>= w-top first) (< w-top best-edge)))
	       (setq best-edge w-top)
	       (setq best w)))
	    ((and (or (and (eq direction 'above)
			   (<= (+ w-top (window-total-height w)) first))
		      (and (eq direction 'below) (<= last w-top)))
		  ;; W is above or below WINDOW but does not cover POSN.
		  (setq best-diff-2-new
			(window-in-direction-2 w posn hor))
		  (or (< best-diff-2-new best-diff-2)
		      (and (= best-diff-2-new best-diff-2)
			   (if (eq direction 'above)
			       (> w-top best-edge-2)
			     (< w-top best-edge-2)))))
	     (setq best-edge-2 w-top)
	     (setq best-diff-2 best-diff-2-new)
	     (setq best-2 w)))))))
     (window-frame window))
    (or best best-2)))

(defun get-window-with-predicate (predicate &optional minibuf
					    all-frames default)
  "Return a live window satisfying PREDICATE.
More precisely, cycle through all windows calling the function
PREDICATE on each one of them with the window as its sole
argument.  Return the first window for which PREDICATE returns
non-nil.  If no window satisfies PREDICATE, return DEFAULT.

ALL-FRAMES nil or omitted means consider all windows on the selected
frame, plus the minibuffer window if specified by the MINIBUF
argument.  If the minibuffer counts, consider all windows on all
frames that share that minibuffer too.  The following non-nil
values of ALL-FRAMES have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Anything else means consider all windows on the selected frame
and no others."
  (catch 'found
    (dolist (window (window-list-1 nil minibuf all-frames))
      (when (funcall predicate window)
	(throw 'found window)))
    default))

(defalias 'some-window 'get-window-with-predicate)

(defun get-lru-window (&optional all-frames dedicated)
   "Return the least recently used window on frames specified by ALL-FRAMES.
Return a full-width window if possible.  A minibuffer window is
never a candidate.  A dedicated window is never a candidate
unless DEDICATED is non-nil, so if all windows are dedicated, the
value is nil.  Avoid returning the selected window if possible.

The following non-nil values of the optional argument ALL-FRAMES
have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Any other value of ALL-FRAMES means consider all windows on the
selected frame and no others."
   (let (best-window best-time second-best-window second-best-time time)
    (dolist (window (window-list-1 nil nil all-frames))
      (when (or dedicated (not (window-dedicated-p window)))
	(setq time (window-use-time window))
	(if (or (eq window (selected-window))
		(not (window-full-width-p window)))
	    (when (or (not second-best-time) (< time second-best-time))
	      (setq second-best-time time)
	      (setq second-best-window window))
	  (when (or (not best-time) (< time best-time))
	    (setq best-time time)
	    (setq best-window window)))))
    (or best-window second-best-window)))

(defun get-mru-window (&optional all-frames)
   "Return the most recently used window on frames specified by ALL-FRAMES.
Do not return a minibuffer window.

The following non-nil values of the optional argument ALL-FRAMES
have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Any other value of ALL-FRAMES means consider all windows on the
selected frame and no others."
   (let (best-window best-time time)
    (dolist (window (window-list-1 nil nil all-frames))
      (setq time (window-use-time window))
      (when (or (not best-time) (> time best-time))
	(setq best-time time)
	(setq best-window window)))
    best-window))

(defun get-largest-window (&optional all-frames dedicated)
  "Return the largest window on frames specified by ALL-FRAMES.
A minibuffer window is never a candidate.  A dedicated window is
never a candidate unless DEDICATED is non-nil, so if all windows
are dedicated, the value is nil.

The following non-nil values of the optional argument ALL-FRAMES
have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Any other value of ALL-FRAMES means consider all windows on the
selected frame and no others."
  (let ((best-size 0)
	best-window size)
    (dolist (window (window-list-1 nil nil all-frames))
      (when (or dedicated (not (window-dedicated-p window)))
	(setq size (* (window-total-size window)
		      (window-total-size window t)))
	(when (> size best-size)
	  (setq best-size size)
	  (setq best-window window))))
    best-window))

(defun get-buffer-window-list (&optional buffer-or-name minibuf all-frames)
  "Return list of all windows displaying BUFFER-OR-NAME, or nil if none.
BUFFER-OR-NAME may be a buffer or the name of an existing buffer
and defaults to the current buffer.

Any windows showing BUFFER-OR-NAME on the selected frame are listed
first.

MINIBUF t means include the minibuffer window even if the
minibuffer is not active.  MINIBUF nil or omitted means include
the minibuffer window only if the minibuffer is active.  Any
other value means do not include the minibuffer window even if
the minibuffer is active.

ALL-FRAMES nil or omitted means consider all windows on the
selected frame, plus the minibuffer window if specified by the
MINIBUF argument.  If the minibuffer counts, consider all windows
on all frames that share that minibuffer too.  The following
non-nil values of ALL-FRAMES have special meanings:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Anything else means consider all windows on the selected frame
and no others."
  (let ((buffer (normalize-live-buffer buffer-or-name))
	windows)
    (dolist (window (window-list-1 (frame-first-window) minibuf all-frames))
      (when (eq (window-buffer window) buffer)
	(setq windows (cons window windows))))
    (nreverse windows)))

(defun minibuffer-window-active-p (window)
  "Return t if WINDOW is the currently active minibuffer window."
  (eq window (active-minibuffer-window)))

(defun count-windows (&optional minibuf)
   "Return the number of live windows on the selected frame.
The optional argument MINIBUF specifies whether the minibuffer
window shall be counted.  See `walk-windows' for the precise
meaning of this argument."
   (length (window-list-1 nil minibuf)))

;;; Resizing windows.
(defun resize-window-reset (&optional frame horizontal)
  "Reset resize values for all windows on FRAME.
FRAME defaults to the selected frame.

This function stores the current value of `window-total-size' applied
with argument HORIZONTAL in the new total size of all windows on
FRAME.  It also resets the new normal size of each of these
windows."
  (resize-window-reset-1
   (frame-root-window (normalize-live-frame frame)) horizontal))

(defun resize-window-reset-1 (window horizontal)
  "Internal function of `resize-window-reset'."
  ;; Register old size in the new total size.
  (set-window-new-total window (window-total-size window horizontal))
  ;; Reset new normal size.
  (set-window-new-normal window)
  (when (window-child window)
    (resize-window-reset-1 (window-child window) horizontal))
  (when (window-right window)
    (resize-window-reset-1 (window-right window) horizontal)))

;; The following routine is used to manually resize the minibuffer
;; window and is currently used, for example, by ispell.el.
(defun resize-mini-window (window delta)
  "Resize minibuffer window WINDOW by DELTA lines.
If WINDOW cannot be resized by DELTA lines make it as large \(or
as small) as possible but don't signal an error."
  (when (window-minibuffer-p window)
    (let* ((frame (window-frame window))
	   (root (frame-root-window frame))
	   (height (window-total-size window))
	   (min-delta
	    (- (window-total-size root)
	       (window-min-size root))))
      ;; Sanitize DELTA.
      (cond
       ((<= (+ height delta) 0)
	(setq delta (- (- height 1))))
       ((> delta min-delta)
	(setq delta min-delta)))

      ;; Resize now.
      (resize-window-reset frame)
      ;; Ideally we should be able to resize just the last subwindow of
      ;; root here.  See the comment in `resize-root-window-vertically'
      ;; for why we do not do that.
      (resize-this-window root (- delta) nil nil t)
      (set-window-new-total window (+ height delta))
      ;; The following routine catches the case where we want to resize
      ;; a minibuffer-only frame.
      (resize-mini-window-internal window))))

(defun resize-window (window delta &optional horizontal ignore)
  "Resize WINDOW vertically by DELTA lines.
WINDOW can be an arbitrary window and defaults to the selected
one.  An attempt to resize the root window of a frame will raise
an error though.

DELTA a positive number means WINDOW shall be enlarged by DELTA
lines.  DELTA negative means WINDOW shall be shrunk by -DELTA
lines.

Optional argument HORIZONTAL non-nil means resize WINDOW
horizontally by DELTA columns.  In this case a positive DELTA
means enlarge WINDOW by DELTA columns.  DELTA negative means
WINDOW shall be shrunk by -DELTA columns.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE any window means ignore
restrictions for that window only.  IGNORE equal `safe' means
live windows may get as small as `window-safe-min-height' lines
and `window-safe-min-width' columns.

This function resizes other windows proportionally and never
deletes any windows.  If you want to move only the low (right)
edge of WINDOW consider using `adjust-window-trailing-edge'
instead."
  (setq window (normalize-any-window window))
  (let* ((frame (window-frame window))
	 sibling)
    (cond
     ((eq window (frame-root-window frame))
      (error "Cannot resize the root window of a frame"))
     ((window-minibuffer-p window)
      (resize-mini-window window delta))
     ((window-resizable-p window delta horizontal ignore)
      (resize-window-reset frame horizontal)
      (resize-this-window window delta horizontal ignore t)
      (if (and (not (window-splits window))
	       (window-iso-combined-p window horizontal)
	       (setq sibling (or (window-right window) (window-left window)))
	       (window-sizable-p sibling (- delta) horizontal ignore))
	  ;; If window-splits returns nil for WINDOW, WINDOW is part of
	  ;; an iso-combination, and WINDOW's neighboring right or left
	  ;; sibling can be resized as requested, resize that sibling.
	  (let ((normal-delta
		 (/ (float delta)
		    (window-total-size (window-parent window) horizontal))))
	    (resize-this-window sibling (- delta) horizontal nil t)
	    (set-window-new-normal
	     window (+ (window-normal-size window horizontal)
		       normal-delta))
	    (set-window-new-normal
	     sibling (- (window-normal-size sibling horizontal)
			normal-delta)))
	;; Otherwise, resize all other windows in the same combination.
	(resize-other-windows window delta horizontal ignore))
      (resize-window-apply frame horizontal))
     (t
      (error "Cannot resize window %s" window)))))

(defsubst resize-subwindows-skip-p (window)
  "Return non-nil if WINDOW shall be skipped by resizing routines."
  (memq (window-new-normal window) '(ignore stuck skip)))

(defun resize-subwindows-normal (parent horizontal window this-delta &optional trail other-delta)
  "Set the new normal height of subwindows of window PARENT.
HORIZONTAL non-nil means set the new normal width of these
windows.  WINDOW specifies a subwindow of PARENT that has been
resized by THIS-DELTA lines \(columns).

Optional argument TRAIL either 'before or 'after means set values
for windows before or after WINDOW only.  Optional argument
OTHER-DELTA a number specifies that this many lines \(columns)
have been obtained from \(or returned to) an ancestor window of
PARENT in order to resize WINDOW."
  (let* ((delta-normal
	  (if (and (= (- this-delta) (window-total-size window horizontal))
		   (zerop other-delta))
	      ;; When WINDOW gets deleted and we can return its entire
	      ;; space to its siblings, use WINDOW's normal size as the
	      ;; normal delta.
	      (- (window-normal-size window horizontal))
	    ;; In any other case calculate the normal delta from the
	    ;; relation of THIS-DELTA to the total size of PARENT.
	    (/ (float this-delta) (window-total-size parent horizontal))))
	 (sub (window-child parent))
	 (parent-normal 0.0)
	 (skip (eq trail 'after)))

    ;; Set parent-normal to the sum of the normal sizes of all
    ;; subwindows of PARENT that shall be resized, excluding only WINDOW
    ;; and any windows specified by the optional TRAIL argument.
    (while sub
      (cond
       ((eq sub window)
	(setq skip (eq trail 'before)))
       (skip)
       (t
	(setq parent-normal
	      (+ parent-normal (window-normal-size sub horizontal)))))
      (setq sub (window-right sub)))

    ;; Set the new normal size of all subwindows of PARENT from what
    ;; they should have contributed for recovering THIS-DELTA lines
    ;; (columns).
    (setq sub (window-child parent))
    (setq skip (eq trail 'after))
    (while sub
      (cond
       ((eq sub window)
	(setq skip (eq trail 'before)))
       (skip)
       (t
	(let ((old-normal (window-normal-size sub horizontal)))
	  (set-window-new-normal
	   sub (min 1.0 ; Don't get larger than 1.
		    (max (- old-normal
			    (* (/ old-normal parent-normal)
			       delta-normal))
			 ;; Don't drop below 0.
			 0.0))))))
      (setq sub (window-right sub)))

    (when (numberp other-delta)
      ;; Set the new normal size of windows from what they should have
      ;; contributed for recovering OTHER-DELTA lines (columns).
      (setq delta-normal (/ (float (window-total-size parent horizontal))
			    (+ (window-total-size parent horizontal)
			       other-delta)))
      (setq sub (window-child parent))
      (setq skip (eq trail 'after))
      (while sub
	(cond
	 ((eq sub window)
	  (setq skip (eq trail 'before)))
	 (skip)
	 (t
	  (set-window-new-normal
	   sub (min 1.0 ; Don't get larger than 1.
		    (max (* (window-new-normal sub) delta-normal)
			 ;; Don't drop below 0.
			 0.0)))))
	(setq sub (window-right sub))))

    ;; Set the new normal size of WINDOW to what is left by the sum of
    ;; the normal sizes of its siblings.
    (set-window-new-normal
     window
     (let ((sum 0))
       (setq sub (window-child parent))
       (while sub
	 (cond
	  ((eq sub window))
	  ((not (numberp (window-new-normal sub)))
	   (setq sum (+ sum (window-normal-size sub horizontal))))
	  (t
	   (setq sum (+ sum (window-new-normal sub)))))
	 (setq sub (window-right sub)))
       ;; Don't get larger than 1 or smaller than 0.
       (min 1.0 (max (- 1.0 sum) 0.0))))))

(defun resize-subwindows (parent delta &optional horizontal window ignore trail edge)
  "Resize subwindows of window PARENT vertically by DELTA lines.
PARENT must be a vertically combined internal window.

Optional argument HORIZONTAL non-nil means resize subwindows of
PARENT horizontally by DELTA columns.  In this case PARENT must
be a horizontally combined internal window.

WINDOW, if specified, must denote a child window of PARENT that
is resized by DELTA lines.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE equal `safe' means live
windows may get as small as `window-safe-min-height' lines and
`window-safe-min-width' columns.  IGNORE any window means ignore
restrictions for that window only.

Optional arguments TRAIL and EDGE, when non-nil, restrict the set
of windows that shall be resized.  If TRAIL equals `before',
resize only windows on the left or above EDGE.  If TRAIL equals
`after', resize only windows on the right or below EDGE.  Also,
preferably only resize windows adjacent to EDGE.

Return the symbol `normalized' if new normal sizes have been
already set by this routine."
  (let* ((first (window-child parent))
	 (sub first)
	 (parent-total (+ (window-total-size parent horizontal) delta))
	 best-window best-value)

    (if (and edge (memq trail '(before after))
	     (progn
	       (setq sub first)
	       (while (and (window-right sub)
			   (or (and (eq trail 'before)
				    (not (resize-subwindows-skip-p
					  (window-right sub))))
			       (and (eq trail 'after)
				    (resize-subwindows-skip-p sub))))
		 (setq sub (window-right sub)))
	       sub)
	     (if horizontal
		 (if (eq trail 'before)
		     (= (+ (window-left-column sub)
			   (window-total-size sub t))
			edge)
		   (= (window-left-column sub) edge))
	       (if (eq trail 'before)
		   (= (+ (window-top-line sub)
			 (window-total-size sub))
		      edge)
		 (= (window-top-line sub) edge)))
	     (window-sizable-p sub delta horizontal ignore))
	;; Resize only windows adjacent to EDGE.
	(progn
	  (resize-this-window sub delta horizontal ignore t trail edge)
	  (if (and window (eq (window-parent sub) parent))
	      (progn
		;; Assign new normal sizes.
		(set-window-new-normal
		 sub (/ (float (window-new-total sub)) parent-total))
		(set-window-new-normal
		 window (- (window-normal-size window horizontal)
			   (- (window-new-normal sub)
			      (window-normal-size sub horizontal)))))
	    (resize-subwindows-normal parent horizontal sub 0 trail delta))
	  ;; Return 'normalized to notify `resize-other-windows' that
	  ;; normal sizes have been already set.
	  'normalized)
      ;; Resize all windows proportionally.
      (setq sub first)
      (while sub
	(cond
	 ((or (resize-subwindows-skip-p sub)
	      ;; Ignore windows to skip and fixed-size subwindows - in
	      ;; the latter case make it a window to skip.
	      (and (not ignore)
		   (window-size-fixed-p sub horizontal)
		   (set-window-new-normal sub 'ignore))))
	 ((< delta 0)
	  ;; When shrinking store the number of lines/cols we can get
	  ;; from this window here together with the total/normal size
	  ;; factor.
	  (set-window-new-normal
	   sub
	   (cons
	    ;; We used to call this with NODOWN t, "fixed" 2011-05-11.
	    (window-min-delta sub horizontal ignore trail t) ; t)
	    (- (/ (float (window-total-size sub horizontal))
		  parent-total)
	       (window-normal-size sub horizontal)))))
	 ((> delta 0)
	  ;; When enlarging store the total/normal size factor only
	  (set-window-new-normal
	   sub
	   (- (/ (float (window-total-size sub horizontal))
		 parent-total)
	      (window-normal-size sub horizontal)))))

	(setq sub (window-right sub)))

      (cond
       ((< delta 0)
	;; Shrink windows by delta.
	(setq best-window t)
	(while (and best-window (not (zerop delta)))
	  (setq sub first)
	  (setq best-window nil)
	  (setq best-value most-negative-fixnum)
	  (while sub
	    (when (and (consp (window-new-normal sub))
		       (not (zerop (car (window-new-normal sub))))
		       (> (cdr (window-new-normal sub)) best-value))
	      (setq best-window sub)
	      (setq best-value (cdr (window-new-normal sub))))

	    (setq sub (window-right sub)))

	  (when best-window
	    (setq delta (1+ delta)))
	  (set-window-new-total best-window -1 t)
	  (set-window-new-normal
	   best-window
	   (if (= (car (window-new-normal best-window)) 1)
	       'skip ; We can't shrink best-window any further.
	     (cons (1- (car (window-new-normal best-window)))
		   (- (/ (float (window-new-total best-window))
			 parent-total)
		      (window-normal-size best-window horizontal)))))))
       ((> delta 0)
	;; Enlarge windows by delta.
	(setq best-window t)
	(while (and best-window (not (zerop delta)))
	  (setq sub first)
	  (setq best-window nil)
	  (setq best-value most-positive-fixnum)
	  (while sub
	    (when (and (numberp (window-new-normal sub))
		       (< (window-new-normal sub) best-value))
	      (setq best-window sub)
	      (setq best-value (window-new-normal sub)))

	    (setq sub (window-right sub)))

	  (when best-window
	    (setq delta (1- delta)))
	  (set-window-new-total best-window 1 t)
	  (set-window-new-normal
	   best-window
	   (- (/ (float (window-new-total best-window))
		 parent-total)
	      (window-normal-size best-window horizontal))))))

      (when best-window
	(setq sub first)
	(while sub
	  (when (or (consp (window-new-normal sub))
		    (numberp (window-new-normal sub)))
	    ;; Reset new normal size fields so `resize-window-apply'
	    ;; won't use them to apply new sizes.
	    (set-window-new-normal sub))

	  (unless (eq (window-new-normal sub) 'ignore)
	    ;; Resize this subwindow's subwindows (back-engineering
	    ;; delta from sub's old and new total sizes).
	    (let ((delta (- (window-new-total sub)
			    (window-total-size sub horizontal))))
	      (unless (and (zerop delta) (not trail))
		;; For the TRAIL non-nil case we have to resize SUB
		;; recursively even if it's size does not change.
		(resize-this-window
		 sub delta horizontal ignore nil trail edge))))
	  (setq sub (window-right sub)))))))

(defun resize-other-windows (window delta &optional horizontal ignore trail edge)
  "Resize other windows when WINDOW is resized vertically by DELTA lines.
Optional argument HORIZONTAL non-nil means resize other windows
when WINDOW is resized horizontally by DELTA columns.  WINDOW
itself is not resized by this function.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE equal `safe' means live
windows may get as small as `window-safe-min-height' lines and
`window-safe-min-width' columns.  IGNORE any window means ignore
restrictions for that window only.

Optional arguments TRAIL and EDGE, when non-nil, refine the set
of windows that shall be resized.  If TRAIL equals `before',
resize only windows on the left or above EDGE.  If TRAIL equals
`after', resize only windows on the right or below EDGE.  Also,
preferably only resize windows adjacent to EDGE."
  (when (window-parent window)
    (let* ((parent (window-parent window))
	   (sub (window-child parent)))
      (if (window-iso-combined-p sub horizontal)
	  ;; In an iso-combination try to extract DELTA from WINDOW's
	  ;; siblings.
	  (let ((first sub)
		(skip (eq trail 'after))
		this-delta other-delta)
	    ;; Decide which windows shall be left alone.
	    (while sub
	      (cond
	       ((eq sub window)
		;; Make sure WINDOW is left alone when
		;; resizing its siblings.
		(set-window-new-normal sub 'ignore)
		(setq skip (eq trail 'before)))
	       (skip
		;; Make sure this sibling is left alone when
		;; resizing its siblings.
		(set-window-new-normal sub 'ignore))
	       ((or (window-size-ignore sub ignore)
		    (not (window-size-fixed-p sub horizontal)))
		;; Set this-delta to t to signal that we found a sibling
		;; of WINDOW whose size is not fixed.
		(setq this-delta t)))

	      (setq sub (window-right sub)))

	    ;; Set this-delta to what we can get from WINDOW's siblings.
	    (if (= (- delta) (window-total-size window horizontal))
		;; A deletion, presumably.  We must handle this case
		;; specially since `window-resizable' can't be used.
		(if this-delta
		    ;; There's at least one resizable sibling we can
		    ;; give WINDOW's size to.
		    (setq this-delta delta)
		  ;; No resizable sibling exists.
		  (setq this-delta 0))
	      ;; Any other form of resizing.
	      (setq this-delta
		    (window-resizable window delta horizontal ignore trail t)))

	    ;; Set other-delta to what we still have to get from
	    ;; ancestor windows of parent.
	    (setq other-delta (- delta this-delta))
	    (unless (zerop other-delta)
	      ;; Unless we got everything from WINDOW's siblings, PARENT
	      ;; must be resized by other-delta lines or columns.
	      (set-window-new-total parent other-delta 'add))

	    (if (zerop this-delta)
		;; We haven't got anything from WINDOW's siblings but we
		;; must update the normal sizes to respect other-delta.
		(resize-subwindows-normal
		 parent horizontal window this-delta trail other-delta)
	      ;; We did get something from WINDOW's siblings which means
	      ;; we have to resize their subwindows.
	      (unless (eq (resize-subwindows parent (- this-delta) horizontal
					     window ignore trail edge)
			  ;; `resize-subwindows' returning 'normalized,
			  ;; means it has set the normal sizes already.
			  'normalized)
		;; Set the normal sizes.
		(resize-subwindows-normal
		 parent horizontal window this-delta trail other-delta))
	      ;; Set DELTA to what we still have to get from ancestor
	      ;; windows.
	      (setq delta other-delta)))

	;; In an ortho-combination all siblings of WINDOW must be
	;; resized by DELTA.
	(set-window-new-total parent delta 'add)
	(while sub
	  (unless (eq sub window)
	    (resize-this-window sub delta horizontal ignore t))
	  (setq sub (window-right sub))))

      (unless (zerop delta)
	;; "Go up."
	(resize-other-windows parent delta horizontal ignore trail edge)))))

(defun resize-this-window (window delta &optional horizontal ignore add trail edge)
  "Resize WINDOW vertically by DELTA lines.
Optional argument HORIZONTAL non-nil means resize WINDOW
horizontally by DELTA columns.

Optional argument IGNORE non-nil means ignore any restrictions
imposed by fixed size windows, `window-min-height' or
`window-min-width' settings.  IGNORE equal `safe' means live
windows may get as small as `window-safe-min-height' lines and
`window-safe-min-width' columns.  IGNORE any window means ignore
restrictions for that window only.

Optional argument ADD non-nil means add DELTA to the new total
size of WINDOW.

Optional arguments TRAIL and EDGE, when non-nil, refine the set
of windows that shall be resized.  If TRAIL equals `before',
resize only windows on the left or above EDGE.  If TRAIL equals
`after', resize only windows on the right or below EDGE.  Also,
preferably only resize windows adjacent to EDGE.

This function recursively resizes WINDOW's subwindows to fit the
new size.  Make sure that WINDOW is `window-resizable' before
calling this function.  Note that this function does not resize
siblings of WINDOW or WINDOW's parent window.  You have to
eventually call `resize-window-apply' in order to make resizing
actually take effect."
  (when add
    ;; Add DELTA to the new total size of WINDOW.
    (set-window-new-total window delta t))

  (let ((sub (window-child window)))
    (cond
     ((not sub))
     ((window-iso-combined-p sub horizontal)
      ;; In an iso-combination resize subwindows according to their
      ;; normal sizes.
      (resize-subwindows window delta horizontal nil ignore trail edge))
     ;; In an ortho-combination resize each subwindow by DELTA.
     (t
      (while sub
	(resize-this-window sub delta horizontal ignore t trail edge)
	(setq sub (window-right sub)))))))

(defun resize-root-window (window delta horizontal ignore)
  "Resize root window WINDOW vertically by DELTA lines.
HORIZONTAL non-nil means resize root window WINDOW horizontally
by DELTA columns.

IGNORE non-nil means ignore any restrictions imposed by fixed
size windows, `window-min-height' or `window-min-width' settings.

This function is only called by the frame resizing routines.  It
resizes windows proportionally and never deletes any windows."
  (when (and (windowp window) (numberp delta)
	     (window-sizable-p window delta horizontal ignore))
    (resize-window-reset (window-frame window) horizontal)
    (resize-this-window window delta horizontal ignore t)))

(defun resize-root-window-vertically (window delta)
  "Resize root window WINDOW vertically by DELTA lines.
If DELTA is less than zero and we can't shrink WINDOW by DELTA
lines, shrink it as much as possible.  If DELTA is greater than
zero, this function can resize fixed-size subwindows in order to
recover the necessary lines.

Return the number of lines that were recovered.

This function is only called by the minibuffer window resizing
routines.  It resizes windows proportionally and never deletes
any windows."
  (when (numberp delta)
    (let (ignore)
      (cond
       ((< delta 0)
	(setq delta (window-sizable window delta)))
       ((> delta 0)
	(unless (window-sizable window delta)
	  (setq ignore t))))

      (resize-window-reset (window-frame window))
      ;; Ideally, we would resize just the last window in a combination
      ;; but that's not feasible for the following reason: If we grow
      ;; the minibuffer window and the last window cannot be shrunk any
      ;; more, we shrink another window instead.  But if we then shrink
      ;; the minibuffer window again, the last window might get enlarged
      ;; and the state after shrinking is not the state before growing.
      ;; So, in practice, we'd need a history variable to record how to
      ;; proceed.  But I'm not sure how such a variable could work with
      ;; repeated minibuffer window growing steps.
      (resize-this-window window delta nil ignore t)
      delta)))

(defun adjust-window-trailing-edge (window delta &optional horizontal)
  "Move WINDOW's bottom edge by DELTA lines.
Optional argument HORIZONTAL non-nil means move WINDOW's right
edge by DELTA columns.  WINDOW defaults to the selected window.

If DELTA is greater zero, then move the edge downwards or to the
right.  If DELTA is less than zero, move the edge upwards or to
the left.  If the edge can't be moved by DELTA lines or columns,
move it as far as possible in the desired direction."
  (setq window (normalize-any-window window))
  (let ((frame (window-frame window))
	(right window)
	left this-delta min-delta max-delta failed)
    ;; Find the edge we want to move.
    (while (and (or (not (window-iso-combined-p right horizontal))
		    (not (window-right right)))
		(setq right (window-parent right))))
    (cond
     ((and (not right) (not horizontal) (not resize-mini-windows)
	   (eq (window-frame (minibuffer-window frame)) frame))
      (resize-mini-window (minibuffer-window frame) (- delta)))
     ((or (not (setq left right)) (not (setq right (window-right right))))
      (if horizontal
	  (error "No window on the right of this one")
	(error "No window below this one")))
     (t
      ;; Set LEFT to the first resizable window on the left.  This step is
      ;; needed to handle fixed-size windows.
      (while (and left (window-size-fixed-p left horizontal))
	(setq left
	      (or (window-left left)
		  (progn
		    (while (and (setq left (window-parent left))
				(not (window-iso-combined-p left horizontal))))
		    (window-left left)))))
      (unless left
	(if horizontal
	    (error "No resizable window on the left of this one")
	  (error "No resizable window above this one")))

      ;; Set RIGHT to the first resizable window on the right.  This step
      ;; is needed to handle fixed-size windows.
      (while (and right (window-size-fixed-p right horizontal))
	(setq right
	      (or (window-right right)
		  (progn
		    (while (and (setq right (window-parent right))
				(not (window-iso-combined-p right horizontal))))
		    (window-right right)))))
      (unless right
	(if horizontal
	    (error "No resizable window on the right of this one")
	  (error "No resizable window below this one")))

      ;; LEFT and RIGHT (which might be both internal windows) are now the
      ;; two windows we want to resize.
      (cond
       ((> delta 0)
	(setq max-delta (window-max-delta-1 left 0 horizontal nil 'after))
	(setq min-delta (window-min-delta-1 right (- delta) horizontal nil 'before))
	(when (or (< max-delta delta) (> min-delta (- delta)))
	  ;; We can't get the whole DELTA - move as far as possible.
	  (setq delta (min max-delta (- min-delta))))
	(unless (zerop delta)
	  ;; Start resizing.
	  (resize-window-reset frame horizontal)
	  ;; Try to enlarge LEFT first.
	  (setq this-delta (window-resizable left delta horizontal))
	  (unless (zerop this-delta)
	    (resize-this-window
	     left this-delta horizontal nil t 'before
	     (if horizontal
		 (+ (window-left-column left) (window-total-size left t))
	       (+ (window-top-line left) (window-total-size left)))))
	  ;; Shrink windows on right of LEFT.
	  (resize-other-windows
	   left delta horizontal nil 'after
	   (if horizontal
	       (window-left-column right)
	     (window-top-line right)))))
       ((< delta 0)
	(setq max-delta (window-max-delta-1 right 0 horizontal nil 'before))
	(setq min-delta (window-min-delta-1 left delta horizontal nil 'after))
	(when (or (< max-delta (- delta)) (> min-delta delta))
	  ;; We can't get the whole DELTA - move as far as possible.
	  (setq delta (max (- max-delta) min-delta)))
	(unless (zerop delta)
	  ;; Start resizing.
	  (resize-window-reset frame horizontal)
	  ;; Try to enlarge RIGHT.
	  (setq this-delta (window-resizable right (- delta) horizontal))
	  (unless (zerop this-delta)
	    (resize-this-window
	     right this-delta horizontal nil t 'after
	     (if horizontal
		 (window-left-column right)
	       (window-top-line right))))
	  ;; Shrink windows on left of RIGHT.
	  (resize-other-windows
	   right (- delta) horizontal nil 'before
	   (if horizontal
	       (+ (window-left-column left) (window-total-size left t))
	     (+ (window-top-line left) (window-total-size left)))))))
      (unless (zerop delta)
	;; Don't report an error in the standard case.
	(unless (resize-window-apply frame horizontal)
	  ;; But do report an error if applying the changes fails.
	  (error "Failed adjusting window %s" window)))))))

(defun enlarge-window (delta &optional horizontal)
  "Make selected window DELTA lines taller.
Interactively, if no argument is given, make the selected window
one line taller.  If optional argument HORIZONTAL is non-nil,
make selected window wider by DELTA columns.  If DELTA is
negative, shrink selected window by -DELTA lines or columns.
Return nil."
  (interactive "p")
  (resize-window (selected-window) delta horizontal))

(defun shrink-window (delta &optional horizontal)
  "Make selected window DELTA lines smaller.
Interactively, if no argument is given, make the selected window
one line smaller.  If optional argument HORIZONTAL is non-nil,
make selected window narrower by DELTA columns.  If DELTA is
negative, enlarge selected window by -DELTA lines or columns.
Return nil."
  (interactive "p")
  (resize-window (selected-window) (- delta) horizontal))

(defun maximize-window (&optional window)
  "Maximize WINDOW.
Make WINDOW as large as possible without deleting any windows.
WINDOW can be any window and defaults to the selected window."
  (interactive)
  (setq window (normalize-any-window window))
  (resize-window window (window-max-delta window))
  (resize-window window (window-max-delta window t) t))

(defun minimize-window (&optional window)
  "Minimize WINDOW.
Make WINDOW as small as possible without deleting any windows.
WINDOW can be any window and defaults to the selected window."
  (interactive)
  (setq window (normalize-any-window window))
  (resize-window window (- (window-min-delta window)))
  (resize-window window (- (window-min-delta window t)) t))

(defsubst frame-root-window-p (window)
  "Return non-nil if WINDOW is the root window of its frame."
  (eq window (frame-root-window window)))

;; This should probably return non-nil when the selected window is part
;; of an atomic window whose root is the frame's root window.
(defun one-window-p (&optional nomini all-frames)
  "Return non-nil if the selected window is the only window.
Optional arg NOMINI non-nil means don't count the minibuffer
even if it is active.  Otherwise, the minibuffer is counted
when it is active.

Optional argument ALL-FRAMES specifies the set of frames to
consider, see also `next-window'.  ALL-FRAMES nil or omitted
means consider windows on the selected frame only, plus the
minibuffer window if specified by the NOMINI argument.  If the
minibuffer counts, consider all windows on all frames that share
that minibuffer too.  The remaining non-nil values of ALL-FRAMES
with a special meaning are:

- t means consider all windows on all existing frames.

- `visible' means consider all windows on all visible frames on
  the current terminal.

- 0 (the number zero) means consider all windows on all visible
  and iconified frames on the current terminal.

- A frame means consider all windows on that frame only.

Anything else means consider all windows on the selected frame
and no others."
  (let ((base-window (selected-window)))
    (if (and nomini (eq base-window (minibuffer-window)))
	(setq base-window (next-window base-window)))
    (eq base-window
	(next-window base-window (if nomini 'arg) all-frames))))

;;; Deleting windows.
(defun window-deletable-p (&optional window)
  "Return t if WINDOW can be safely deleted from its frame.
Return `frame' if deleting WINDOW should delete its frame
instead."
  (setq window (normalize-any-window window))
  (unless ignore-window-parameters
    ;; Handle atomicity.
    (when (window-parameter window 'window-atom)
      (setq window (window-atom-root window))))
  (let ((parent (window-parent window))
	(frame (window-frame window))
	(dedicated (and (window-buffer window) (window-dedicated-p window)))
	(quit-restore (window-parameter window 'quit-restore)))
    (cond
     ((frame-root-window-p window)
      (when (and (or dedicated
		     (and (eq (car-safe quit-restore) 'new-frame)
			  (eq (nth 1 quit-restore) (window-buffer window))))
		 (other-visible-frames-p frame))
	;; WINDOW is the root window of its frame.  Return `frame' but
	;; only if WINDOW is (1) either dedicated or quit-restore's car
	;; is new-frame and the window still displays the same buffer
	;; and (2) there are other frames left.
	'frame))
     ((and (not ignore-window-parameters)
	   (eq (window-parameter window 'window-side) 'none)
	   (or (not parent)
	       (not (eq (window-parameter parent 'window-side) 'none))))
      ;; Can't delete last main window.
      nil)
     (t))))

(defun window-or-subwindow-p (subwindow window)
  "Return t if SUBWINDOW is either WINDOW or a subwindow of WINDOW."
  (or (eq subwindow window)
      (let ((parent (window-parent subwindow)))
	(catch 'done
	  (while parent
	    (if (eq parent window)
		(throw 'done t)
	      (setq parent (window-parent parent))))))))

(defun delete-window (&optional window)
  "Delete WINDOW.
WINDOW can be an arbitrary window and defaults to the selected
one.  Return nil.

If the variable `ignore-window-parameters' is non-nil or the
`delete-window' parameter of WINDOW equals t, do not process any
parameters of WINDOW.  Otherwise, if the `delete-window'
parameter of WINDOW specifies a function, call that function with
WINDOW as its sole argument and return the value returned by that
function.

Otherwise, if WINDOW is part of an atomic window, call
`delete-window' with the root of the atomic window as its
argument.  If WINDOW is the only window on its frame or the last
non-side window, signal an error."
  (interactive)
  (setq window (normalize-any-window window))
  (let* ((frame (window-frame window))
	 (function (window-parameter window 'delete-window))
	 (parent (window-parent window))
	 atom-root)
    (window-check frame)
    (catch 'done
      ;; Handle window parameters.
      (cond
       ;; Ignore window parameters if `ignore-window-parameters' tells
       ;; us so or `delete-window' equals t.
       ((or ignore-window-parameters (eq function t)))
       ((functionp function)
	;; The `delete-window' parameter specifies the function to call.
	;; If that function is `ignore' nothing is done.  It's up to the
	;; function called here to avoid infinite recursion.
	(throw 'done (funcall function window)))
       ((and (window-parameter window 'window-atom)
	     (setq atom-root (window-atom-root window))
	     (not (eq atom-root window)))
	(throw 'done (delete-window atom-root)))
       ((and (eq (window-parameter window 'window-side) 'none)
	     (or (not parent)
		 (not (eq (window-parameter parent 'window-side) 'none))))
	(error "Attempt to delete last non-side window"))
       ((not parent)
	(error "Attempt to delete minibuffer or sole ordinary window")))

      (let* ((horizontal (window-hchild parent))
	     (size (window-total-size window horizontal))
	     (frame-selected
	      (window-or-subwindow-p (frame-selected-window frame) window))
	     ;; Emacs 23 preferably gives WINDOW's space to its left
	     ;; sibling.
	     (sibling (or (window-left window) (window-right window))))
	(resize-window-reset frame horizontal)
	(cond
	 ((and (not (window-splits window))
	       sibling (window-sizable-p sibling size))
	  ;; Resize WINDOW's sibling.
	  (resize-this-window sibling size horizontal nil t)
	  (set-window-new-normal
	   sibling (+ (window-normal-size sibling horizontal)
		      (window-normal-size window horizontal))))
	 ((window-resizable-p window (- size) horizontal nil nil nil t)
	  ;; Can do without resizing fixed-size windows.
	  (resize-other-windows window (- size) horizontal))
	 (t
	  ;; Can't do without resizing fixed-size windows.
	  (resize-other-windows window (- size) horizontal t)))
	;; Actually delete WINDOW.
	(delete-window-internal window)
	(when (and frame-selected
		   (window-parameter
		    (frame-selected-window frame) 'no-other-window))
	  ;; `delete-window-internal' has selected a window that should
	  ;; not be selected, fix this here.
	  (other-window -1 frame))
	(run-window-configuration-change-hook frame)
	(window-check frame)
	;; Always return nil.
	nil))))

(defun delete-other-windows (&optional window)
  "Make WINDOW fill its frame.
WINDOW may be any window and defaults to the selected one.
Return nil.

If the variable `ignore-window-parameters' is non-nil or the
`delete-other-windows' parameter of WINDOW equals t, do not
process any parameters of WINDOW.  Otherwise, if the
`delete-other-windows' parameter of WINDOW specifies a function,
call that function with WINDOW as its sole argument and return
the value returned by that function.

Otherwise, if WINDOW is part of an atomic window, call this
function with the root of the atomic window as its argument.  If
WINDOW is a non-side window, make WINDOW the only non-side window
on the frame.  Side windows are not deleted. If WINDOW is a side
window signal an error."
  (interactive)
  (setq window (normalize-any-window window))
  (let* ((frame (window-frame window))
	 (function (window-parameter window 'delete-other-windows))
	 (window-side (window-parameter window 'window-side))
	 atom-root side-main)
    (window-check frame)
    (catch 'done
      (cond
       ;; Ignore window parameters if `ignore-window-parameters' is t or
       ;; `delete-other-windows' is t.
       ((or ignore-window-parameters (eq function t)))
       ((functionp function)
	;; The `delete-other-windows' parameter specifies the function
	;; to call.  If the function is `ignore' no windows are deleted.
	;; It's up to the function called to avoid infinite recursion.
	(throw 'done (funcall function window)))
       ((and (window-parameter window 'window-atom)
	     (setq atom-root (window-atom-root window))
	     (not (eq atom-root window)))
	(throw 'done (delete-other-windows atom-root)))
       ((eq window-side 'none)
	;; Set side-main to the major non-side window.
	(setq side-main (window-with-parameter 'window-side 'none nil t)))
       ((memq window-side window-sides)
	(error "Cannot make side window the only window")))
      ;; If WINDOW is the main non-side window, do nothing.
      (unless (eq window side-main)
	(delete-other-windows-internal window side-main)
	(run-window-configuration-change-hook frame)
	(window-check frame))
      ;; Always return nil.
      nil)))

;;; Splitting windows.
(defsubst window-split-min-size (&optional horizontal)
  "Return minimum height of any window when splitting windows.
Optional argument HORIZONTAL non-nil means return minimum width."
  (if horizontal
      (max window-min-width window-safe-min-width)
    (max window-min-height window-safe-min-height)))

(defun split-window (&optional window size side)
  "Make a new window adjacent to WINDOW.
WINDOW can be any window and defaults to the selected one.
Return the new window which is always a live window.

Optional argument SIZE a positive number means make WINDOW SIZE
lines or columns tall.  If SIZE is negative, make the new window
-SIZE lines or columns tall.  If and only if SIZE is non-nil, its
absolute value can be less than `window-min-height' or
`window-min-width'; so this command can make a new window as
small as one line or two columns.  SIZE defaults to half of
WINDOW's size.  Interactively, SIZE is the prefix argument.

Optional third argument SIDE nil (or `below') specifies that the
new window shall be located below WINDOW.  SIDE `above' means the
new window shall be located above WINDOW.  In both cases SIZE
specifies the new number of lines for WINDOW \(or the new window
if SIZE is negative) including space reserved for the mode and/or
header line.

SIDE t (or `right') specifies that the new window shall be
located on the right side of WINDOW.  SIDE `left' means the new
window shall be located on the left of WINDOW.  In both cases
SIZE specifies the new number of columns for WINDOW \(or the new
window provided SIZE is negative) including space reserved for
fringes and the scrollbar or a divider column.  Any other non-nil
value for SIDE is currently handled like t (or `right').

If the variable `ignore-window-parameters' is non-nil or the
`split-window' parameter of WINDOW equals t, do not process any
parameters of WINDOW.  Otherwise, if the `split-window' parameter
of WINDOW specifies a function, call that function with all three
arguments and return the value returned by that function.

Otherwise, if WINDOW is part of an atomic window, \"split\" the
root of that atomic window.  The new window does not become a
member of that atomic window.

If WINDOW is live, properties of the new window like margins and
scrollbars are inherited from WINDOW.  If WINDOW is an internal
window, these properties as well as the buffer displayed in the
new window are inherited from the window selected on WINDOW's
frame.  The selected window is not changed by this function."
  (interactive "i")
  (setq window (normalize-any-window window))
  (let* ((horizontal (not (memq side '(nil below above))))
	 (frame (window-frame window))
	 (parent (window-parent window))
	 (function (window-parameter window 'split-window))
	 (window-side (window-parameter window 'window-side))
	 ;; Rebind `window-nest' since in some cases we may have to
	 ;; override its value.
	 (window-nest window-nest)
	 atom-root)

    (window-check frame)
    (catch 'done
      (cond
       ;; Ignore window parameters if either `ignore-window-parameters'
       ;; is t or the `split-window' parameter equals t.
       ((or ignore-window-parameters (eq function t)))
       ((functionp function)
	;; The `split-window' parameter specifies the function to call.
	;; If that function is `ignore', do nothing.
	(throw 'done (funcall function window size side)))
       ;; If WINDOW is a subwindow of an atomic window, split the root
       ;; window of that atomic window instead.
       ((and (window-parameter window 'window-atom)
	     (setq atom-root (window-atom-root window))
	     (not (eq atom-root window)))
	(throw 'done (split-window atom-root size side))))

      (when (and window-side
		 (or (not parent)
		     (not (window-parameter parent 'window-side))))
	;; WINDOW is a side root window.  To make sure that a new parent
	;; window gets created set `window-nest' to t.
	(setq window-nest t))

      (when (and window-splits size (> size 0))
	;; If `window-splits' is non-nil and SIZE is a non-negative
	;; integer, we cannot reasonably resize other windows.  Rather
	;; bind `window-nest' to t to make sure that subsequent window
	;; deletions are handled correctly.
	(setq window-nest t))

      (let* ((parent-size
	      ;; `parent-size' is the size of WINDOW's parent, provided
	      ;; it has one.
	      (when parent (window-total-size parent horizontal)))
	     ;; `resize' non-nil means we are supposed to resize other
	     ;; windows in WINDOW's combination.
	     (resize
	      (and window-splits (not window-nest)
		   ;; Resize makes sense in iso-combinations only.
		   (window-iso-combined-p window horizontal)))
	     ;; `old-size' is the current size of WINDOW.
	     (old-size (window-total-size window horizontal))
	     ;; `new-size' is the specified or calculated size of the
	     ;; new window.
	     (new-size
	      (cond
	       ((not size)
		(max (window-split-min-size horizontal)
		     (if resize
			 ;; When resizing try to give the new window the
			 ;; average size of a window in its combination.
			 (min (- parent-size
				 (window-min-size parent horizontal))
			      (/ parent-size
				 (1+ (window-iso-combinations
				      parent horizontal))))
		       ;; Else try to give the new window half the size
		       ;; of WINDOW (plus an eventual odd line).
		       (+ (/ old-size 2) (% old-size 2)))))
	       ((>= size 0)
		;; SIZE non-negative specifies the new size of WINDOW.

		;; Note: Specifying a non-negative SIZE is practically
		;; always done as workaround for making the new window
		;; appear above or on the left of the new window (the
		;; ispell window is a typical example of that).  In all
		;; these cases the SIDE argument should be set to 'above
		;; or 'left in order to support the 'resize option.
		;; Here we have to nest the windows instead, see above.
		(- old-size size))
	       (t
		;; SIZE negative specifies the size of the new window.
		(- size))))
	     new-parent new-normal)

	;; Check SIZE.
	(cond
	 ((not size)
	  (cond
	   (resize
	    ;; SIZE unspecified, resizing.
	    (when (and (not (window-sizable-p parent (- new-size) horizontal))
		       ;; Try again with minimum split size.
		       (setq new-size
			     (max new-size (window-split-min-size horizontal)))
		       (not (window-sizable-p parent (- new-size) horizontal)))
	      (error "Window %s too small for splitting" parent)))
	   ((> (+ new-size (window-min-size window horizontal)) old-size)
	    ;; SIZE unspecified, no resizing.
	    (error "Window %s too small for splitting" window))))
	 ((and (>= size 0)
	       (or (>= size old-size)
		   (< new-size (if horizontal
				   window-safe-min-width
				 window-safe-min-width))))
	  ;; SIZE specified as new size of old window.  If the new size
	  ;; is larger than the old size or the size of the new window
	  ;; would be less than the safe minimum, signal an error.
	  (error "Window %s too small for splitting" window))
	 (resize
	  ;; SIZE specified, resizing.
	  (unless (window-sizable-p parent (- new-size) horizontal)
	    ;; If we cannot resize the parent give up.
	    (error "Window %s too small for splitting" parent)))
	 ((or (< new-size
		 (if horizontal window-safe-min-width window-safe-min-height))
	      (< (- old-size new-size)
		 (if horizontal window-safe-min-width window-safe-min-height)))
	  ;; SIZE specification violates minimum size restrictions.
	  (error "Window %s too small for splitting" window)))

	(resize-window-reset frame horizontal)

	(setq new-parent
	      ;; Make new-parent non-nil if we need a new parent window;
	      ;; either because we want to nest or because WINDOW is not
	      ;; iso-combined.
	      (or window-nest (not (window-iso-combined-p window horizontal))))
	(setq new-normal
	      ;; Make new-normal the normal size of the new window.
	      (cond
	       (size (/ (float new-size) (if new-parent old-size parent-size)))
	       (new-parent 0.5)
	       (resize (/ 1.0 (1+ (window-iso-combinations parent horizontal))))
	       (t (/ (window-normal-size window horizontal) 2.0))))

	(if resize
	    ;; Try to get space from OLD's siblings.  We could go "up" and
	    ;; try getting additional space from surrounding windows but
	    ;; we won't be able to return space to those windows when we
	    ;; delete the one we create here.  Hence we do not go up.
	    (progn
	      (resize-subwindows parent (- new-size) horizontal)
	      (let* ((normal (- 1.0 new-normal))
		     (sub (window-child parent)))
		(while sub
		  (set-window-new-normal
		   sub (* (window-normal-size sub horizontal) normal))
		  (setq sub (window-right sub)))))
	  ;; Get entire space from WINDOW.
	  (set-window-new-total window (- old-size new-size))
	  (resize-this-window window (- new-size) horizontal)
	  (set-window-new-normal
	   window (- (if new-parent 1.0 (window-normal-size window horizontal))
		     new-normal)))

	(let* ((new (split-window-internal window new-size side new-normal)))
	  ;; Inherit window-side parameters, if any.
	  (when (and window-side new-parent)
	    (set-window-parameter (window-parent new) 'window-side window-side)
	    (set-window-parameter new 'window-side window-side))

	  (run-window-configuration-change-hook frame)
	  (window-check frame)
	  ;; Always return the new window.
	  new)))))

;; I think this should be the default; I think people will prefer it--rms.
(defcustom split-window-keep-point t
  "If non-nil, \\[split-window-above-each-other] keeps the original point \
in both children.
This is often more convenient for editing.
If nil, adjust point in each of the two windows to minimize redisplay.
This is convenient on slow terminals, but point can move strangely.

This option applies only to `split-window-above-each-other' and
functions that call it.  `split-window' always keeps the original
point in both children."
  :type 'boolean
  :group 'windows)

(defun split-window-above-each-other (&optional size)
  "Split selected window into two windows, one above the other.
The upper window gets SIZE lines and the lower one gets the rest.
SIZE negative means the lower window gets -SIZE lines and the
upper one the rest.  With no argument, split windows equally or
close to it.  Both windows display the same buffer, now current.

If the variable `split-window-keep-point' is non-nil, both new
windows will get the same value of point as the selected window.
This is often more convenient for editing.  The upper window is
the selected window.

Otherwise, we choose window starts so as to minimize the amount of
redisplay; this is convenient on slow terminals.  The new selected
window is the one that the current value of point appears in.  The
value of point can change if the text around point is hidden by the
new mode line.

Regardless of the value of `split-window-keep-point', the upper
window is the original one and the return value is the new, lower
window."
  (interactive "P")
  (let ((old-window (selected-window))
	(old-point (point))
	(size (and size (prefix-numeric-value size)))
        moved-by-window-height moved new-window bottom)
    (when (and size (< size 0) (< (- size) window-min-height))
      ;; `split-window' would not signal an error here.
      (error "Size of new window too small"))
    (setq new-window (split-window nil size))
    (unless split-window-keep-point
      (with-current-buffer (window-buffer)
	(goto-char (window-start))
	(setq moved (vertical-motion (window-height)))
	(set-window-start new-window (point))
	(when (> (point) (window-point new-window))
	  (set-window-point new-window (point)))
	(when (= moved (window-height))
	  (setq moved-by-window-height t)
	  (vertical-motion -1))
	(setq bottom (point)))
      (and moved-by-window-height
	   (<= bottom (point))
	   (set-window-point old-window (1- bottom)))
      (and moved-by-window-height
	   (<= (window-start new-window) old-point)
	   (set-window-point new-window old-point)
	   (select-window new-window)))
    (split-window-save-restore-data new-window old-window)))

(defalias 'split-window-vertically 'split-window-above-each-other)

;; This is to avoid compiler warnings.
(defvar view-return-to-alist)

(defun split-window-save-restore-data (new-window old-window)
  (with-current-buffer (window-buffer)
    (when view-mode
      (let ((old-info (assq old-window view-return-to-alist)))
	(when old-info
	  (push (cons new-window (cons (car (cdr old-info)) t))
		view-return-to-alist))))
    new-window))

(defun split-window-side-by-side (&optional size)
  "Split selected window into two windows side by side.
The selected window becomes the left one and gets SIZE columns.
SIZE negative means the right window gets -SIZE lines.

SIZE includes the width of the window's scroll bar; if there are
no scroll bars, it includes the width of the divider column to
the window's right, if any.  SIZE omitted or nil means split
window equally.

The selected window remains selected.  Return the new window."
  (interactive "P")
  (let ((old-window (selected-window))
	(size (and size (prefix-numeric-value size)))
	new-window)
    (when (and size (< size 0) (< (- size) window-min-width))
      ;; `split-window' would not signal an error here.
      (error "Size of new window too small"))
    (split-window-save-restore-data (split-window nil size t) old-window)))

(defalias 'split-window-horizontally 'split-window-side-by-side)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; `balance-windows' subroutines using `window-tree'

;;; Translate from internal window tree format

(defun bw-get-tree (&optional window-or-frame)
  "Get a window split tree in our format.

WINDOW-OR-FRAME must be nil, a frame, or a window.  If it is nil,
then the whole window split tree for `selected-frame' is returned.
If it is a frame, then this is used instead.  If it is a window,
then the smallest tree containing that window is returned."
  (when window-or-frame
    (unless (or (framep window-or-frame)
                (windowp window-or-frame))
      (error "Not a frame or window: %s" window-or-frame)))
  (let ((subtree (bw-find-tree-sub window-or-frame)))
    (when subtree
      (if (integerp subtree)
	  nil
	(bw-get-tree-1 subtree)))))

(defun bw-get-tree-1 (split)
  (if (windowp split)
      split
    (let ((dir (car split))
          (edges (car (cdr split)))
          (childs (cdr (cdr split))))
      (list
       (cons 'dir (if dir 'ver 'hor))
       (cons 'b (nth 3 edges))
       (cons 'r (nth 2 edges))
       (cons 't (nth 1 edges))
       (cons 'l (nth 0 edges))
       (cons 'childs (mapcar #'bw-get-tree-1 childs))))))

(defun bw-find-tree-sub (window-or-frame &optional get-parent)
  (let* ((window (when (windowp window-or-frame) window-or-frame))
         (frame (when (windowp window) (window-frame window)))
         (wt (car (window-tree frame))))
    (when (< 1 (length (window-list frame 0)))
      (if window
          (bw-find-tree-sub-1 wt window get-parent)
        wt))))

(defun bw-find-tree-sub-1 (tree win &optional get-parent)
  (unless (windowp win) (error "Not a window: %s" win))
  (if (memq win tree)
      (if get-parent
          get-parent
        tree)
    (let ((childs (cdr (cdr tree)))
          child
          subtree)
      (while (and childs (not subtree))
        (setq child (car childs))
        (setq childs (cdr childs))
        (when (and child (listp child))
          (setq subtree (bw-find-tree-sub-1 child win get-parent))))
      (if (integerp subtree)
          (progn
            (if (= 1 subtree)
                tree
              (1- subtree)))
        subtree
        ))))

;;; Window or object edges

(defun bw-l (obj)
  "Left edge of OBJ."
  (if (windowp obj) (nth 0 (window-edges obj)) (cdr (assq 'l obj))))
(defun bw-t (obj)
  "Top edge of OBJ."
  (if (windowp obj) (nth 1 (window-edges obj)) (cdr (assq 't obj))))
(defun bw-r (obj)
  "Right edge of OBJ."
  (if (windowp obj) (nth 2 (window-edges obj)) (cdr (assq 'r obj))))
(defun bw-b (obj)
  "Bottom edge of OBJ."
  (if (windowp obj) (nth 3 (window-edges obj)) (cdr (assq 'b obj))))

;;; Split directions

(defun bw-dir (obj)
  "Return window split tree direction if OBJ.
If OBJ is a window return 'both.  If it is a window split tree
then return its direction."
  (if (symbolp obj)
      obj
    (if (windowp obj)
        'both
      (let ((dir (cdr (assq 'dir obj))))
        (unless (memq dir '(hor ver both))
          (error "Can't find dir in %s" obj))
        dir))))

(defun bw-eqdir (obj1 obj2)
  "Return t if window split tree directions are equal.
OBJ1 and OBJ2 should be either windows or window split trees in
our format.  The directions returned by `bw-dir' are compared and
t is returned if they are `eq' or one of them is 'both."
  (let ((dir1 (bw-dir obj1))
        (dir2 (bw-dir obj2)))
    (or (eq dir1 dir2)
        (eq dir1 'both)
        (eq dir2 'both))))

;;; Building split tree

(defun bw-refresh-edges (obj)
  "Refresh the edge information of OBJ and return OBJ."
  (unless (windowp obj)
    (let ((childs (cdr (assq 'childs obj)))
          (ol 1000)
          (ot 1000)
          (or -1)
          (ob -1))
      (dolist (o childs)
        (when (> ol (bw-l o)) (setq ol (bw-l o)))
        (when (> ot (bw-t o)) (setq ot (bw-t o)))
        (when (< or (bw-r o)) (setq or (bw-r o)))
        (when (< ob (bw-b o)) (setq ob (bw-b o))))
      (setq obj (delq 'l obj))
      (setq obj (delq 't obj))
      (setq obj (delq 'r obj))
      (setq obj (delq 'b obj))
      (add-to-list 'obj (cons 'l ol))
      (add-to-list 'obj (cons 't ot))
      (add-to-list 'obj (cons 'r or))
      (add-to-list 'obj (cons 'b ob))
      ))
  obj)

;;; Balance windows

(defun balance-windows (&optional window-or-frame)
  "Make windows the same heights or widths in window split subtrees.

When called non-interactively WINDOW-OR-FRAME may be either a
window or a frame.  It then balances the windows on the implied
frame.  If the parameter is a window only the corresponding window
subtree is balanced."
  (interactive)
  (let (
        (wt (bw-get-tree window-or-frame))
        (w)
        (h)
        (tried-sizes)
        (last-sizes)
        (windows (window-list nil 0)))
    (when wt
      (while (not (member last-sizes tried-sizes))
        (when last-sizes (setq tried-sizes (cons last-sizes tried-sizes)))
        (setq last-sizes (mapcar (lambda (w)
                                   (window-edges w))
                                 windows))
        (when (eq 'hor (bw-dir wt))
          (setq w (- (bw-r wt) (bw-l wt))))
        (when (eq 'ver (bw-dir wt))
          (setq h (- (bw-b wt) (bw-t wt))))
        (bw-balance-sub wt w h)))))

(defun bw-adjust-window (window delta horizontal)
  "Wrapper around `adjust-window-trailing-edge' with error checking.
Arguments WINDOW, DELTA and HORIZONTAL are passed on to that function."
  ;; `adjust-window-trailing-edge' may fail if delta is too large.
  (while (>= (abs delta) 1)
    (condition-case nil
        (progn
          (adjust-window-trailing-edge window delta horizontal)
          (setq delta 0))
      (error
       ;;(message "adjust: %s" (error-message-string err))
       (setq delta (/ delta 2))))))

(defun bw-balance-sub (wt w h)
  (setq wt (bw-refresh-edges wt))
  (unless w (setq w (- (bw-r wt) (bw-l wt))))
  (unless h (setq h (- (bw-b wt) (bw-t wt))))
  (if (windowp wt)
      (progn
        (when w
          (let ((dw (- w (- (bw-r wt) (bw-l wt)))))
            (when (/= 0 dw)
              (bw-adjust-window wt dw t))))
        (when h
          (let ((dh (- h (- (bw-b wt) (bw-t wt)))))
            (when (/= 0 dh)
              (bw-adjust-window wt dh nil)))))
    (let* ((childs (cdr (assq 'childs wt)))
           (cw (when w (/ w (if (bw-eqdir 'hor wt) (length childs) 1))))
           (ch (when h (/ h (if (bw-eqdir 'ver wt) (length childs) 1)))))
      (dolist (c childs)
        (bw-balance-sub c cw ch)))))

(defun window-fixed-size-p (&optional window direction)
  "Return t if WINDOW cannot be resized in DIRECTION.
WINDOW defaults to the selected window.  DIRECTION can be
nil (i.e. any), `height' or `width'."
  (with-current-buffer (window-buffer window)
    (when (and (boundp 'window-size-fixed) window-size-fixed)
      (not (and direction
		(member (cons direction window-size-fixed)
			'((height . width) (width . height))))))))

;;; A different solution to balance-windows.

(defvar window-area-factor 1
  "Factor by which the window area should be over-estimated.
This is used by `balance-windows-area'.
Changing this globally has no effect.")
(make-variable-buffer-local 'window-area-factor)

(defun balance-windows-area ()
  "Make all visible windows the same area (approximately).
See also `window-area-factor' to change the relative size of
specific buffers."
  (interactive)
  (let* ((unchanged 0) (carry 0) (round 0)
         ;; Remove fixed-size windows.
         (wins (delq nil (mapcar (lambda (win)
                                   (if (not (window-fixed-size-p win)) win))
                                 (window-list nil 'nomini))))
         (changelog nil)
         next)
    ;; Resizing a window changes the size of surrounding windows in complex
    ;; ways, so it's difficult to balance them all.  The introduction of
    ;; `adjust-window-trailing-edge' made it a bit easier, but it is still
    ;; very difficult to do.  `balance-window' above takes an off-line
    ;; approach: get the whole window tree, then balance it, then try to
    ;; adjust the windows so they fit the result.
    ;; Here, instead, we take a "local optimization" approach, where we just
    ;; go through all the windows several times until nothing needs to be
    ;; changed.  The main problem with this approach is that it's difficult
    ;; to make sure it terminates, so we use some heuristic to try and break
    ;; off infinite loops.
    ;; After a round without any change, we allow a second, to give a chance
    ;; to the carry to propagate a minor imbalance from the end back to
    ;; the beginning.
    (while (< unchanged 2)
      ;; (message "New round")
      (setq unchanged (1+ unchanged) round (1+ round))
      (dolist (win wins)
        (setq next win)
        (while (progn (setq next (next-window next))
                      (window-fixed-size-p next)))
        ;; (assert (eq next (or (cadr (member win wins)) (car wins))))
        (let* ((horiz
                (< (car (window-edges win)) (car (window-edges next))))
               (areadiff (/ (- (* (window-height next) (window-width next)
                                  (buffer-local-value 'window-area-factor
                                                      (window-buffer next)))
                               (* (window-height win) (window-width win)
                                  (buffer-local-value 'window-area-factor
                                                      (window-buffer win))))
                            (max (buffer-local-value 'window-area-factor
                                                     (window-buffer win))
                                 (buffer-local-value 'window-area-factor
                                                     (window-buffer next)))))
               (edgesize (if horiz
                             (+ (window-height win) (window-height next))
                           (+ (window-width win) (window-width next))))
               (diff (/ areadiff edgesize)))
          (when (zerop diff)
            ;; Maybe diff is actually closer to 1 than to 0.
            (setq diff (/ (* 3 areadiff) (* 2 edgesize))))
          (when (and (zerop diff) (not (zerop areadiff)))
            (setq diff (/ (+ areadiff carry) edgesize))
            ;; Change things smoothly.
            (if (or (> diff 1) (< diff -1)) (setq diff (/ diff 2))))
          (if (zerop diff)
              ;; Make sure negligible differences don't accumulate to
              ;; become significant.
              (setq carry (+ carry areadiff))
            (bw-adjust-window win diff horiz)
            ;; (sit-for 0.5)
            (let ((change (cons win (window-edges win))))
              ;; If the same change has been seen already for this window,
              ;; we're most likely in an endless loop, so don't count it as
              ;; a change.
              (unless (member change changelog)
                (push change changelog)
                (setq unchanged 0 carry 0)))))))
    ;; We've now basically balanced all the windows.
    ;; But there may be some minor off-by-one imbalance left over,
    ;; so let's do some fine tuning.
    ;; (bw-finetune wins)
    ;; (message "Done in %d rounds" round)
    ))


(defcustom display-buffer-function nil
  "If non-nil, function to call to handle `display-buffer'.
It will receive two args, the buffer and a flag which if non-nil
means that the currently selected window is not acceptable.  It
should choose or create a window, display the specified buffer in
it, and return the window.

Commands such as `switch-to-buffer-other-window' and
`find-file-other-window' work using this function."
  :type '(choice
	  (const nil)
	  (function :tag "function"))
  :group 'windows)

(defcustom special-display-buffer-names nil
  "List of names of buffers that should be displayed specially.
Displaying a buffer with `display-buffer' or `pop-to-buffer', if
its name is in this list, displays the buffer in a way specified
by `special-display-function'.  `special-display-popup-frame'
\(the default for `special-display-function') usually displays
the buffer in a separate frame made with the parameters specified
by `special-display-frame-alist'.  If `special-display-function'
has been set to some other function, that function is called with
the buffer as first, and nil as second argument.

Alternatively, an element of this list can be specified as
\(BUFFER-NAME FRAME-PARAMETERS), where BUFFER-NAME is a buffer
name and FRAME-PARAMETERS an alist of \(PARAMETER . VALUE) pairs.
`special-display-popup-frame' will interpret such pairs as frame
parameters when it creates a special frame, overriding the
corresponding values from `special-display-frame-alist'.

As a special case, if FRAME-PARAMETERS contains (same-window . t)
`special-display-popup-frame' displays that buffer in the
selected window.  If FRAME-PARAMETERS contains (same-frame . t),
it displays that buffer in a window on the selected frame.

If `special-display-function' specifies some other function than
`special-display-popup-frame', that function is called with the
buffer named BUFFER-NAME as first, and FRAME-PARAMETERS as second
argument.

Finally, an element of this list can be also specified as
\(BUFFER-NAME FUNCTION OTHER-ARGS).  In that case,
`special-display-popup-frame' will call FUNCTION with the buffer
named BUFFER-NAME as first argument, and OTHER-ARGS as the
second.  If `special-display-function' specifies some other
function, that function is called with the buffer named
BUFFER-NAME as first, and the element's cdr as second argument.

If this variable appears \"not to work\", because you added a
name to it but the corresponding buffer is displayed in the
selected window, look at the values of `same-window-buffer-names'
and `same-window-regexps'.  Those variables take precedence over
this one.

See also `special-display-regexps'."
  :type '(repeat
	  (choice :tag "Buffer"
		  :value ""
		  (string :format "%v")
		  (cons :tag "With parameters"
			:format "%v"
			:value ("" . nil)
			(string :format "%v")
			(repeat :tag "Parameters"
				(cons :format "%v"
				      (symbol :tag "Parameter")
				      (sexp :tag "Value"))))
		  (list :tag "With function"
			:format "%v"
			:value ("" . nil)
			(string :format "%v")
			(function :tag "Function")
			(repeat :tag "Arguments" (sexp)))))
  :group 'windows
  :group 'frames)

;;;###autoload
(put 'special-display-buffer-names 'risky-local-variable t)

(defcustom special-display-regexps nil
  "List of regexps saying which buffers should be displayed specially.
Displaying a buffer with `display-buffer' or `pop-to-buffer', if
any regexp in this list matches its name, displays it specially
using `special-display-function'.  `special-display-popup-frame'
\(the default for `special-display-function') usually displays
the buffer in a separate frame made with the parameters specified
by `special-display-frame-alist'.  If `special-display-function'
has been set to some other function, that function is called with
the buffer as first, and nil as second argument.

Alternatively, an element of this list can be specified as
\(REGEXP FRAME-PARAMETERS), where REGEXP is a regexp as above and
FRAME-PARAMETERS an alist of (PARAMETER . VALUE) pairs.
`special-display-popup-frame' will then interpret these pairs as
frame parameters when creating a special frame for a buffer whose
name matches REGEXP, overriding the corresponding values from
`special-display-frame-alist'.

As a special case, if FRAME-PARAMETERS contains (same-window . t)
`special-display-popup-frame' displays buffers matching REGEXP in
the selected window.  \(same-frame . t) in FRAME-PARAMETERS means
to display such buffers in a window on the selected frame.

If `special-display-function' specifies some other function than
`special-display-popup-frame', that function is called with the
buffer whose name matched REGEXP as first, and FRAME-PARAMETERS
as second argument.

Finally, an element of this list can be also specified as
\(REGEXP FUNCTION OTHER-ARGS).  `special-display-popup-frame'
will then call FUNCTION with the buffer whose name matched
REGEXP as first, and OTHER-ARGS as second argument.  If
`special-display-function' specifies some other function, that
function is called with the buffer whose name matched REGEXP
as first, and the element's cdr as second argument.

If this variable appears \"not to work\", because you added a
name to it but the corresponding buffer is displayed in the
selected window, look at the values of `same-window-buffer-names'
and `same-window-regexps'.  Those variables take precedence over
this one.

See also `special-display-buffer-names'."
  :type '(repeat
	  (choice :tag "Buffer"
		  :value ""
		  (regexp :format "%v")
		  (cons :tag "With parameters"
			:format "%v"
			:value ("" . nil)
			(regexp :format "%v")
			(repeat :tag "Parameters"
				(cons :format "%v"
				      (symbol :tag "Parameter")
				      (sexp :tag "Value"))))
		  (list :tag "With function"
			:format "%v"
			:value ("" . nil)
			(regexp :format "%v")
			(function :tag "Function")
			(repeat :tag "Arguments" (sexp)))))
  :group 'windows
  :group 'frames)

(defun special-display-p (buffer-name)
  "Return non-nil if a buffer named BUFFER-NAME gets a special frame.
More precisely, return t if `special-display-buffer-names' or
`special-display-regexps' contain a string entry equaling or
matching BUFFER-NAME.  If `special-display-buffer-names' or
`special-display-regexps' contain a list entry whose car equals
or matches BUFFER-NAME, the return value is the cdr of that
entry."
  (let (tmp)
    (cond
     ((not (stringp buffer-name)))
     ((member buffer-name special-display-buffer-names)
      t)
     ((setq tmp (assoc buffer-name special-display-buffer-names))
      (cdr tmp))
     ((catch 'found
	(dolist (regexp special-display-regexps)
	  (cond
	   ((stringp regexp)
	    (when (string-match-p regexp buffer-name)
	      (throw 'found t)))
	   ((and (consp regexp) (stringp (car regexp))
		 (string-match-p (car regexp) buffer-name))
	    (throw 'found (cdr regexp))))))))))

(defcustom special-display-function 'special-display-popup-frame
  "Function to call for displaying special buffers.
This function is called with two arguments - the buffer and,
optionally, a list - and should return a window displaying that
buffer.  The default value usually makes a separate frame for the
buffer using `special-display-frame-alist' to specify the frame
parameters.  See the definition of `special-display-popup-frame'
for how to specify such a function.

A buffer is special when its name is either listed in
`special-display-buffer-names' or matches a regexp in
`special-display-regexps'."
  :type 'function
  :group 'frames)

(defcustom same-window-buffer-names nil
  "List of names of buffers that should appear in the \"same\" window.
`display-buffer' and `pop-to-buffer' show a buffer whose name is
on this list in the selected rather than some other window.

An element of this list can be a cons cell instead of just a
string.  In that case, the cell's car must be a string specifying
the buffer name.  This is for compatibility with
`special-display-buffer-names'; the cdr of the cons cell is
ignored.

See also `same-window-regexps'."
 :type '(repeat (string :format "%v"))
 :group 'windows)

(defcustom same-window-regexps nil
  "List of regexps saying which buffers should appear in the \"same\" window.
`display-buffer' and `pop-to-buffer' show a buffer whose name
matches a regexp on this list in the selected rather than some
other window.

An element of this list can be a cons cell instead of just a
string.  In that case, the cell's car must be a regexp matching
the buffer name.  This is for compatibility with
`special-display-regexps'; the cdr of the cons cell is ignored.

See also `same-window-buffer-names'."
  :type '(repeat (regexp :format "%v"))
  :group 'windows)

(defun same-window-p (buffer-name)
  "Return non-nil if a buffer named BUFFER-NAME would be shown in the \"same\" window.
This function returns non-nil if `display-buffer' or
`pop-to-buffer' would show a buffer named BUFFER-NAME in the
selected rather than \(as usual\) some other window.  See
`same-window-buffer-names' and `same-window-regexps'."
  (cond
   ((not (stringp buffer-name)))
   ;; The elements of `same-window-buffer-names' can be buffer
   ;; names or cons cells whose cars are buffer names.
   ((member buffer-name same-window-buffer-names))
   ((assoc buffer-name same-window-buffer-names))
   ((catch 'found
      (dolist (regexp same-window-regexps)
	;; The elements of `same-window-regexps' can be regexps
	;; or cons cells whose cars are regexps.
	(when (or (and (stringp regexp)
		       (string-match regexp buffer-name))
		  (and (consp regexp) (stringp (car regexp))
		       (string-match-p (car regexp) buffer-name)))
	  (throw 'found t)))))))

(defcustom pop-up-frames nil
  "Whether `display-buffer' should make a separate frame.
If nil, never make a separate frame.
If the value is `graphic-only', make a separate frame
on graphic displays only.
Any other non-nil value means always make a separate frame."
  :type '(choice
	  (const :tag "Never" nil)
	  (const :tag "On graphic displays only" graphic-only)
	  (const :tag "Always" t))
  :group 'windows)

(defcustom display-buffer-reuse-frames nil
  "Non-nil means `display-buffer' should reuse frames.
If the buffer in question is already displayed in a frame, raise
that frame."
  :type 'boolean
  :version "21.1"
  :group 'windows)

(defcustom pop-up-windows t
  "Non-nil means `display-buffer' should make a new window."
  :type 'boolean
  :group 'windows)

(defcustom split-window-preferred-function 'split-window-sensibly
  "Function called by `display-buffer' routines to split a window.
This function is called with a window as single argument and is
supposed to split that window and return the new window.  If the
window can (or shall) not be split, it is supposed to return nil.
The default is to call the function `split-window-sensibly' which
tries to split the window in a way which seems most suitable.
You can customize the options `split-height-threshold' and/or
`split-width-threshold' in order to have `split-window-sensibly'
prefer either vertical or horizontal splitting.

If you set this to any other function, bear in mind that the
`display-buffer' routines may call this function two times.  The
argument of the first call is the largest window on its frame.
If that call fails to return a live window, the function is
called again with the least recently used window as argument.  If
that call fails too, `display-buffer' will use an existing window
to display its buffer.

The window selected at the time `display-buffer' was invoked is
still selected when this function is called.  Hence you can
compare the window argument with the value of `selected-window'
if you intend to split the selected window instead or if you do
not want to split the selected window."
  :type 'function
  :version "23.1"
  :group 'windows)

(defcustom split-height-threshold 80
  "Minimum height for splitting windows sensibly.
If this is an integer, `split-window-sensibly' may split a window
vertically only if it has at least this many lines.  If this is
nil, `split-window-sensibly' is not allowed to split a window
vertically.  If, however, a window is the only window on its
frame, `split-window-sensibly' may split it vertically
disregarding the value of this variable."
  :type '(choice (const nil) (integer :tag "lines"))
  :version "23.1"
  :group 'windows)

(defcustom split-width-threshold 160
  "Minimum width for splitting windows sensibly.
If this is an integer, `split-window-sensibly' may split a window
horizontally only if it has at least this many columns.  If this
is nil, `split-window-sensibly' is not allowed to split a window
horizontally."
  :type '(choice (const nil) (integer :tag "columns"))
  :version "23.1"
  :group 'windows)

(defun window-splittable-p (window &optional horizontal)
  "Return non-nil if `split-window-sensibly' may split WINDOW.
Optional argument HORIZONTAL nil or omitted means check whether
`split-window-sensibly' may split WINDOW vertically.  HORIZONTAL
non-nil means check whether WINDOW may be split horizontally.

WINDOW may be split vertically when the following conditions
hold:
- `window-size-fixed' is either nil or equals `width' for the
  buffer of WINDOW.
- `split-height-threshold' is an integer and WINDOW is at least as
  high as `split-height-threshold'.
- When WINDOW is split evenly, the emanating windows are at least
  `window-min-height' lines tall and can accommodate at least one
  line plus - if WINDOW has one - a mode line.

WINDOW may be split horizontally when the following conditions
hold:
- `window-size-fixed' is either nil or equals `height' for the
  buffer of WINDOW.
- `split-width-threshold' is an integer and WINDOW is at least as
  wide as `split-width-threshold'.
- When WINDOW is split evenly, the emanating windows are at least
  `window-min-width' or two (whichever is larger) columns wide."
  (when (window-live-p window)
    (with-current-buffer (window-buffer window)
      (if horizontal
	  ;; A window can be split horizontally when its width is not
	  ;; fixed, it is at least `split-width-threshold' columns wide
	  ;; and at least twice as wide as `window-min-width' and 2 (the
	  ;; latter value is hardcoded).
	  (and (memq window-size-fixed '(nil height))
	       ;; Testing `window-full-width-p' here hardly makes any
	       ;; sense nowadays.  This can be done more intuitively by
	       ;; setting up `split-width-threshold' appropriately.
	       (numberp split-width-threshold)
	       (>= (window-width window)
		   (max split-width-threshold
			(* 2 (max window-min-width 2)))))
	;; A window can be split vertically when its height is not
	;; fixed, it is at least `split-height-threshold' lines high,
	;; and it is at least twice as high as `window-min-height' and 2
	;; if it has a modeline or 1.
	(and (memq window-size-fixed '(nil width))
	     (numberp split-height-threshold)
	     (>= (window-height window)
		 (max split-height-threshold
		      (* 2 (max window-min-height
				(if mode-line-format 2 1))))))))))

(defun split-window-sensibly (window)
  "Split WINDOW in a way suitable for `display-buffer'.
If `split-height-threshold' specifies an integer, WINDOW is at
least `split-height-threshold' lines tall and can be split
vertically, split WINDOW into two windows one above the other and
return the lower window.  Otherwise, if `split-width-threshold'
specifies an integer, WINDOW is at least `split-width-threshold'
columns wide and can be split horizontally, split WINDOW into two
windows side by side and return the window on the right.  If this
can't be done either and WINDOW is the only window on its frame,
try to split WINDOW vertically disregarding any value specified
by `split-height-threshold'.  If that succeeds, return the lower
window.  Return nil otherwise.

By default `display-buffer' routines call this function to split
the largest or least recently used window.  To change the default
customize the option `split-window-preferred-function'.

You can enforce this function to not split WINDOW horizontally,
by setting \(or binding) the variable `split-width-threshold' to
nil.  If, in addition, you set `split-height-threshold' to zero,
chances increase that this function does split WINDOW vertically.

In order to not split WINDOW vertically, set \(or bind) the
variable `split-height-threshold' to nil.  Additionally, you can
set `split-width-threshold' to zero to make a horizontal split
more likely to occur.

Have a look at the function `window-splittable-p' if you want to
know how `split-window-sensibly' determines whether WINDOW can be
split."
  (or (and (window-splittable-p window)
	   ;; Split window vertically.
	   (with-selected-window window
	     (split-window-vertically)))
      (and (window-splittable-p window t)
	   ;; Split window horizontally.
	   (with-selected-window window
	     (split-window-horizontally)))
      (and (eq window (frame-root-window (window-frame window)))
	   (not (window-minibuffer-p window))
	   ;; If WINDOW is the only window on its frame and is not the
	   ;; minibuffer window, try to split it vertically disregarding
	   ;; the value of `split-height-threshold'.
	   (let ((split-height-threshold 0))
	     (when (window-splittable-p window)
	       (with-selected-window window
		 (split-window-vertically)))))))

(defun window--try-to-split-window (window)
  "Try to split WINDOW.
Return value returned by `split-window-preferred-function' if it
represents a live window, nil otherwise."
      (and (window-live-p window)
	   (not (frame-parameter (window-frame window) 'unsplittable))
	   (let ((new-window
		  ;; Since `split-window-preferred-function' might
		  ;; throw an error use `condition-case'.
		  (condition-case nil
		      (funcall split-window-preferred-function window)
		    (error nil))))
	     (and (window-live-p new-window) new-window))))

(defun window--frame-usable-p (frame)
  "Return FRAME if it can be used to display a buffer."
  (when (frame-live-p frame)
    (let ((window (frame-root-window frame)))
      ;; `frame-root-window' may be an internal window which is considered
      ;; "dead" by `window-live-p'.  Hence if `window' is not live we
      ;; implicitly know that `frame' has a visible window we can use.
      (unless (and (window-live-p window)
                   (or (window-minibuffer-p window)
                       ;; If the window is soft-dedicated, the frame is usable.
                       ;; Actually, even if the window is really dedicated,
                       ;; the frame is still usable by splitting it.
                       ;; At least Emacs-22 allowed it, and it is desirable
                       ;; when displaying same-frame windows.
                       nil ; (eq t (window-dedicated-p window))
                       ))
	frame))))

(defcustom even-window-heights t
  "If non-nil `display-buffer' will try to even window heights.
Otherwise `display-buffer' will leave the window configuration
alone.  Heights are evened only when `display-buffer' chooses a
window that appears above or below the selected window."
  :type 'boolean
  :group 'windows)

(defun window--even-window-heights (window)
  "Even heights of WINDOW and selected window.
Do this only if these windows are vertically adjacent to each
other, `even-window-heights' is non-nil, and the selected window
is higher than WINDOW."
  (when (and even-window-heights
	     (not (eq window (selected-window)))
	     ;; Don't resize minibuffer windows.
	     (not (window-minibuffer-p (selected-window)))
	     (> (window-height (selected-window)) (window-height window))
	     (eq (window-frame window) (window-frame (selected-window)))
	     (let ((sel-edges (window-edges (selected-window)))
		   (win-edges (window-edges window)))
	       (and (= (nth 0 sel-edges) (nth 0 win-edges))
		    (= (nth 2 sel-edges) (nth 2 win-edges))
		    (or (= (nth 1 sel-edges) (nth 3 win-edges))
			(= (nth 3 sel-edges) (nth 1 win-edges))))))
    (let ((window-min-height 1))
      ;; Don't throw an error if we can't even window heights for
      ;; whatever reason.
      (condition-case nil
	  (enlarge-window (/ (- (window-height window) (window-height)) 2))
	(error nil)))))

(defun window--display-buffer-1 (window)
  "Raise the frame containing WINDOW.
Do not raise the selected frame.  Return WINDOW."
  (let* ((frame (window-frame window))
	 (visible (frame-visible-p frame)))
    (unless (or (not visible)
		;; Assume the selected frame is already visible enough.
		(eq frame (selected-frame))
		;; Assume the frame from which we invoked the minibuffer
		;; is visible.
		(and (minibuffer-window-active-p (selected-window))
		     (eq frame (window-frame (minibuffer-selected-window)))))
      (raise-frame frame))
    window))

(defun window--display-buffer-2 (buffer window &optional dedicated)
  "Display BUFFER in WINDOW and make its frame visible.
Set `window-dedicated-p' to DEDICATED if non-nil.
Return WINDOW."
  (when (and (buffer-live-p buffer) (window-live-p window))
    (set-window-buffer window buffer)
    (when dedicated
      (set-window-dedicated-p window dedicated))
    (window--display-buffer-1 window)))

(defvar display-buffer-mark-dedicated nil
  "If non-nil, `display-buffer' marks the windows it creates as dedicated.
The actual non-nil value of this variable will be copied to the
`window-dedicated-p' flag.")

(defun display-buffer (buffer-or-name &optional not-this-window frame)
  "Make buffer BUFFER-OR-NAME appear in some window but don't select it.
BUFFER-OR-NAME must be a buffer or the name of an existing
buffer.  Return the window chosen to display BUFFER-OR-NAME or
nil if no such window is found.

Optional argument NOT-THIS-WINDOW non-nil means display the
buffer in a window other than the selected one, even if it is
already displayed in the selected window.

Optional argument FRAME specifies which frames to investigate
when the specified buffer is already displayed.  If the buffer is
already displayed in some window on one of these frames simply
return that window.  Possible values of FRAME are:

`visible' - consider windows on all visible frames on the current
terminal.

0 - consider windows on all visible or iconified frames on the
current terminal.

t - consider windows on all frames.

A specific frame - consider windows on that frame only.

nil - consider windows on the selected frame \(actually the
last non-minibuffer frame\) only.  If, however, either
`display-buffer-reuse-frames' or `pop-up-frames' is non-nil
\(non-nil and not graphic-only on a text-only terminal),
consider all visible or iconified frames on the current terminal."
  (interactive "BDisplay buffer:\nP")
  (let* ((can-use-selected-window
	  ;; The selected window is usable unless either NOT-THIS-WINDOW
	  ;; is non-nil, it is dedicated to its buffer, or it is the
	  ;; `minibuffer-window'.
	  (not (or not-this-window
		   (window-dedicated-p (selected-window))
		   (window-minibuffer-p))))
	 (buffer (if (bufferp buffer-or-name)
		     buffer-or-name
		   (get-buffer buffer-or-name)))
	 (name-of-buffer (buffer-name buffer))
	 ;; On text-only terminals do not pop up a new frame when
	 ;; `pop-up-frames' equals graphic-only.
	 (use-pop-up-frames (if (eq pop-up-frames 'graphic-only)
				(display-graphic-p)
			      pop-up-frames))
	 ;; `frame-to-use' is the frame where to show `buffer' - either
	 ;; the selected frame or the last nonminibuffer frame.
	 (frame-to-use
	  (or (window--frame-usable-p (selected-frame))
	      (window--frame-usable-p (last-nonminibuffer-frame))))
	 ;; `window-to-use' is the window we use for showing `buffer'.
	 window-to-use)
    (cond
     ((not (buffer-live-p buffer))
      (error "No such buffer %s" buffer))
     (display-buffer-function
      ;; Let `display-buffer-function' do the job.
      (funcall display-buffer-function buffer not-this-window))
     ((and (not not-this-window)
	   (eq (window-buffer (selected-window)) buffer))
      ;; The selected window already displays BUFFER and
      ;; `not-this-window' is nil, so use it.
      (window--display-buffer-1 (selected-window)))
     ((and can-use-selected-window (same-window-p name-of-buffer))
      ;; If the buffer's name tells us to use the selected window do so.
      (window--display-buffer-2 buffer (selected-window)))
     ((let ((frames (or frame
			(and (or use-pop-up-frames
				 display-buffer-reuse-frames
				 (not (last-nonminibuffer-frame)))
			     0)
			(last-nonminibuffer-frame))))
	(setq window-to-use
	      (catch 'found
		;; Search frames for a window displaying BUFFER.  Return
		;; the selected window only if we are allowed to do so.
		(dolist (window (get-buffer-window-list buffer 'nomini frames))
		  (when (or can-use-selected-window
			    (not (eq (selected-window) window)))
		    (throw 'found window))))))
      ;; The buffer is already displayed in some window; use that.
      (window--display-buffer-1 window-to-use))
     ((and special-display-function
	   ;; `special-display-p' returns either t or a list of frame
	   ;; parameters to pass to `special-display-function'.
	   (let ((pars (special-display-p name-of-buffer)))
	     (when pars
	       (funcall special-display-function
			buffer (if (listp pars) pars))))))
     ((or use-pop-up-frames (not frame-to-use))
      ;; We want or need a new frame.
      (let ((win (frame-selected-window (funcall pop-up-frame-function))))
        (window--display-buffer-2 buffer win display-buffer-mark-dedicated)))
     ((and pop-up-windows
	   ;; Make a new window.
	   (or (not (frame-parameter frame-to-use 'unsplittable))
	       ;; If the selected frame cannot be split look at
	       ;; `last-nonminibuffer-frame'.
	       (and (eq frame-to-use (selected-frame))
		    (setq frame-to-use (last-nonminibuffer-frame))
		    (window--frame-usable-p frame-to-use)
		    (not (frame-parameter frame-to-use 'unsplittable))))
	   ;; Attempt to split largest or least recently used window.
	   (setq window-to-use
		 (or (window--try-to-split-window
		      (get-largest-window frame-to-use t))
		     (window--try-to-split-window
		      (get-lru-window frame-to-use t)))))
      (window--display-buffer-2 buffer window-to-use
                                display-buffer-mark-dedicated))
     ((let ((window-to-undedicate
	     ;; When NOT-THIS-WINDOW is non-nil, temporarily dedicate
	     ;; the selected window to its buffer, to avoid that some of
	     ;; the `get-' routines below choose it.  (Bug#1415)
	     (and not-this-window (not (window-dedicated-p))
		  (set-window-dedicated-p (selected-window) t)
		  (selected-window))))
	(unwind-protect
	    (setq window-to-use
		  ;; Reuse an existing window.
		  (or (get-lru-window frame-to-use)
		      (let ((window (get-buffer-window buffer 'visible)))
			(unless (and not-this-window
				     (eq window (selected-window)))
			  window))
		      (get-largest-window 'visible)
		      (let ((window (get-buffer-window buffer 0)))
			(unless (and not-this-window
				     (eq window (selected-window)))
			  window))
		      (get-largest-window 0)
		      (frame-selected-window (funcall pop-up-frame-function))))
	  (when (window-live-p window-to-undedicate)
	    ;; Restore dedicated status of selected window.
	    (set-window-dedicated-p window-to-undedicate nil))))
      (window--even-window-heights window-to-use)
      (window--display-buffer-2 buffer window-to-use)))))

(defun pop-to-buffer (buffer-or-name &optional other-window norecord)
  "Select buffer BUFFER-OR-NAME in some window, preferably a different one.
BUFFER-OR-NAME may be a buffer, a string \(a buffer name), or
nil.  If BUFFER-OR-NAME is a string not naming an existent
buffer, create a buffer with that name.  If BUFFER-OR-NAME is
nil, choose some other buffer.

If `pop-up-windows' is non-nil, windows can be split to display
the buffer.  If optional second arg OTHER-WINDOW is non-nil,
insist on finding another window even if the specified buffer is
already visible in the selected window, and ignore
`same-window-regexps' and `same-window-buffer-names'.

If the window to show BUFFER-OR-NAME is not on the selected
frame, raise that window's frame and give it input focus.

This function returns the buffer it switched to.  This uses the
function `display-buffer' as a subroutine; see the documentation
of `display-buffer' for additional customization information.

Optional third arg NORECORD non-nil means do not put this buffer
at the front of the list of recently selected ones."
  (let ((buffer
         ;; FIXME: This behavior is carried over from the previous C version
         ;; of pop-to-buffer, but really we should use just
         ;; `get-buffer' here.
         (if (null buffer-or-name) (other-buffer (current-buffer))
           (or (get-buffer buffer-or-name)
               (let ((buf (get-buffer-create buffer-or-name)))
                 (set-buffer-major-mode buf)
                 buf))))
	(old-frame (selected-frame))
	new-window new-frame)
    (set-buffer buffer)
    (setq new-window (display-buffer buffer other-window))
    (select-window new-window norecord)
    (setq new-frame (window-frame new-window))
    (unless (eq new-frame old-frame)
      ;; `display-buffer' has chosen another frame, make sure it gets
      ;; input focus and is risen.
      (select-frame-set-input-focus new-frame))
    buffer))

(defun set-window-text-height (window height)
  "Set the height in lines of the text display area of WINDOW to HEIGHT.
HEIGHT doesn't include the mode line or header line, if any, or
any partial-height lines in the text display area.

Note that the current implementation of this function cannot
always set the height exactly, but attempts to be conservative,
by allocating more lines than are actually needed in the case
where some error may be present."
  (let ((delta (- height (window-text-height window))))
    (unless (zerop delta)
      ;; Setting window-min-height to a value like 1 can lead to very
      ;; bizarre displays because it also allows Emacs to make *other*
      ;; windows 1-line tall, which means that there's no more space for
      ;; the modeline.
      (let ((window-min-height (min 2 height))) ; One text line plus a modeline.
	(if (and window (not (eq window (selected-window))))
	    (save-selected-window
	      (select-window window 'norecord)
	      (enlarge-window delta))
	  (enlarge-window delta))))))


(defun enlarge-window-horizontally (columns)
  "Make selected window COLUMNS wider.
Interactively, if no argument is given, make selected window one
column wider."
  (interactive "p")
  (enlarge-window columns t))

(defun shrink-window-horizontally (columns)
  "Make selected window COLUMNS narrower.
Interactively, if no argument is given, make selected window one
column narrower."
  (interactive "p")
  (shrink-window columns t))

(defun window-buffer-height (window)
  "Return the height (in screen lines) of the buffer that WINDOW is displaying."
  (with-current-buffer (window-buffer window)
    (max 1
	 (count-screen-lines (point-min) (point-max)
			     ;; If buffer ends with a newline, ignore it when
			     ;; counting height unless point is after it.
			     (eobp)
			     window))))

(defun count-screen-lines (&optional beg end count-final-newline window)
  "Return the number of screen lines in the region.
The number of screen lines may be different from the number of actual lines,
due to line breaking, display table, etc.

Optional arguments BEG and END default to `point-min' and `point-max'
respectively.

If region ends with a newline, ignore it unless optional third argument
COUNT-FINAL-NEWLINE is non-nil.

The optional fourth argument WINDOW specifies the window used for obtaining
parameters such as width, horizontal scrolling, and so on.  The default is
to use the selected window's parameters.

Like `vertical-motion', `count-screen-lines' always uses the current buffer,
regardless of which buffer is displayed in WINDOW.  This makes possible to use
`count-screen-lines' in any buffer, whether or not it is currently displayed
in some window."
  (unless beg
    (setq beg (point-min)))
  (unless end
    (setq end (point-max)))
  (if (= beg end)
      0
    (save-excursion
      (save-restriction
        (widen)
        (narrow-to-region (min beg end)
                          (if (and (not count-final-newline)
                                   (= ?\n (char-before (max beg end))))
                              (1- (max beg end))
                            (max beg end)))
        (goto-char (point-min))
        (1+ (vertical-motion (buffer-size) window))))))

(defun fit-window-to-buffer (&optional window max-height min-height)
  "Adjust height of WINDOW to display its buffer's contents exactly.
WINDOW defaults to the selected window.
Optional argument MAX-HEIGHT specifies the maximum height of the
window and defaults to the maximum permissible height of a window
on WINDOW's frame.
Optional argument MIN-HEIGHT specifies the minimum height of the
window and defaults to `window-min-height'.
Both, MAX-HEIGHT and MIN-HEIGHT are specified in lines and
include the mode line and header line, if any.

Return non-nil if height was orderly adjusted, nil otherwise.

Caution: This function can delete WINDOW and/or other windows
when their height shrinks to less than MIN-HEIGHT."
  (interactive)
  ;; Do all the work in WINDOW and its buffer and restore the selected
  ;; window and the current buffer when we're done.
  (let ((old-buffer (current-buffer))
	value)
    (with-selected-window (or window (setq window (selected-window)))
      (set-buffer (window-buffer))
      ;; Use `condition-case' to handle any fixed-size windows and other
      ;; pitfalls nearby.
      (condition-case nil
	  (let* (;; MIN-HEIGHT must not be less than 1 and defaults to
		 ;; `window-min-height'.
		 (min-height (max (or min-height window-min-height) 1))
		 (max-window-height
		  ;; Maximum height of any window on this frame.
		  (min (window-height (frame-root-window)) (frame-height)))
		 ;; MAX-HEIGHT must not be larger than max-window-height and
		 ;; defaults to max-window-height.
		 (max-height
		  (min (or max-height max-window-height) max-window-height))
		 (desired-height
		  ;; The height necessary to show all of WINDOW's buffer,
		  ;; constrained by MIN-HEIGHT and MAX-HEIGHT.
		  (max
		   (min
		    ;; For an empty buffer `count-screen-lines' returns zero.
		    ;; Even in that case we need one line for the cursor.
		    (+ (max (count-screen-lines) 1)
		       ;; For non-minibuffers count the mode line, if any.
		       (if (and (not (window-minibuffer-p)) mode-line-format)
			   1 0)
		       ;; Count the header line, if any.
		       (if header-line-format 1 0))
		    max-height)
		   min-height))
		 (delta
		  ;; How much the window height has to change.
		  (if (= (window-height) (window-height (frame-root-window)))
		      ;; Don't try to resize a full-height window.
		      0
		    (- desired-height (window-height))))
		 ;; Do something reasonable so `enlarge-window' can make
		 ;; windows as small as MIN-HEIGHT.
		 (window-min-height (min min-height window-min-height)))
	    ;; Don't try to redisplay with the cursor at the end on its
	    ;; own line--that would force a scroll and spoil things.
	    (when (and (eobp) (bolp) (not (bobp)))
	      (set-window-point window (1- (window-point))))
	    ;; Adjust WINDOW's height to the nominally correct one
	    ;; (which may actually be slightly off because of variable
	    ;; height text, etc).
	    (unless (zerop delta)
	      (enlarge-window delta))
	    ;; `enlarge-window' might have deleted WINDOW, so make sure
	    ;; WINDOW's still alive for the remainder of this.
	    ;; Note: Deleting WINDOW is clearly counter-intuitive in
	    ;; this context, but we can't do much about it given the
	    ;; current semantics of `enlarge-window'.
	    (when (window-live-p window)
	      ;; Check if the last line is surely fully visible.  If
	      ;; not, enlarge the window.
	      (let ((end (save-excursion
			   (goto-char (point-max))
			   (when (and (bolp) (not (bobp)))
			     ;; Don't include final newline.
			     (backward-char 1))
			   (when truncate-lines
			     ;; If line-wrapping is turned off, test the
			     ;; beginning of the last line for
			     ;; visibility instead of the end, as the
			     ;; end of the line could be invisible by
			     ;; virtue of extending past the edge of the
			     ;; window.
			     (forward-line 0))
			   (point))))
		(set-window-vscroll window 0)
		(while (and (< desired-height max-height)
			    (= desired-height (window-height))
			    (not (pos-visible-in-window-p end)))
		  (enlarge-window 1)
		  (setq desired-height (1+ desired-height))))
	      ;; Return non-nil only if nothing "bad" happened.
	      (setq value t)))
	(error nil)))
    (when (buffer-live-p old-buffer)
      (set-buffer old-buffer))
    value))

(defun window-safely-shrinkable-p (&optional window)
  "Return t if WINDOW can be shrunk without shrinking other windows.
WINDOW defaults to the selected window."
  (with-selected-window (or window (selected-window))
    (let ((edges (window-edges)))
      (or (= (nth 2 edges) (nth 2 (window-edges (previous-window))))
	  (= (nth 0 edges) (nth 0 (window-edges (next-window))))))))

(defun shrink-window-if-larger-than-buffer (&optional window)
  "Shrink height of WINDOW if its buffer doesn't need so many lines.
More precisely, shrink WINDOW vertically to be as small as
possible, while still showing the full contents of its buffer.
WINDOW defaults to the selected window.

Do not shrink to less than `window-min-height' lines.  Do nothing
if the buffer contains more lines than the present window height,
or if some of the window's contents are scrolled out of view, or
if shrinking this window would also shrink another window, or if
the window is the only window of its frame.

Return non-nil if the window was shrunk, nil otherwise."
  (interactive)
  (when (null window)
    (setq window (selected-window)))
  (let* ((frame (window-frame window))
	 (mini (frame-parameter frame 'minibuffer))
	 (edges (window-edges window)))
    (if (and (not (eq window (frame-root-window frame)))
	     (window-safely-shrinkable-p window)
	     (pos-visible-in-window-p (point-min) window)
	     (not (eq mini 'only))
	     (or (not mini)
		 (let ((mini-window (minibuffer-window frame)))
		   (or (null mini-window)
		       (not (eq frame (window-frame mini-window)))
		       (< (nth 3 edges)
			  (nth 1 (window-edges mini-window)))
		       (> (nth 1 edges)
			  (frame-parameter frame 'menu-bar-lines))))))
	(fit-window-to-buffer window (window-height window)))))

(defun kill-buffer-and-window ()
  "Kill the current buffer and delete the selected window."
  (interactive)
  (let ((window-to-delete (selected-window))
	(buffer-to-kill (current-buffer))
	(delete-window-hook (lambda ()
			      (condition-case nil
				  (delete-window)
				(error nil)))))
    (unwind-protect
	(progn
	  (add-hook 'kill-buffer-hook delete-window-hook t t)
	  (if (kill-buffer (current-buffer))
	      ;; If `delete-window' failed before, we rerun it to regenerate
	      ;; the error so it can be seen in the echo area.
	      (when (eq (selected-window) window-to-delete)
		(delete-window))))
      ;; If the buffer is not dead for some reason (probably because
      ;; of a `quit' signal), remove the hook again.
      (condition-case nil
	  (with-current-buffer buffer-to-kill
	    (remove-hook 'kill-buffer-hook delete-window-hook t))
	(error nil)))))

(defun quit-window (&optional kill window)
  "Quit WINDOW and bury its buffer.
With a prefix argument, kill the buffer instead.  WINDOW defaults
to the selected window.

If WINDOW is non-nil, dedicated, or a minibuffer window, delete
it and, if it's alone on its frame, its frame too.  Otherwise, or
if deleting WINDOW fails in any of the preceding cases, display
another buffer in WINDOW using `switch-to-buffer'.

Optional argument KILL non-nil means kill WINDOW's buffer.
Otherwise, bury WINDOW's buffer, see `bury-buffer'."
  (interactive "P")
  (let ((buffer (window-buffer window)))
    (if (or window
	    (window-minibuffer-p window)
	    (window-dedicated-p window))
	;; WINDOW is either non-nil, a minibuffer window, or dedicated;
	;; try to delete it.
	(let* ((window (or window (selected-window)))
	       (frame (window-frame window)))
	  (if (eq window (frame-root-window frame))
	      ;; WINDOW is alone on its frame.  `delete-windows-on'
	      ;; knows how to handle that case.
	      (delete-windows-on buffer frame)
	    ;; There are other windows on its frame, delete WINDOW.
	    (delete-window window)))
      ;; Otherwise, switch to another buffer in the selected window.
      (switch-to-buffer nil))

    ;; Deal with the buffer.
    (if kill
	(kill-buffer buffer)
      (bury-buffer buffer))))


(defvar recenter-last-op nil
  "Indicates the last recenter operation performed.
Possible values: `top', `middle', `bottom', integer or float numbers.")

(defcustom recenter-positions '(middle top bottom)
  "Cycling order for `recenter-top-bottom'.
A list of elements with possible values `top', `middle', `bottom',
integer or float numbers that define the cycling order for
the command `recenter-top-bottom'.

Top and bottom destinations are `scroll-margin' lines the from true
window top and bottom.  Middle redraws the frame and centers point
vertically within the window.  Integer number moves current line to
the specified absolute window-line.  Float number between 0.0 and 1.0
means the percentage of the screen space from the top.  The default
cycling order is middle -> top -> bottom."
  :type '(repeat (choice
		  (const :tag "Top" top)
		  (const :tag "Middle" middle)
		  (const :tag "Bottom" bottom)
		  (integer :tag "Line number")
		  (float :tag "Percentage")))
  :version "23.2"
  :group 'windows)

(defun recenter-top-bottom (&optional arg)
  "Move current buffer line to the specified window line.
With no prefix argument, successive calls place point according
to the cycling order defined by `recenter-positions'.

A prefix argument is handled like `recenter':
 With numeric prefix ARG, move current line to window-line ARG.
 With plain `C-u', move current line to window center."
  (interactive "P")
  (cond
   (arg (recenter arg))			; Always respect ARG.
   (t
    (setq recenter-last-op
	  (if (eq this-command last-command)
	      (car (or (cdr (member recenter-last-op recenter-positions))
		       recenter-positions))
	    (car recenter-positions)))
    (let ((this-scroll-margin
	   (min (max 0 scroll-margin)
		(truncate (/ (window-body-height) 4.0)))))
      (cond ((eq recenter-last-op 'middle)
	     (recenter))
	    ((eq recenter-last-op 'top)
	     (recenter this-scroll-margin))
	    ((eq recenter-last-op 'bottom)
	     (recenter (- -1 this-scroll-margin)))
	    ((integerp recenter-last-op)
	     (recenter recenter-last-op))
	    ((floatp recenter-last-op)
	     (recenter (round (* recenter-last-op (window-height))))))))))

(define-key global-map [?\C-l] 'recenter-top-bottom)

(defun move-to-window-line-top-bottom (&optional arg)
  "Position point relative to window.

With a prefix argument ARG, acts like `move-to-window-line'.

With no argument, positions point at center of window.
Successive calls position point at positions defined
by `recenter-positions'."
  (interactive "P")
  (cond
   (arg (move-to-window-line arg))	; Always respect ARG.
   (t
    (setq recenter-last-op
	  (if (eq this-command last-command)
	      (car (or (cdr (member recenter-last-op recenter-positions))
		       recenter-positions))
	    (car recenter-positions)))
    (let ((this-scroll-margin
	   (min (max 0 scroll-margin)
		(truncate (/ (window-body-height) 4.0)))))
      (cond ((eq recenter-last-op 'middle)
	     (call-interactively 'move-to-window-line))
	    ((eq recenter-last-op 'top)
	     (move-to-window-line this-scroll-margin))
	    ((eq recenter-last-op 'bottom)
	     (move-to-window-line (- -1 this-scroll-margin)))
	    ((integerp recenter-last-op)
	     (move-to-window-line recenter-last-op))
	    ((floatp recenter-last-op)
	     (move-to-window-line (round (* recenter-last-op (window-height))))))))))

(define-key global-map [?\M-r] 'move-to-window-line-top-bottom)


;;; Scrolling commands.

;;; Scrolling commands which does not signal errors at top/bottom
;;; of buffer at first key-press (instead moves to top/bottom
;;; of buffer).

(defcustom scroll-error-top-bottom nil
  "Move point to top/bottom of buffer before signalling a scrolling error.
A value of nil means just signal an error if no more scrolling possible.
A value of t means point moves to the beginning or the end of the buffer
\(depending on scrolling direction) when no more scrolling possible.
When point is already on that position, then signal an error."
  :type 'boolean
  :group 'scrolling
  :version "24.1")

(defun scroll-up-command (&optional arg)
  "Scroll text of selected window upward ARG lines; or near full screen if no ARG.
If `scroll-error-top-bottom' is non-nil and `scroll-up' cannot
scroll window further, move cursor to the bottom line.
When point is already on that position, then signal an error.
A near full screen is `next-screen-context-lines' less than a full screen.
Negative ARG means scroll downward.
If ARG is the atom `-', scroll downward by nearly full screen."
  (interactive "^P")
  (cond
   ((null scroll-error-top-bottom)
    (scroll-up arg))
   ((eq arg '-)
    (scroll-down-command nil))
   ((< (prefix-numeric-value arg) 0)
    (scroll-down-command (- (prefix-numeric-value arg))))
   ((eobp)
    (scroll-up arg))			; signal error
   (t
    (condition-case nil
	(scroll-up arg)
      (end-of-buffer
       (if arg
	   ;; When scrolling by ARG lines can't be done,
	   ;; move by ARG lines instead.
	   (forward-line arg)
	 ;; When ARG is nil for full-screen scrolling,
	 ;; move to the bottom of the buffer.
	 (goto-char (point-max))))))))

(put 'scroll-up-command 'scroll-command t)

(defun scroll-down-command (&optional arg)
  "Scroll text of selected window down ARG lines; or near full screen if no ARG.
If `scroll-error-top-bottom' is non-nil and `scroll-down' cannot
scroll window further, move cursor to the top line.
When point is already on that position, then signal an error.
A near full screen is `next-screen-context-lines' less than a full screen.
Negative ARG means scroll upward.
If ARG is the atom `-', scroll upward by nearly full screen."
  (interactive "^P")
  (cond
   ((null scroll-error-top-bottom)
    (scroll-down arg))
   ((eq arg '-)
    (scroll-up-command nil))
   ((< (prefix-numeric-value arg) 0)
    (scroll-up-command (- (prefix-numeric-value arg))))
   ((bobp)
    (scroll-down arg))			; signal error
   (t
    (condition-case nil
	(scroll-down arg)
      (beginning-of-buffer
       (if arg
	   ;; When scrolling by ARG lines can't be done,
	   ;; move by ARG lines instead.
	   (forward-line (- arg))
	 ;; When ARG is nil for full-screen scrolling,
	 ;; move to the top of the buffer.
	 (goto-char (point-min))))))))

(put 'scroll-down-command 'scroll-command t)

;;; Scrolling commands which scroll a line instead of full screen.

(defun scroll-up-line (&optional arg)
  "Scroll text of selected window upward ARG lines; or one line if no ARG.
If ARG is omitted or nil, scroll upward by one line.
This is different from `scroll-up-command' that scrolls a full screen."
  (interactive "p")
  (scroll-up (or arg 1)))

(put 'scroll-up-line 'scroll-command t)

(defun scroll-down-line (&optional arg)
  "Scroll text of selected window down ARG lines; or one line if no ARG.
If ARG is omitted or nil, scroll down by one line.
This is different from `scroll-down-command' that scrolls a full screen."
  (interactive "p")
  (scroll-down (or arg 1)))

(put 'scroll-down-line 'scroll-command t)


(defun scroll-other-window-down (lines)
  "Scroll the \"other window\" down.
For more details, see the documentation for `scroll-other-window'."
  (interactive "P")
  (scroll-other-window
   ;; Just invert the argument's meaning.
   ;; We can do that without knowing which window it will be.
   (if (eq lines '-) nil
     (if (null lines) '-
       (- (prefix-numeric-value lines))))))

(defun beginning-of-buffer-other-window (arg)
  "Move point to the beginning of the buffer in the other window.
Leave mark at previous position.
With arg N, put point N/10 of the way from the true beginning."
  (interactive "P")
  (let ((orig-window (selected-window))
	(window (other-window-for-scrolling)))
    ;; We use unwind-protect rather than save-window-excursion
    ;; because the latter would preserve the things we want to change.
    (unwind-protect
	(progn
	  (select-window window)
	  ;; Set point and mark in that window's buffer.
	  (with-no-warnings
	   (beginning-of-buffer arg))
	  ;; Set point accordingly.
	  (recenter '(t)))
      (select-window orig-window))))

(defun end-of-buffer-other-window (arg)
  "Move point to the end of the buffer in the other window.
Leave mark at previous position.
With arg N, put point N/10 of the way from the true end."
  (interactive "P")
  ;; See beginning-of-buffer-other-window for comments.
  (let ((orig-window (selected-window))
	(window (other-window-for-scrolling)))
    (unwind-protect
	(progn
	  (select-window window)
	  (with-no-warnings
	   (end-of-buffer arg))
	  (recenter '(t)))
      (select-window orig-window))))


(defvar mouse-autoselect-window-timer nil
  "Timer used by delayed window autoselection.")

(defvar mouse-autoselect-window-position nil
  "Last mouse position recorded by delayed window autoselection.")

(defvar mouse-autoselect-window-window nil
  "Last window recorded by delayed window autoselection.")

(defvar mouse-autoselect-window-state nil
  "When non-nil, special state of delayed window autoselection.
Possible values are `suspend' \(suspend autoselection after a menu or
scrollbar interaction\) and `select' \(the next invocation of
'handle-select-window' shall select the window immediately\).")

(defun mouse-autoselect-window-cancel (&optional force)
  "Cancel delayed window autoselection.
Optional argument FORCE means cancel unconditionally."
  (unless (and (not force)
	       ;; Don't cancel for select-window or select-frame events
	       ;; or when the user drags a scroll bar.
	       (or (memq this-command
			 '(handle-select-window handle-switch-frame))
		   (and (eq this-command 'scroll-bar-toolkit-scroll)
			(memq (nth 4 (event-end last-input-event))
			      '(handle end-scroll)))))
    (setq mouse-autoselect-window-state nil)
    (when (timerp mouse-autoselect-window-timer)
      (cancel-timer mouse-autoselect-window-timer))
    (remove-hook 'pre-command-hook 'mouse-autoselect-window-cancel)))

(defun mouse-autoselect-window-start (mouse-position &optional window suspend)
  "Start delayed window autoselection.
MOUSE-POSITION is the last position where the mouse was seen as returned
by `mouse-position'.  Optional argument WINDOW non-nil denotes the
window where the mouse was seen.  Optional argument SUSPEND non-nil
means suspend autoselection."
  ;; Record values for MOUSE-POSITION, WINDOW, and SUSPEND.
  (setq mouse-autoselect-window-position mouse-position)
  (when window (setq mouse-autoselect-window-window window))
  (setq mouse-autoselect-window-state (when suspend 'suspend))
  ;; Install timer which runs `mouse-autoselect-window-select' after
  ;; `mouse-autoselect-window' seconds.
  (setq mouse-autoselect-window-timer
	(run-at-time
	 (abs mouse-autoselect-window) nil 'mouse-autoselect-window-select)))

(defun mouse-autoselect-window-select ()
  "Select window with delayed window autoselection.
If the mouse position has stabilized in a non-selected window, select
that window.  The minibuffer window is selected only if the minibuffer is
active.  This function is run by `mouse-autoselect-window-timer'."
  (condition-case nil
      (let* ((mouse-position (mouse-position))
	     (window
	      (condition-case nil
		  (window-at (cadr mouse-position) (cddr mouse-position)
			     (car mouse-position))
		(error nil))))
	(cond
	 ((or (menu-or-popup-active-p)
	      (and window
		   (not (coordinates-in-window-p (cdr mouse-position) window))))
	  ;; A menu / popup dialog is active or the mouse is on the scroll-bar
	  ;; of WINDOW, temporarily suspend delayed autoselection.
	  (mouse-autoselect-window-start mouse-position nil t))
	 ((eq mouse-autoselect-window-state 'suspend)
	  ;; Delayed autoselection was temporarily suspended, reenable it.
	  (mouse-autoselect-window-start mouse-position))
	 ((and window (not (eq window (selected-window)))
	       (or (not (numberp mouse-autoselect-window))
		   (and (> mouse-autoselect-window 0)
			;; If `mouse-autoselect-window' is positive, select
			;; window if the window is the same as before.
			(eq window mouse-autoselect-window-window))
		   ;; Otherwise select window if the mouse is at the same
		   ;; position as before.  Observe that the first test after
		   ;; starting autoselection usually fails since the value of
		   ;; `mouse-autoselect-window-position' recorded there is the
		   ;; position where the mouse has entered the new window and
		   ;; not necessarily where the mouse has stopped moving.
		   (equal mouse-position mouse-autoselect-window-position))
	       ;; The minibuffer is a candidate window if it's active.
	       (or (not (window-minibuffer-p window))
		   (eq window (active-minibuffer-window))))
	  ;; Mouse position has stabilized in non-selected window: Cancel
	  ;; delayed autoselection and try to select that window.
	  (mouse-autoselect-window-cancel t)
	  ;; Select window where mouse appears unless the selected window is the
	  ;; minibuffer.  Use `unread-command-events' in order to execute pre-
	  ;; and post-command hooks and trigger idle timers.  To avoid delaying
	  ;; autoselection again, set `mouse-autoselect-window-state'."
	  (unless (window-minibuffer-p (selected-window))
	    (setq mouse-autoselect-window-state 'select)
	    (setq unread-command-events
		  (cons (list 'select-window (list window))
			unread-command-events))))
	 ((or (and window (eq window (selected-window)))
	      (not (numberp mouse-autoselect-window))
	      (equal mouse-position mouse-autoselect-window-position))
	  ;; Mouse position has either stabilized in the selected window or at
	  ;; `mouse-autoselect-window-position': Cancel delayed autoselection.
	  (mouse-autoselect-window-cancel t))
	 (t
	  ;; Mouse position has not stabilized yet, resume delayed
	  ;; autoselection.
	  (mouse-autoselect-window-start mouse-position window))))
    (error nil)))

(defun handle-select-window (event)
  "Handle select-window events."
  (interactive "e")
  (let ((window (posn-window (event-start event))))
    (unless (or (not (window-live-p window))
		;; Don't switch if we're currently in the minibuffer.
		;; This tries to work around problems where the
		;; minibuffer gets unselected unexpectedly, and where
		;; you then have to move your mouse all the way down to
		;; the minibuffer to select it.
		(window-minibuffer-p (selected-window))
		;; Don't switch to minibuffer window unless it's active.
		(and (window-minibuffer-p window)
		     (not (minibuffer-window-active-p window)))
		;; Don't switch when autoselection shall be delayed.
		(and (numberp mouse-autoselect-window)
		     (not (zerop mouse-autoselect-window))
		     (not (eq mouse-autoselect-window-state 'select))
		     (progn
		       ;; Cancel any delayed autoselection.
		       (mouse-autoselect-window-cancel t)
		       ;; Start delayed autoselection from current mouse
		       ;; position and window.
		       (mouse-autoselect-window-start (mouse-position) window)
		       ;; Executing a command cancels delayed autoselection.
		       (add-hook
			'pre-command-hook 'mouse-autoselect-window-cancel))))
      (when mouse-autoselect-window
	;; Reset state of delayed autoselection.
	(setq mouse-autoselect-window-state nil)
	;; Run `mouse-leave-buffer-hook' when autoselecting window.
	(run-hooks 'mouse-leave-buffer-hook))
      (select-window window))))

(defun delete-other-windows-vertically (&optional window)
  "Delete the windows in the same column with WINDOW, but not WINDOW itself.
This may be a useful alternative binding for \\[delete-other-windows]
 if you often split windows horizontally."
  (interactive)
  (let* ((window (or window (selected-window)))
         (edges (window-edges window))
         (w window) delenda)
    (while (not (eq (setq w (next-window w 1)) window))
      (let ((e (window-edges w)))
        (when (and (= (car e) (car edges))
                   (= (caddr e) (caddr edges)))
          (push w delenda))))
    (mapc 'delete-window delenda)))

(defun truncated-partial-width-window-p (&optional window)
  "Return non-nil if lines in WINDOW are specifically truncated due to its width.
WINDOW defaults to the selected window.
Return nil if WINDOW is not a partial-width window
 (regardless of the value of `truncate-lines').
Otherwise, consult the value of `truncate-partial-width-windows'
 for the buffer shown in WINDOW."
  (unless window
    (setq window (selected-window)))
  (unless (window-full-width-p window)
    (let ((t-p-w-w (buffer-local-value 'truncate-partial-width-windows
				       (window-buffer window))))
      (if (integerp t-p-w-w)
	  (< (window-width window) t-p-w-w)
	t-p-w-w))))

(define-key ctl-x-map "0" 'delete-window)
(define-key ctl-x-map "1" 'delete-other-windows)
(define-key ctl-x-map "2" 'split-window-above-each-other)
(define-key ctl-x-map "3" 'split-window-side-by-side)
(define-key ctl-x-map "^" 'enlarge-window)
(define-key ctl-x-map "}" 'enlarge-window-horizontally)
(define-key ctl-x-map "{" 'shrink-window-horizontally)
(define-key ctl-x-map "-" 'shrink-window-if-larger-than-buffer)
(define-key ctl-x-map "+" 'balance-windows)
(define-key ctl-x-4-map "0" 'kill-buffer-and-window)

;;; window.el ends here
