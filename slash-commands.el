;;; slash-commands.el --- Popup slash commands using posframe -*- lexical-binding: t -*-

;; Copyright (C) 2025 Daniel Nguyen

;; Author: Daniel Nguyen <bluesky.1289@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1") (posframe "1.0.0"))
;; Keywords: convenience
;; URL: https://github.com/bluzky/slash-commands

;;; Commentary:

;; A minor mode that provides modern document editor-like slash commands
;; with a popup interface using posframe.
;; Type a slash at the beginning of a line or after whitespace to trigger
;; the popup command interface.
;;
;; Commands can be registered per-buffer, allowing different buffers of
;; the same major mode to have different slash commands.

;;; Code:

(require 'posframe)
(require 'cl-lib)
(require 'face-remap)  ;; For face color access

;; Customization Options

(defgroup slash-commands nil
  "Popup slash commands configuration options."
  :group 'convenience
  :prefix "slash-commands-")

(defcustom slash-commands-max-items 10
  "Maximum number of items to show in the popup."
  :type 'integer
  :group 'slash-commands)

(defcustom slash-commands-width 30
  "Width of the popup frame in characters."
  :type 'integer
  :group 'slash-commands)

(defcustom slash-commands-trigger-chars '(?\s ?\t)
  "Characters after which a slash will trigger commands.
By default, slash commands can be triggered at the beginning of a line
or after whitespace (space or tab)."
  :type '(repeat character)
  :group 'slash-commands)

(defcustom slash-commands-border-width 1
  "Width of the border around the popup frame."
  :type 'integer
  :group 'slash-commands)

(defface slash-commands-face-selected
  '((t :inherit highlight :weight bold :extend t))
  "Face for the selected command in the popup."
  :group 'slash-commands)

;; Buffer-local variables

(defvar-local slash-commands-buffer-commands nil
  "Buffer-local slash commands.
An alist where each entry is (COMMAND-NAME . FUNCTION).")

;; Global State

(defvar slash-commands--state nil
  "Global state for slash popups.
An alist with these keys:
- `buffer': The original buffer where the popup was triggered
- `start-point': Position where the slash command starts
- `input': Current input text for filtering commands
- `commands': List of currently displayed commands
- `selected-index': Index of currently selected command
- `popup-buffer': Name of the buffer used for the popup display
- `active': Non-nil means the popup is currently active")

(defvar slash-commands--buffer-name " *slash-commands*"
  "Name of the posframe buffer for slash commands.")

(defvar slash-commands--keymap
  (let ((map (make-sparse-keymap)))
    ;; Navigation - arrow keys, Emacs standard keys
    (define-key map [down] #'slash-commands-next-command)
    (define-key map [up] #'slash-commands-prev-command)

    ;; Cancellation
    (define-key map [escape] #'slash-commands-cancel)
    (define-key map (kbd "ESC") #'slash-commands-cancel)
    (define-key map "\C-g" #'slash-commands-cancel)
    map)
  "Keymap active when slash popup is displayed.")

;; Theme Integration Functions

(defun slash-commands--get-face-attribute (face attribute &optional inherit)
  "Get FACE's ATTRIBUTE value, with INHERIT option."
  (face-attribute face attribute nil inherit))

(defun slash-commands--get-background-color ()
  "Get the background color from the current theme."
  (slash-commands--get-face-attribute 'hl-line :background t))

(defun slash-commands--get-foreground-color ()
  "Get the foreground color from the current theme."
  (slash-commands--get-face-attribute 'default :foreground t))

(defun slash-commands--get-border-color ()
  "Get the background color from the current theme."
  (slash-commands--get-face-attribute 'highlight :background t))

;; Core Functions

(defun slash-commands-register-commands (commands-alist &optional buffer)
  "Set slash commands for the specified BUFFER.
COMMANDS-ALIST is an alist where each entry is (COMMAND-NAME . FUNCTION).
If BUFFER is nil, use the current buffer.
This replaces any existing commands for the buffer."
  (with-current-buffer (or buffer (current-buffer))
    (setq slash-commands-buffer-commands commands-alist)))

(defun slash-commands-clear-buffer-commands (&optional buffer)
  "Clear all slash commands for the specified BUFFER.
If BUFFER is nil, use the current buffer."
  (with-current-buffer (or buffer (current-buffer))
    (setq slash-commands-buffer-commands nil)))

(defun slash-commands--get-available-commands ()
  "Get all available slash commands for the current buffer."
  slash-commands-buffer-commands)

(defun slash-commands--can-trigger-p ()
  "Return non-nil if slash command can be triggered at point."
  (and (or (bolp)  ; beginning of line
           (and (> (point) 0)  ; not at beginning of buffer
                (memq (char-before) slash-commands-trigger-chars)))
       ;; Check if after the slash, there's whitespace or end of line
       (or (eolp)
           (memq (char-after) slash-commands-trigger-chars))
       slash-commands-buffer-commands))  ; commands exist for this buffer

(defun slash-commands-next-command ()
  "Select the next command in the popup."
  (interactive)
  (when (alist-get 'active slash-commands--state)
    (let* ((commands (alist-get 'commands slash-commands--state))
           (current-index (alist-get 'selected-index slash-commands--state 0))
           (new-index (min (1- (length commands))
                           (1+ current-index))))
      (setf (alist-get 'selected-index slash-commands--state) new-index)
      ;; (slash-commands--update-display)
      )))

(defun slash-commands-prev-command ()
  "Select the previous command in the popup."
  (interactive)
  (when (alist-get 'active slash-commands--state)
    (let* ((current-index (alist-get 'selected-index slash-commands--state 0))
           (new-index (max 0 (1- current-index))))
      (setf (alist-get 'selected-index slash-commands--state) new-index)
      ;; (slash-commands--update-display)
      )))

;; Define submenu as a special symbol
(defvar slash-commands-submenu-symbol 'submenu
  "Symbol used to identify submenu commands.")


(defun slash-commands-select-command ()
  "Execute the currently selected command or navigate to a sub-menu."
  (interactive)
  (when (alist-get 'active slash-commands--state)
    (let* ((commands (alist-get 'commands slash-commands--state))
           (index (alist-get 'selected-index slash-commands--state 0))
           (cmd-data (nth index commands))
           (cmd-name (car cmd-data))
           (cmd-fn (cdr cmd-data))
           (buffer (alist-get 'buffer slash-commands--state))
           (start-pos (when (markerp (alist-get 'start-point slash-commands--state))
                        (marker-position (alist-get 'start-point slash-commands--state)))))


      ;; Check if this is a submenu by checking if cmd-fn is a list with 'submenu as the first element
      (if (and (listp cmd-fn) (eq (car-safe cmd-fn) slash-commands-submenu-symbol))
          ;; Handle submenu - cmd-fn is (submenu . commands-list)
          (let ((submenu-commands (cdr cmd-fn)))
            ;; Save current state to parent stack
            (push (cons (alist-get 'commands slash-commands--state)
                        (alist-get 'input slash-commands--state ""))
                  (alist-get 'parent-commands slash-commands--state))

            ;; Update command path
            (push cmd-name (alist-get 'command-path slash-commands--state))

            ;; Clear the buffer input back to just the slash character
            (when (and buffer (buffer-live-p buffer) start-pos)
              (with-current-buffer buffer
                (delete-region (1+ start-pos) (point))))

            ;; Set new commands and reset selection state
            (setf (alist-get 'commands slash-commands--state) submenu-commands)
            (setf (alist-get 'command-list slash-commands--state) submenu-commands)
            (setf (alist-get 'selected-index slash-commands--state) 0)
            (setf (alist-get 'input slash-commands--state) "")

            ;; Update the display
            ;; (slash-commands--update-display)
            )

        ;; Regular command execution
        (slash-commands--close)

        ;; Switch to the original buffer
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            ;; Remove the command text
            (when start-pos
              (delete-region start-pos (point)))

            ;; Execute the command function
            (when (functionp cmd-fn)
              (funcall cmd-fn))))))))


(defun slash-commands-cancel ()
  "Cancel the slash command popup."
  (interactive)
  (when (alist-get 'active slash-commands--state)
    (slash-commands--close)))

(defun slash-commands--filter-commands (input)
  "Filter available commands based on INPUT string.
Sort filtered commands by the position of the matched string,
commands that match at the beginning of the name appear first."
  (let ((commands (alist-get 'command-list slash-commands--state))
        (case-fold-search t)) ;; Make search case-insensitive

    (cond
     ;; If no commands defined, return nil
     ((null commands) nil)

     ;; If input is empty, return all commands
     ((string-empty-p input) commands)

     ;; Filter commands by input and sort by match position
     (t
      (let ((filtered-commands
             (cl-remove-if-not
              (lambda (cmd)
                (let ((cmd-name (car cmd)))
                  (and cmd-name
                       (stringp cmd-name)
                       (string-match-p (regexp-quote input) cmd-name))))
              commands)))

        ;; Sort filtered commands by match position
        (sort filtered-commands
              (lambda (a b)
                (let* ((name-a (car a))
                       (name-b (car b))
                       (pos-a (string-match (regexp-quote input) name-a))
                       (pos-b (string-match (regexp-quote input) name-b)))
                  (< pos-a pos-b)))))))))

(defun slash-commands--update-display ()
  "Update the popup display with filtered commands.
Closes the popup if no commands match the filter."
  (when (alist-get 'active slash-commands--state)
    (let* ((input (alist-get 'input slash-commands--state ""))
           (filtered-commands (slash-commands--filter-commands input))
           (selected-index (alist-get 'selected-index slash-commands--state 0))
           (command-path (alist-get 'command-path slash-commands--state))
           ;; Ensure selected index is in bounds
           (selected-index (min (if filtered-commands
                                    (max 0 (1- (length filtered-commands)))
                                  0)
                                selected-index)))

      (setf (alist-get 'commands slash-commands--state) filtered-commands)

      ;; If no commands match, close the popup
      (if (null filtered-commands)
          ;; (insert (propertize "No matching commands" 'face 'italic))
          (slash-commands--close)

        ;; Otherwise continue with normal update
        ;; Update the state
        (setf (alist-get 'selected-index slash-commands--state) selected-index)

        ;; Prepare buffer content
        (with-current-buffer (get-buffer-create slash-commands--buffer-name)
          (let ((inhibit-read-only t))
            (erase-buffer)

            ;; Show the command path if we're in a submenu
            (when command-path
              (insert (propertize (concat "/"
                                          (mapconcat #'identity (reverse command-path) "/")
                                          "/")
                                  'face 'font-lock-comment-face))
              (insert "\n\n"))

            ;; Show the filtered commands
            (let ((display-commands (seq-take filtered-commands slash-commands-max-items)))
              (dotimes (i (length display-commands))
                (let* ((cmd (nth i display-commands))
                       (cmd-name (car cmd))
                       (cmd-fn (cdr cmd))
                       (selected (= i selected-index))
                       (is-submenu (and (listp cmd-fn)
                                        (eq (car-safe cmd-fn) slash-commands-submenu-symbol)))
                       (prefix (if selected " " " "))
                       ;; Add an indicator for submenus
                       (suffix (if is-submenu " »" ""))
                       (content (concat prefix cmd-name suffix "\n")))

                  ;; Insert command with proper formatting
                  (insert (propertize content
                                      'face (if selected 'slash-commands-face-selected nil))))))))

        ;; Get theme-aware colors
        (let ((bg-color (slash-commands--get-background-color))
              (fg-color (slash-commands--get-foreground-color))
              (border-color (slash-commands--get-border-color)))

          ;; Position and show the posframe
          (posframe-show slash-commands--buffer-name
                         :position (or (and (markerp (alist-get 'start-point slash-commands--state))
                                            (marker-position (alist-get 'start-point slash-commands--state)))
                                       (with-current-buffer (alist-get 'buffer slash-commands--state)
                                         (point)))
                         :width slash-commands-width
                         :min-width 20
                         :max-width (min 40 (- (frame-width) 10))
                         :internal-border-width slash-commands-border-width
                         :internal-border-color border-color
                         :background-color bg-color
                         :foreground-color fg-color
                         :refresh t))
        ))))

(defun slash-commands--close ()
  "Close the slash command popup and reset state."
  (remove-hook 'post-command-hook #'slash-commands--post-command-hook)
  (when (get-buffer slash-commands--buffer-name)
    (posframe-delete slash-commands--buffer-name))
  ;; Clean up keymap
  (setq overriding-terminal-local-map nil)
  (setf (alist-get 'active slash-commands--state) nil)
  (setq slash-commands--state nil)


  ;; Ensure keyboard focus returns to the original buffer
  (when-let ((buffer (alist-get 'buffer slash-commands--state)))
    (when (buffer-live-p buffer)
      (select-window (get-buffer-window buffer)))))

(defun slash-commands--post-command-hook ()
  "Monitor user actions to update or close the popup as needed."
  (cl-block slash-commands--post-command-hook
    (when (alist-get 'active slash-commands--state)
      (let* ((buffer (alist-get 'buffer slash-commands--state)))
        ;; Check if we've switched to a different buffer
        (when (not (eq (current-buffer) buffer))
          (slash-commands--close)
          (cl-return-from slash-commands--post-command-hook))

        ;; Continue with normal processing in the original buffer
        (cond
         ;; If RET was pressed, select the current command
         ;; ((and last-command-event-char (memq last-command-event-char '(?\r ?\n)))
         ;;  (slash-commands-select-command))

         ;; If point moved before the slash, close the popup
         ((let ((start-point (alist-get 'start-point slash-commands--state)))
            (or (null start-point)
                (< (point) start-point)
                ;; If user deleted the slash character, close the popup
                (not (eq (char-after start-point) ?/))))
          (slash-commands--close))

         ;; Otherwise, update current input and filter commands
         (t
          (let* ((start-point (alist-get 'start-point slash-commands--state))
                 (new-input (buffer-substring-no-properties
                             (1+ start-point)
                             (point)))
                 (old-input (alist-get 'input slash-commands--state "")))


            ;; Only reset selection if the input changed
            (when (not (string= old-input new-input))
              (setf (alist-get 'input slash-commands--state) new-input)
              (setf (alist-get 'selected-index slash-commands--state) 0))

            (slash-commands--update-display))))))))

(defun slash-commands-key-pressed ()
  "Handle the slash key being pressed to trigger popup."
  (interactive)
  ;; Check if we're in a context where slash commands can be triggered
  (if (slash-commands--can-trigger-p)
      (progn
        (insert "/")
        ;; Initialize the command popup with global state
        ;; Set the state
        (setq slash-commands--state
              `((buffer . ,(current-buffer))
                (start-point . ,(copy-marker (1- (point))))
                (input . "")
                (commands . ,(slash-commands--get-available-commands))
                (command-list . ,(slash-commands--get-available-commands))
                (selected-index . 0)
                (popup-buffer . ,slash-commands--buffer-name)
                (command-path . ())
                (parent-commands . nil)
                (active . t)))

        (setf (alist-get 'command-path slash-commands--state) nil)
        (setf (alist-get 'active slash-commands--state) t)

        ;; Display the initial popup with all commands
        ;; (slash-commands--update-display)

        ;; Set up the command hook to track further actions
        (add-hook 'post-command-hook #'slash-commands--post-command-hook)

        ;; Use overriding-terminal-local-map for higher priority
        (setq overriding-terminal-local-map slash-commands--keymap)

        ;; Also set up a cleanup function for when the keymap is deactivated
        (add-hook 'post-command-hook
                  (lambda ()
                    (unless (alist-get 'active slash-commands--state)
                      (setq overriding-terminal-local-map nil)
                      (remove-hook 'post-command-hook 'slash-commands--cleanup-keymap)))
                  nil t))

    ;; Otherwise, just insert a normal slash
    (insert "/")))

;;;###autoload
(define-minor-mode slash-commands-mode
  "Minor mode for showing slash commands in a popup interface.
With prefix argument ARG, turn on if positive, otherwise off."
  :lighter " /Popup"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "/") #'slash-commands-key-pressed)
            (define-key map (kbd "RET") (lambda ()
                                          (interactive)
                                          (if (alist-get 'active slash-commands--state)
                                              (slash-commands-select-command)
                                            (newline))))
            map))

;;;###autoload
(define-globalized-minor-mode global-slash-commands-mode
  slash-commands-mode
  (lambda () (slash-commands-mode 1)))

(defun slash-commands--inhibit-self-insert ()
  "Intercept keys when popup is active to prevent them from inserting."
  (when (and (alist-get 'active slash-commands--state)
             (eq this-command 'newline))
    (setq this-command 'slash-commands-select-command)))

;; Add needed cleanup function
(defun slash-commands--cleanup-keymap ()
  "Remove the overriding keymap when popup is closed."
  (when (not (alist-get 'active slash-commands--state))
    (setq overriding-terminal-local-map nil)))

;; Add pre-command hook globally to intercept newline
(add-hook 'pre-command-hook #'slash-commands--inhibit-self-insert)



(provide 'slash-commands)
;;; slash-commands.el ends here
