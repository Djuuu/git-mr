#!/usr/bin/env bash

test_menu_file="$(git rev-parse --git-dir)/MR_MENU_EDITMSG.md"

echo '



<!------------------------------------------------------------------------->
<!--                                                                     -->
<!--  Here you can rearrange menu items and add additional description.  -->
<!--                                                                     -->
<!--  Current menu item will be highlighted in each merge request,       -->
<!--  provided you keep the markdown list & link format.                 -->
<!--                                                                     -->
<!--  If you remove everything, menu update will be aborted.             -->
<!--                                                                     -->
<!------------------------------------------------------------------------->


' > "$test_menu_file"
