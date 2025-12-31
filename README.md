# gsom_modapi

A generic content-based mod framework for Godot 4.
- The main idea is to represent 99% of the game implementation as "mod content".

There is a singleton `GsomModapi`, and several helper classes, which let you
define content entries, and then find/list and spawn them later.
This approach is being scaled from tiniest items or visual effects to whole
gameplay modes and systems.

## GsomModapi
