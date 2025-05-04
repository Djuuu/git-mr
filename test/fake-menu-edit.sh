#!/usr/bin/env bash

test_menu_file="$(git rev-parse --git-dir)/MR_MENU_EDITMSG"

echo '

* Fake edited menu
* For test

' > "$test_menu_file"
