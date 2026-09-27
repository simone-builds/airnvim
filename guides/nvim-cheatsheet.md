# Neovim Cheatsheet

Daily keys for Neovim and for what airnvim adds on top. Reopen this page
with `:nvcheat`, close it with `q`. The markdown syntax guide is
`:mdguide`.

---

## How to read this sheet

- `^x` means hold `Ctrl` and press `x`
- `\` is the **leader key**. `\sf` means: press `\`, release it, then `s`,
  then `f`, one after the other. Plugins and the Neovim docs write it as
  `<leader>sf`; the local leader is `\` as well
- a number in front repeats a command: `5j` moves five lines down
- `m` stands for any motion, `c` for any character
- capital letters mean `Shift`: `G` is `Shift-g`
- `:` commands end with `Enter`

---

## Modes

- `i` `a` insert before, after the cursor
- `I` `A` insert at the start, end of the line
- `o` `O` open a new line below, above
- `v` `V` `^v` visual: characters, lines, block
- `R` replace mode, overwrites as you type
- `:` command line
- `Esc` back to normal mode

---

## Movement

### Characters and words

- `h` `j` `k` `l` left, down, up, right
- `w` `b` start of next, previous word
- `e` `ge` end of next, previous word
- `W` `B` `E` the same, but words are split by spaces only
- `fc` `Fc` jump to the next, previous `c` on the line
- `tc` `Tc` jump to just before the next, previous `c`
- `;` `,` repeat the last `f` `t` forward, backward
- `%` jump to the matching bracket

### Lines

- `0` `^` `$` first column, first character, end of line
- `H` `L` start, end of line (airnvim; `dL` deletes to the end)
- `n|` column `n` of the line
- `nj` `nk` `n` lines down, up: the gutter shows relative numbers
- `gg` `G` first, last line
- `nG` or `:n` line `n`
- `{` `}` previous, next paragraph
- `(` `)` previous, next sentence

### Jumps

- `^o` `^i` back, forward through the places you jumped from
- `` `. `` where the last change was made
- `gi` back into insert mode where you last left it

### Scrolling

- `^d` `^u` half a page down, up
- `^f` `^b` a full page down, up
- `^e` `^y` one line down, up, the cursor stays
- `zz` `zt` `zb` put the cursor line at the centre, top, bottom
- mouse wheel: 5 lines per step, `settings.mouse.scroll_lines` in Nix

---

## Editing

### Operators

An operator waits for a motion or a text object: `dw` deletes a word, `y$`
copies to the end of the line, `gUiw` uppercases a word. Doubled, it works
on the whole line.

- `d` delete (cut)
- `c` change: delete, then insert
- `y` yank (copy)
- `>` `<` indent, dedent
- `=` reindent
- `gu` `gU` lowercase, uppercase
- `gq` rewrap to the text width
- `dd` `cc` `yy` delete, change, copy the whole line
- `D` `C` `Y` delete, change, copy to the end of the line

### Small edits

- `x` `X` delete the character under, before the cursor
- `rc` replace the character under the cursor with `c`
- `~` toggle the case of a character
- `J` join the line below onto this one
- `.` repeat the last change

### Text objects

Use them after an operator or in visual mode. `i` is inside, `a` includes
the surroundings.

