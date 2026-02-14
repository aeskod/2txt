## Download

| Platform | Download |
| --- | --- |
| macOS (Apple Silicon / ARM64) | [Download DMG for Apple Silicon](../../releases/latest/download/2txt-arm64.dmg) |
| macOS (Intel / x86_64) | [Download DMG for Intel Macs](../../releases/latest/download/2txt-x86_64.dmg) |

- Download the `.dmg`, open it, then drag `2txt.app` to `Applications`.

# 2txt

2txt is a macOS app that scans a source folder, collects text and source-code files, and combines them into a single `.txt` output file. It supports flexible filtering and naming rules, and can append a directory tree so the output includes both file contents and structural context.

## Features

- Template-based output naming with tokens: `{yyyy}`, `{yy}`, `{MM}`, `{dd}`, `{HH}`, `{mm}`, `{ss}`, `{dir}`
- File/folder exclusions with three modes: exact, glob, and regex
- Exclusion autocomplete suggestions based on scanned file names
- File inclusion controls:
  - Include only plain text/source-code files
  - Include hidden files
  - Follow symbolic links
  - Optional max file size limit (MB)
- Optional directory tree appended to output
- Optional file size display in the appended directory tree
- Default output directory support via security-scoped bookmark
- Progress UI, cancel support, result summary, and a "Go To File" shortcut
- Preset management for reusable output-name templates

## Download

- Latest release for Apple Silicon and Intel Macs: [https://github.com/aeskod/2txt/releases/latest](https://github.com/aeskod/2txt/releases/latest)
- Download the `.dmg`, open it, then drag `2txt.app` to `Applications`.

## Quick Start

1. Open 2txt.
2. Click **Choose…** and select a source directory.
3. Configure exclusions and output options.
4. Click **Save**.
5. Open the generated output file (or use **Go To File** after completion).

## Output Format

Each included file is written with a header like:

```txt
// ===== File: ./relative/path =====
```

If enabled, a directory tree is appended at the end of the output file.

## Settings Reference

- Pattern mode: `exact`, `glob`, or `regex` matching for exclusion entries
- Text-only: include only plain text/source-code files
- Hidden files: include or skip hidden files/folders
- Symlink behavior: follow symlinks or skip them
- Max file size: optional size cap (MB) per included file
- Append tree / tree sizes: append directory tree and optionally show file sizes
- Default output directory: save to a pre-authorized folder without prompting each run

## Privacy

2txt processes files locally on your Mac. Core functionality does not require network access.
