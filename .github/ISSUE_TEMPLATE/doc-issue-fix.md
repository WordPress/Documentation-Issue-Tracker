---
name: Fix Doc Issue Report
about: Report an issue in the existing WordPress documentation and help us improve the documentation.
labels: tracking issue, needs triage
---
<!--
Please fill out the following sections with as many details as you can.
We can't work on fixing an issue unless we have all the details. 
So please be sure your submission is complete; if it's not, it will be marked as incomplete, and closed without being fixed.

-->

## Issue Description
it's a typo
## URL of the Page with the Issue
https://developer.wordpress.org/themes/functionality/administration-menus/

## Section of Page with the issue
Determining Location for New Menus > Example

## Why is this a problem?
the example code isn't working

## Suggested Fix
...
function register_my_theme_more_settings_menu() {
    add_submenu_page(
        "my-themes-settings-menu",  >>>  "my-theme-settings-menu",
        ...