- `iw` `aw` word
- `ip` `ap` paragraph
- `is` sentence
- `i"` `a"` inside, around quotes; also `'` and `` ` ``
- `i(` `a(` inside, around brackets; also `[`, `{` and `<`
- `it` `at` inside, around an HTML tag
- `im` `am` function (treesitter)
- `ic` `ac` class (treesitter)
- `as` local scope (treesitter; replaces "a sentence")

Examples: `ci"` rewrites a quoted string, `dap` deletes a paragraph, `yiw`
copies a word.

### Undo and redo

- `u` undo
- `^r` redo
- `U` undo every change on the last changed line
- `\u` undo tree: every past state, even undone branches

### Copy and paste

- `p` `P` paste after, before the cursor
- `"ay` `"ap` copy into, paste from register `a`
- `:reg` all registers; `:reg a` register `a` only
- `^r"` paste the last copy while in insert mode

Every copy also lands in the system clipboard, and `p` pastes what you
copied in other programs.

### Macros

- `qa` start recording into register `a`
- `q` stop recording
- `@a` play it; `5@a` five times
- `@@` play the last macro again
- `qA` append to the macro in `a`
- `:@a` run register `a` as a `:` command

### Surround

- `ysiw"` surround a word with `"`; any motion works after `ys`
- `ds"` delete the surrounding `"`
- `cs"'` change the surrounding `"` into `'`
- `S"` in visual mode: surround the selection

### Comments

- `gcc` comment, uncomment the line
- `gc` with a motion or a selection: `gcap` comments a paragraph

### Completion (insert mode)

- `^n` `^p` next, previous suggestion
- `^y` or `Enter` accept
- `^e` close the menu
- `^Space` open the menu by hand
- `^d` `^u` scroll the documentation

---

## Markdown

### Emphasis (visual mode)

- `^b` wrap the selection in `**bold**`
- `^i` wrap it in `*italic*`; `Tab` does the same
- `` ^` `` wrap it in `` `code` ``; needs WezTerm, kitty or similar

They go through the clipboard: afterwards it holds the selected words.

### Images

- `\ip` or `:pasteimage` paste the image in the clipboard: a popup asks for
  a name, the file is saved as `assets/YYYY-MM-DD_HH-MM-SS_name.png` next
  to the note, and the link is written for you. An empty name keeps the
  date only
- pasted links end in `{ width=15cm }`: the image width in the PDF, set
  by `settings.markdown.images.paste_width` in Nix
- images show inside the buffer, below their link, as wide as the text
- dropping an image file onto the terminal inserts a link to it

### Preview and layout

- `:previewmd` live preview in the browser, follows the cursor
- `:previewmd stop` end the preview
- `:mdwrap` rewrap every paragraph; saving does it too
- `:RenderMarkdown toggle` show the raw text instead of the rendering

### Headings and folds

- `]]` `[[` next, previous heading
- `\t` or `gO` table of contents: every heading, indented by level;
  `Enter` jumps to it, `:q` closes the list
- headings show as 1, 1.1, 1.1.1: the numbers are drawn, not written in
  the file, so a PDF export does not number them twice
- a number with a 0 in it (1.0.1) means a skipped level: the linter
  warns about it too, fix the number of `#` in the source
- `za` open or close the fold under the cursor
- `zc` `zo` close, open the fold under the cursor
- `zM` close every fold: only headings stay visible
- `zR` open every fold
- `zM` then `zo` on a heading: that heading and its subheadings

### Spelling

- `\z` or `:spelltoggle` spell checking on, off (this buffer only)
- `]s` `[s` next, previous misspelled word
- `z=` suggestions for the word under the cursor
- `zG` accept a word for this session

### Links

- `Enter` or `Ctrl`+click on a link: a note opens here, at its `#heading`
  if the link names one; a web address goes to the browser, other files
  to their program. `^o` comes back
- a link to a note that does not exist asks to create it, next to the
  note holding the link
- `\il` insert a link: pick a note, `[](path.md)` is written with the
  cursor between the brackets for the text (`Esc` leaves it empty)
- `\il` on a selection: the selected words become the link text
- `gx` open the link with the system program instead
- `gf` open the file whose name is under the cursor

---

## Search

### In the file

- `/text` `?text` search forward, backward
- `n` `N` next, previous match
- `*` `#` search the word under the cursor forward, backward
- `\/` fuzzy search in the file, with a list of matches

### In the project

Search starts from the directory Neovim was opened in (`:pwd`).

- `\sf` find a file by name
- `\sg` search text in every file (live grep)
- `\sw` search the word under the cursor
- `\s.` recent files
- `\sb` or `\\` open buffers
- `\sh` help pages
- `\sk` keymaps
- `\sc` commands
- `\sd` diagnostics
- `\sr` reopen the last search
- `\sn` airnvim's own config files
- `\ss` every search picker

### Inside a search window

- `^n` `^p` or arrows move through the results
- `Enter` or `^y` open
- `^v` `^x` `^t` open in a vertical split, a split, a tab
- `^q` send every result to the quickfix list
- `Esc` `Esc` or `q` close

---

## Find and replace

### In the file

- `:s/old/new/` first match on the current line
- `:%s/old/new/g` every match in the file
- `:%s/old/new/gc` ask for each one: `y` yes, `n` no, `a` all, `q` quit
- `:'<,'>s/old/new/g` inside the selection: select, then press `:`
- `:'<,'>s/\%Vold/new/g` inside a block selection (`^v`) only
- `:%s/\<old\>/new/g` whole words only
- `:%s//new/g` reuse the last `/` search as the pattern
- `&` `g&` repeat the last replace on this line, on the whole file

### In every file of a directory

Spectre searches the current directory and all its subdirectories.

- `\S` open Spectre: type the search, `Tab` to the replace field
- `\sR` start from the word under the cursor, or the selection
- `\sF` limit it to the current file
- `dd` in the results: leave that match out
- `\rc` replace only the match under the cursor
- `\R` replace everything listed
- `ti` `th` toggle ignore case, hidden files
- `Enter` open the file at that match

### With the quickfix list

- `\sg`, type the search, then `^q` to collect the matches
- `:cfdo %s/old/new/gc | update` replace in every collected file
- `:cdo s/old/new/g | update` replace on the collected lines only
- `:copen` `:cclose` show, hide the list
- `]q` `[q` next, previous entry

---

## Files (Oil)

- `-` open the file explorer on the current file's directory

### Inside the explorer

- `-` or `Enter` open the file or enter the directory (forward)
- `.` go to the parent directory (back)
- `_` go to the directory Neovim was started in
- `^s` `^h` `^t` open in a vertical split, a split, a tab
- `^p` preview the file on the right, it follows the cursor; `^p` again
  closes it. Text files only, their first screenful of lines; the mouse
  wheel scrolls it. `settings.oil.preview` in Nix opens it by default
- the explorer width is `settings.oil.width` in Nix (a percentage)
- `g.` show, hide hidden files
- `gx` open with the system program
- `g?` every explorer key
- `^c` or `:q` close

### Edit the directory like text

- `i` then edit a name: rename
- `dd` delete a file
- `o` then a name: new file; a name ending in `/` makes a directory
- `dd` here and `p` elsewhere: move; `yy` and `p`: copy
- `:w` apply the changes, after a confirmation

---

## Windows, tabs and buffers

### Windows

- `^wv` or `:vsplit` split vertically
- `^ws` or `:split` split horizontally
- `^wh` `^wj` `^wk` `^wl` move to the window left, below, above, right
- `^ww` cycle through the windows
- `^wq` close this window; `^wo` close all the others
- `^w=` make every window the same size
- `^w>` `^w<` wider, narrower; `10^w>` ten columns at once
- `^w+` `^w-` taller, shorter

### Tabs

- `:tabnew` new tab
- `gt` `gT` next, previous tab; `2gt` tab number 2
- `:tabclose` close the tab

### Buffers and files

- `:e path` open a file
- `]b` `[b` next, previous buffer
- `:bd` close the buffer
- `:w` save; `:wa` save all
- `:q` quit; `:qa` quit all
- `:wq` or `ZZ` save and quit
- `:q!` or `ZQ` quit and discard the changes

---

## Code

These work when a language server is attached (Nix, Lua, Markdown).

- `gd` go to the definition
- `gD` go to the declaration
- `gr` list the references
- `gI` go to the implementation
- `K` documentation of the word under the cursor
- `^k` signature help
- `\D` type definition
- `\ds` `\ws` symbols in the file, in the workspace
- `\rn` rename everywhere
- `\ca` code actions, with a preview
- `\e` show the diagnostic under the cursor
- `]d` `[d` next, previous diagnostic
- `:Format` format the file; saving formats too

---

## Git

- `\gg` LazyGit
- `\gd` open the diff view; `\gq` close it
- `\gh` history of the current file
- `\gc` commits
- `\gs` changed files
- `\gb` branches

---

## Notes (Obsidian)

Available when a vault is set in Nix.

- `\oo` open a note; `\os` search the notes
- `\on` new note; `\ot` insert a template
- `\ob` backlinks; `\ol` links in this note; `\otg` tags
- `\od` daily notes; `\odtd` `\ody` `\odtm` today, yesterday, tomorrow
- `\orn` rename the note and fix its links
- `\opi` paste an image into the vault
- `\og` open in the Obsidian app; `\ow` switch vault
- `gf` follow the link under the cursor
- `\ol` in visual mode: link the selection to a note
- `\onl` in visual mode: new note from the selection

---

## AI

Available when `settings.ai.enable` is on.

- `\a` open, close the chat
- `^s` actions menu
- `ga` in visual mode: add the selection to the chat

---

## Miscellaneous

- `:!cmd` run a shell command; `:r !cmd` insert its output
- `\z` spell checking, see Markdown above
- `:help topic` or `\sh` the manual
- `:checkhealth` diagnose problems
- `:LzeStatus` installed plugins and whether they are loaded
- `:LzeNix` plugins provided by Nix
- start screen: `n` new file, `f` find file, `g` find word, `r` recent, `s`
  settings, `q` quit
