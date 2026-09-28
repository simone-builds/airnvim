# Markdown Guide

Every section shows the **source** in a code block, then the same thing
**rendered**. Reopen this page with `:MdGuide`, close it with `q`.

---

## Headings

```markdown
# Level 1 (the title of this page)
## Level 2 (the sections of this page)
### Level 3
#### Level 4
##### Level 5
###### Level 6
```

### Level 3

#### Level 4

##### Level 5

###### Level 6

Leave a blank line before and after a heading, and put a space after the
`#` marks.

---

## Paragraphs and line breaks

```markdown
A blank line starts a new paragraph.

A line ending in a backslash\
breaks here without a new paragraph.
Two trailing spaces do the same.
```

A blank line starts a new paragraph.

A line ending in a backslash\
breaks here without a new paragraph.

---

## Emphasis

```markdown
**bold**  *italic*  ***bold italic***  ~~strikethrough~~  `code`
```

**bold** · *italic* · ***bold italic*** · ~~strikethrough~~ · `code`

In airnvim select the text in visual mode and press `Ctrl-b` (bold),
`Ctrl-i` (italic) or ``Ctrl-` `` (inline code).

```markdown
Text with a ==highlighted== word.
```

Text with a ==highlighted== word.

Obsidian and the editor show it; pandoc needs its `mark` extension.

---

## Lists

### Bulleted and nested

```markdown
- First level
  - Second level (indent by two spaces)
    - Third level
- Back to the first level
```

- First level
  - Second level (indent by two spaces)
    - Third level
- Back to the first level

### Numbered

```markdown
1. First step
2. Second step
3. Third step
```

1. First step
2. Second step
3. Third step

### Mixed

```markdown
1. Prepare
   - check the tools
   - read the notes
2. Build
```

1. Prepare
   - check the tools
   - read the notes
2. Build

Items under a number are indented to the text of that number: three spaces
after `1.`, four after `10.`.

### Tasks

```markdown
- [ ] To do
- [x] Done
- [-] In progress
- [~] Important
```

- [ ] To do
- [x] Done
- [-] In progress
- [~] Important

Numbered tasks keep their number in front of the box:

```markdown
1. [ ] First step
2. [x] Second step
```

1. [ ] First step
2. [x] Second step

---

## Quotes and callouts

### Plain quote

```markdown
> A quote has no header.
>
> > Quotes can nest.
```

> A quote has no header.
>
> > Quotes can nest.

A callout is a quote whose first line is `[!type]`. That line is the
header: whatever follows the type on it is the **title**, and the body goes
on the lines below. Keep the header on a line of its own: saving never
joins the body onto it.

### Callout with its default title

```markdown
> [!NOTE]
> The type in brackets picks icon, colour and title.
```

> [!NOTE]
> The type in brackets picks icon, colour and title.

### Callout with a custom title

```markdown
> [!TIP] Remember this
> Text after the type replaces the default title.
```

> [!TIP] Remember this
> Text after the type replaces the default title.

### Title only

```markdown
> [!WARNING] Backup before updating
```

> [!WARNING] Backup before updating

### Several paragraphs

A line holding only `>` separates paragraphs inside the callout.

```markdown
> [!INFO]
> First paragraph of the body.
>
> Second paragraph, still inside the callout.
```

> [!INFO]
> First paragraph of the body.
>
> Second paragraph, still inside the callout.

### Foldable

A `-` after the type starts it closed, a `+` starts it open; a click on the
title toggles it in Obsidian. The editor always shows it open.

```markdown
> [!FAQ]- Why is it closed?
> The `-` folds it until clicked.

