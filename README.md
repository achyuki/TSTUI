# TSTUI

> TermuxSnapshotTUI - Fast rollback and backup of termux based on git.

## Install

```
bash <(curl -sL https://raw.githubusercontent.com/achyuki/TSTUI/main/install.sh)
```

## Usage

```
# TUI Mode
tstui
# CLI Mode
tstui create <snapshotname>
tstui list
tstui restore <snapshotname>
```

For more information, see `tstui --help`.

## Config

You can configure ignore rules in the `~/.tstuignore` file.
These paths will be skipped during backup and rollback.

```
# The format is consistent with the .gitignore file.
# The root directory is $TERMUX_APP__Files_DIR.

/apps
/usr/tmp
/home/.cache
/usr/var/log

```

## Tips

* Due to the nature of Git, empty directories will not be backed up.
* Do not interrupt while performing time-consuming operations, as it may cause abnormal snapshot systems or environments.

## License

```
MIT License

Copyright (c) 2025 YukiChan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
