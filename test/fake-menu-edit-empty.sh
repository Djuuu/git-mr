#!/usr/bin/env bash

test_menu_file="$(git rev-parse --git-dir)/MR_MENU_EDITMSG"

echo '

//!
//!  Here you can rearrange menu items, add additional description, etc.
//!
//!  Individual menu items will be highlighted in the relevant merge request,
//!  provided you keep the markdown list & link format.
//!
//!  If you remove everything, menu update will be aborted.
//!



' > "$test_menu_file"
