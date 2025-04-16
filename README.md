# Slash Commands for Emacs


A modern document editor-like slash command interface for Emacs.


## Installation


### With quelpa

```elisp
;; With quelpa
(quelpa '(slash-commands :repo "bluzky/slash-commands" :fetcher github))

;; With use-package + quelpa-use-package
(use-package slash-commands
  :quelpa (slash-commands :repo "bluzky/slash-commands" :fetcher github)
  :config
  (global-slash-commands-mode 1))
```

### With straight.el

```elisp
;; Basic straight.el usage
(straight-use-package
 '(slash-commands :type git :host github :repo "bluzky/slash-commands"))

;; With use-package + straight.el
(use-package slash-commands
  :straight (slash-commands :type git :host github :repo "bluzky/slash-commands")
  :config
  (global-slash-commands-mode 1))
```

### Manual installation

Clone this repository to your Emacs load path:

```bash
git clone https://github.com/bluzky/slash-commands.git ~/.emacs.d/slash-commands
```

Then add to your Emacs configuration:

```elisp
(add-to-list 'load-path "~/.emacs.d/slash-commands")
(require 'slash-commands)
(global-slash-commands-mode 1)
```


## Configuration

### Basic setup

```elisp
;; Enable globally
(global-slash-commands-mode 1)

;; Mode-specific commands
(add-hook 'org-mode-hook
          (lambda ()
            (slash-commands-register-commands
             '(("todo" . org-insert-todo-heading)
               ("link" . org-insert-link)
               ("src" . org-insert-structure-template)))))
```

### Customization options

```elisp
;; Maximum number of items shown in the popup
(setq slash-commands-max-items 15)

;; Width of the popup (in characters)
(setq slash-commands-width 40)

;; Characters after which slash will trigger commands
;; By default it's space and tab
(setq slash-commands-trigger-chars '(?\s ?\t))

;; Border width for the popup
(setq slash-commands-border-width 2)

;; Customize the selected item face
(set-face-attribute 'slash-commands-face-selected nil
                   :background "darkblue"
                   :foreground "white"
                   :weight 'bold)
```

## Creating Commands

Commands are simply functions that perform some action. You register them with a name that will appear in the popup menu.

```elisp
;; Simple command example
(defun insert-date ()
  "Insert current date at point."
  (interactive)
  (insert (format-time-string "%Y-%m-%d")))

;; Register it
(slash-commands-register-commands
 '(("date" . insert-date)))
```

### Creating Submenus

Submenus allow you to organize commands hierarchically:

```elisp
(slash-commands-register-commands
 `(("insert" . (,slash-commands-submenu-symbol
               ("date" . insert-date)
               ("time" . insert-time)
               ("signature" . insert-signature)))
   ("format" . (,slash-commands-submenu-symbol
               ("bold" . make-region-bold)
               ("italic" . make-region-italic)
               ("code" . make-region-code)))))
```

When you select "insert" from the menu, it will show the submenu with date, time, and signature options.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## Author

Daniel Nguyen <bluesky.1289@gmail.com>