> [!EXAMPLE]+ Open, but foldable
> The `+` shows it open with a toggle.
```

> [!FAQ]- Why is it closed?
> The `-` folds it until clicked.

<!-- -->

> [!EXAMPLE]+ Open, but foldable
> The `+` shows it open with a toggle.

### Lists, code and formatting inside

Everything works inside a callout as long as each line starts with `>`.

````markdown
> [!TODO] Before the release
> Check **these** points:
>
> - update the `CHANGELOG`
> - run the tests
>
> ```sh
> nix flake check
> ```
````

> [!TODO] Before the release
> Check **these** points:
>
> - update the `CHANGELOG`
> - run the tests
>
> ```sh
> nix flake check
> ```

### Nested callouts

One `>` more per level. The inner header goes on its own line too.

```markdown
> [!QUESTION] Outer
> Text of the outer callout.
>
> > [!SUCCESS] Inner
> > Text of the inner callout.
```

> [!QUESTION] Outer
> Text of the outer callout.
>
> > [!SUCCESS] Inner
> > Text of the inner callout.

### Callout types

The type picks icon and colour. In Obsidian the names on one line are
aliases of the same type; the editor labels each name on its own, and
GitHub's `IMPORTANT` and `CAUTION` get their own colour. Case does not
matter (`[!note]` works). An unknown type is a note in Obsidian and a plain
quote in the editor.

- `[!NOTE]`
- `[!ABSTRACT]` `[!SUMMARY]` `[!TLDR]`
- `[!INFO]`
- `[!TODO]`
- `[!TIP]` `[!HINT]` `[!IMPORTANT]`
- `[!SUCCESS]` `[!CHECK]` `[!DONE]`
- `[!QUESTION]` `[!HELP]` `[!FAQ]`
- `[!WARNING]` `[!CAUTION]` `[!ATTENTION]`
- `[!FAILURE]` `[!FAIL]` `[!MISSING]`
- `[!DANGER]` `[!ERROR]`
- `[!BUG]`
- `[!EXAMPLE]`
- `[!QUOTE]` `[!CITE]`

> [!ABSTRACT]
> A summary.

<!-- -->

> [!IMPORTANT]
> Key information.

<!-- -->

> [!SUCCESS]
> It worked.

<!-- -->

> [!WARNING]
> Needs attention.

<!-- -->

> [!FAILURE]
> It did not work.

<!-- -->

> [!DANGER]
> Risky: think twice.

<!-- -->

> [!BUG]
> A known problem.

<!-- -->

> [!QUOTE]
> Someone else's words.

### Where callouts show

- Obsidian and the editor draw them as boxes with icon and colour
- `:PreviewMd` in the browser shows a plain quote
- the PDF export (pandoc) has no callouts either: it prints a plain quote
  with the `[!type]` line as text

---

## Links

### Web and email

```markdown
[Neovim](https://neovim.io)
<https://neovim.io>
<name@example.com>
```

[Neovim](https://neovim.io) · <https://neovim.io>

### Other notes

```markdown
[Same directory](nvim-cheatsheet.md)
[Subdirectory](projects/plan.md)
[Parent directory](../archive/old.md)
[Absolute path](/home/user/notes/todo.md)
[Heading in this note](#lists)
[Heading in another note](nvim-cheatsheet.md#search)
```

[Same directory](nvim-cheatsheet.md) · [Heading in this note](#lists)

Paths are relative to the file that contains the link. A heading anchor is
its text in lowercase, with spaces turned into dashes.

In airnvim, `Enter` or `Ctrl`+click follows a link, and `␣il` writes one
for you: pick the note from a list and the path is filled in.

### Wikilinks (Obsidian)

```markdown
[[nvim-cheatsheet]]
[[nvim-cheatsheet|shown text]]
[[folder/note]]
[[note#Heading]]
```

[[nvim-cheatsheet]] · [[nvim-cheatsheet|shown text]]

Obsidian finds a wikilink by name anywhere in the vault; pandoc and the
browser preview do not understand them.

### Reference style

```markdown
Read [the manual][docs] first.

[docs]: https://neovim.io/doc
```

Read [the manual][docs] first.

[docs]: https://neovim.io/doc

---

## Images

```markdown
![Markdown source becomes a rendered page](assets/markdown-guide.svg)
```

![Markdown source becomes a rendered page](assets/markdown-guide.svg)

The text in square brackets is the alt text. When an image stands alone in
its paragraph, pandoc turns that text into the figure caption.

```markdown
![Caption](assets/photo.png "Tooltip on hover")
![Caption](../images/photo.png)
![Caption](assets/photo.png){ width=15cm }
![[photo.png]]
![[photo.png|400]]
```

`{ width=15cm }` is a pandoc attribute: it sets the size of the image in
the PDF (typst) and changes nothing in the editor. The last two are
Obsidian embeds; `|400` sets the width in pixels.

In airnvim, copy an image and press `␣ip` or run `:PasteImage`: it asks for
a name, saves `assets/YYYY-MM-DD_HH-MM-SS_name.png` next to the file and
writes the link for you, with `{ width=15cm }` already added.

---

## Code

### Inline

```markdown
Run `nix build` in the repository.
```

Run `nix build` in the repository.

### Block

````markdown
```bash
echo "the word after the backticks picks the highlighting"
```
````

```bash
echo "the word after the backticks picks the highlighting"
```

Use `text` when there is no language. To show a code block inside a code
block, fence the outer one with four backticks.

---

## Tables

```markdown
| Left     | Centre | Right |
| :------- | :----: | ----: |
| apples   |   3    |  1.20 |
| pears    |   12   |  0.80 |
```

| Left     | Centre | Right |
| :------- | :----: | ----: |
| apples   |   3    |  1.20 |
| pears    |   12   |  0.80 |

The colons in the second row set the alignment. Write `\|` for a pipe
inside a cell.

---

## Footnotes

```markdown
A claim that needs a source.[^1]

[^1]: The source, shown at the end of the document.
```

A claim that needs a source.[^1]

[^1]: The source, shown at the end of the document.

---

## Horizontal rule

```markdown
---
```

Three dashes alone on a line, with blank lines around them. Saving adds the
blank lines when they are missing, so `---` typed right under a line of
text stays a rule instead of turning that text into a heading. `===` gets
the same treatment and is rewritten as `---`.

---

## Escaping

```markdown
\*not italic\*  \# not a heading  \[not a link\]
```

\*not italic\* · \# not a heading · \[not a link\]

---

## Front matter

```markdown
---
title: Meeting notes
date: 2026-09-27
tags: [work, planning]
---
```

Only at the very top of a file. Obsidian shows it as properties, pandoc
reads the title and date from it.

---

## Writing in airnvim

- `:PreviewMd` opens a live preview in the browser, `:PreviewMd stop`
  closes it
- `:MdWrap` rewraps the paragraphs; saving does it too
- `:MdFormatDir` formats every `.md` in the file's directory at once
- `:MdFormatDirRecursive` does the same through every subdirectory too
- `#word` is a tag and is never touched, even at the start of a line;
  `##Title` without its space becomes `## Title` on save. A level-1 heading
  needs its space typed: `#Title` stays a tag
- `:SpellToggle` or `␣z` checks spelling in this buffer
- `:NvCheat` opens the Neovim cheatsheet
