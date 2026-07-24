# -*- coding: utf-8 -*-
# =============================================================================
# Project       : hdlCatalog/sine
# Module name   : makeSineROM
# File name     : makeSineROM.py
# File type     : Python script (Python 3)
# Purpose       : automated VHDL package generation for a sinewave ROM
# Author        : QuBi (nitrogenium@outlook.fr)
# Creation date : Thursday, 23 July 2026
# -----------------------------------------------------------------------------
# Best viewed with space indentation (2 spaces)
# =============================================================================
import numpy as np
from datetime import datetime



# =============================================================================
# OUTPUT PRODUCT SETTINGS
# =============================================================================
TARGET_PKG_FILE = "sine_pkg.vhd"



# =============================================================================
# ROM SETTINGS
# =============================================================================
OUTPUT_WIDTH  = 16
ROM_SIZE      = 1024



# =============================================================================
# MAIN
# =============================================================================
def main() :

  # ---------------------------------------------------------------------------
  # STEP 1: read and buffer the current VHDL package
  # ---------------------------------------------------------------------------
  with open(TARGET_PKG_FILE, "r") as inputFile :
    lines = inputFile.readlines()

  lineOutput = []
  isRomSection = False

  for lineInput in lines :
    if ("-- Last generated" in lineInput) :
      _insertDate(lineOutput)
    elif ("___BEGIN_GENERATED_SECTION___" in lineInput) :
      _insertROM(lineOutput)
      isRomSection = True
    elif (("___END_GENERATED_SECTION___" in lineInput) and isRomSection) :
      isRomSection = False
    elif not(isRomSection) :
      lineOutput.append(lineInput)



  # ---------------------------------------------------------------------------
  # STEP 2: write the edited file
  # ---------------------------------------------------------------------------
  with open(TARGET_PKG_FILE, "w") as outputFile :
    outputFile.writelines(lineOutput)

  print(f"[NOTE] Output generated to '{TARGET_PKG_FILE}'.")



def _insertDate(line) :
  now = datetime.now()
  timestamp = now.strftime(f"%A, {now.day} %B %Y at %H:%M")
  line.append(f"-- Last generated : {timestamp}\n")
  print("- insertDate: OK")



def _insertROM(line) :
  line.append(f"  -- ___BEGIN_GENERATED_SECTION___\n")
  line.append(f"  constant OUTPUT_WIDTH : INTEGER := {OUTPUT_WIDTH};\n")
  line.append(f"  constant FREQ_WIDTH   : INTEGER := 32;\n")
  line.append(f"  constant ROM_SIZE     : INTEGER := {ROM_SIZE//4};\n")
  line.append(f"  \n")
  line.append(f"  type freq_array_t is array (NATURAL range <>)   of STD_LOGIC_VECTOR(FREQ_WIDTH-1 downto 0);\n")
  line.append(f"  type out_array_t  is array (NATURAL range <>)   of STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0)\n")
  line.append(f"  type rom_type_t   is array (0 to (ROM_SIZE-1))  of STD_LOGIC_VECTOR(OUTPUT_WIDTH-1 downto 0);\n")
  line.append(f"  \n")
  line.append(f"  constant SINE_ROM : rom_type_t := \n")
  line.append(f"  (\n")
  for i in range(ROM_SIZE//4) :
    gain = ((1 << (OUTPUT_WIDTH-1))-1)
    x = np.sin(2*np.pi*i/ROM_SIZE)
    x = x * gain
    x = int(round(x))
    val = x & ((1 << OUTPUT_WIDTH) - 1)
    
    if (i == ((ROM_SIZE//4)-1)) :
      line.append(f"    {i} => \"{val:0{OUTPUT_WIDTH}b}\"     -- sin({i}) = {x}\n")
    else :
      line.append(f"    {i} => \"{val:0{OUTPUT_WIDTH}b}\",    -- sin({i}) = {x}\n")
    
  line.append("  );\n")
  line.append(f"  -- ___END_GENERATED_SECTION___\n")
  print("- insertROM: OK")




# =============================================================================
# ENTRY POINT
# =============================================================================
if (__name__ == "__main__") :
  main()