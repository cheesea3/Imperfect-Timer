#!/bin/bash

/cygdrive/c/scripting/spcomp \
  -i /cygdrive/c/scripting/include \
  -i /cygdrive/c/scripting \
  -i /cygdrive/c/scripting/include \
  -i addons/sourcemod/scripting \
  -i addons/sourcemod/scripting/include \
  -o surftimer.smx \
  addons/sourcemod/scripting/surftimer.sp \
  | grep -v "loose indentation"
