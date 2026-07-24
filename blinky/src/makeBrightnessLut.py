# -*- coding: utf-8 -*-
# =============================================================================
# Project       : hdlCatalog/blinky
# Module name   : makeBrightnessLut
# File name     : makeBrightnessLut.py
# File type     : Python script (Python 3)
# Purpose       : LUT generation table (gamma correction)
# Author        : QuBi (nitrogenium@outlook.fr)
# Creation date : July 16th, 2025
# -----------------------------------------------------------------------------
# Best viewed with space indentation (2 spaces)
# =============================================================================

import math
from datetime import datetime




# =============================================================================
# LUT SETTINGS
# =============================================================================

TARGET_PKG_FILE = "blinky_pkg.vhd"

# PWM resolution (in bits)
# Number of PWM steps = 2^PWM_RESOL
PWM_RESOL_NBITS = 9
pwmSteps = int(2**PWM_RESOL_NBITS)

# Number of desired steps in brightness.
# NOTES:
# - A value higher than 'pwmSteps' won't make much sense since 
#   there aren't enough distinct PWM values to satisfy the resolution.
# - Use a power of 2 for more optimal synthesis.
BRIGHTNESS_STEPS = 128



# =============================================================================
# VHDL PACKAGE GENERATION
# =============================================================================
def main() :

  # Buffer the VHDL package
  with open(TARGET_PKG_FILE, "r") as inputFile :
    lines = inputFile.readlines()

  lineOutput = []
  isLutSection = False

  for lineInput in lines :
    if ("-- Creation date" in lineInput) :
      _insertDate(lineOutput)
    elif ("___BEGIN_ROM_SECTION___" in lineInput) :
      _insertROM(lineOutput)
      isLutSection = True
    elif (("___END_ROM_SECTION___" in lineInput) and isLutSection) :
      isLutSection = False
    elif not(isLutSection) :
      lineOutput.append(lineInput)


  # Write back modified file
  with open(TARGET_PKG_FILE, "w") as outputFile :
    outputFile.writelines(lineOutput)

  print("[NOTE] Output generated to './blinky_pkg.vhd'.")




def _insertDate(line) :
  now = datetime.now()
  timestamp = now.strftime(f"%B {now.day}, %Y at %H:%M")
  line.append(f"-- Creation date  : {timestamp}\n")



def _insertROM(line) :
  line.append(f"  -- ___BEGIN_ROM_SECTION___\n")
  line.append(f"  constant PWM_RESOL_NBITS  : INTEGER := {PWM_RESOL_NBITS};\n")
  line.append(f"  constant BRIGHTNESS_STEPS : INTEGER := {BRIGHTNESS_STEPS};\n")
  line.append("  \n")
  line.append("  type ROM_TYPE is array (0 to (BRIGHTNESS_STEPS-1)) of STD_LOGIC_VECTOR((PWM_RESOL_NBITS-1) downto 0);\n")
  line.append(" \n")
  line.append("  constant BRIGHTNESS_ROM : ROM_TYPE := \n")
  line.append("  (\n")
  for i in range(BRIGHTNESS_STEPS) :

    # TODO: with the rounding, is there a risk that 'val' exceeds the number
    # of bits available for the PWM (i.e. PWM_RESOL_NBITS)?
    val = int(round(10**((i/BRIGHTNESS_STEPS)*math.log10(pwmSteps))))-1
    
    if (i == (BRIGHTNESS_STEPS-1)) :
      line.append(f"    {i} => \"{val:0{PWM_RESOL_NBITS}b}\"     -- PWM({i}) = {val}/{pwmSteps}\n")
    else :
      line.append(f"    {i} => \"{val:0{PWM_RESOL_NBITS}b}\",    -- PWM({i}) = {val}/{pwmSteps}\n")
    
  line.append("  );\n")
  line.append(f"  -- ___END_ROM_SECTION___\n")




# =============================================================================
# ENTRY POINT
# =============================================================================
if (__name__ == "__main__") :
  main()