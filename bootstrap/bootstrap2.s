# Third stage bootstrap
# Line prefix determines behavior:
#   '#': Comment
#   ':': Set write address to hex 'abcd'
#   'tab': Assemble chars until a newline
#   'newline': Blank line, skipped
#
# Implements an assembler that supports two-pass labels (8-char long only)

# Ra = Zero register
	- aa
# Rb = One register
	=#b 0001
# Rc = Two register
	=#c 0002
# Rd = Four register
	=#d 0004
# Re = Eight register
	=#e 0008

# RA = Exit/cleanup address
	=#A 0900
# RB = Input line buffer base address
	=#B 2000
# RC = Symbol table address
	=#C 3000
# RD = Symbol table length
	- DD
# RE = Fixup table address
	=#E 4000
# RF = Fixup table length
	- FF
# RG = Main loop address (ie: read/process a line)
	=#G 0200
# RH = NOP
	=#H 1200
# RI = Current offset in output (used for fixup)
	=#I 0000
# RJ = Error handler
	=#J 0800
# RK = Line number
	- KK

# Get argv at $5000
	=#0 0005
	=#1 5000
	=#2 1000
	S+012   

# Open argv[1] as r/o in R8 (input)
	=#1 5004
	=(11
	=#8 0000
	S 81

# Open argv[2] as r/w in R9 (output)
	=#1 5008
	=(11
	=#2 0602
	=#9 0000
	S+912   

# Jump to main loop
	= 0G
	J G 

:0200
# Read a char
	=#0 0001
	= 1B
	=#2 0001
	S+0812  

# EOF? (return value == zero?)
	?=0a
	J?A 

# Load the character we just read
	=[01

# Empty line? If so, ignore
	=#1 000a
	?=01
	+?Kb
	J?G 

# Comment line? (#)
	=#1 0023
	?=01
	=#4 0300
	+?Kb
	J?4 

# Label line? (:)
	=#1 003a
	?=01
	=#4 0400
	J?4 

# Define line? (=)
	=#1 003d
	?=01
	=#4 0500
	J?4 

# Tab line?
	=#1 0009
	?=01
	=#4 0600
	J?4 

# Unknown prefix, error exit
	J J 

# Process comment
:0300
	=#0 0001
	= 2B
	S+0820  
	=[32
	=#2 000a
	?=32
	J?G 
	J 4 

# Process label
:0400
# Read 8 bytes to current symbol table address
	=#0 0001
	= 1C
	+ 1D
	=#2 0008
	S+0812  
# Add 8 to offset, then write current file address
	+ 1e
	(=1I
# Add 12 to symbol table address
	+ De
	+ Dd
# The trailing newline will get handled by the main loop
	J G 

# Process define
:0500
# Read 8 bytes to current symbol table address
	=#0 0001
	= 1C
	+ 1D
	=#2 0008
	S+0812  
	+ De
# Read five bytes (ie: space and value) and overwrite the instruction after the syscall
	=#0 0001
	=#1 0547
	=#2 0005
	S+0812  
	=#6 ????
# Write this constant to the symbol table too
	= 1C
	+ 1D
	(=16
# Add 4 to symbol table address
	+ Dd
# The trailing newline will get handled by the main loop
	J G 

# Process assembler line by copying to output
# If we encounter a colon, assume a fixup
:0600
# Read one char
	=#0 0001
	= 1B
	=#2 0001
	S+0812  
	=[21

# EOL? If so, return to main loop
	=#3 000a
	?=32
	+?Kb
	J?G 

# Macro? If so, expand to output
	=#3 0040
	?=32
	=#0 0700
	J?0 

# Colon? If so, write a fixup (assume fixup proc is 0x80 from colon proc)
	=#3 003a
	?=32
	=#0 00a0
	+?40
	J?4 

# Something else, so write to output and continue
	=#0	0002
	= 1B
	=#2	0001
	S+0912  
	+ Ib
	J 4 

# Write a fixup - assumes label reference is at EOL
:06a0
# Read eight bytes from input
	=#0 0001
	= 1B
	=#2 0008
	S+0812  
# Writes eight bytes to output
	=#0 0002
	= 1B
	=#2 0008
	S+0912  

# Write fixup address
	= 0E
	+ 0F
	(=0I

# Increment offset
	+ Ie

# Add 4 to fixup offset
	+ Fd

# The trailing newline will get handled by the main loop
	J G 

:0700
# Read 4 chars for macro
	=#0 0001
	= 1B
	=#2 0004
	S+0812  
	=(21

	=#1 0780
	=#4 1000
	=#5 0020
	=#6 0750
	J 6 

# Loop over macro defs until we read a zero
:0750
	= 04
	=(30
	?=23
	J?1 
	+ 45
	?!3a
	J?6 

# Error
	J J 

:0780
# Write the 12 bytes
	+ 0d
	=(30
	=#4 0798
	(=43
	=#2 ????
	+ 0d
	=#1 0002
	S+1902  
# Mark # of bytes output
	+ I2
# Continue processing assembler
	=#4 0600
	J 4 

# Generic error, try to preserve registers
:0800
	=#a 0002
	=#b 0002
	=#c 08f0
	=#d 0006
	S+abcd  
	=#a 0007
	=#b 0001
	S ab

:08f0
	ERROR!  

# Exit/cleanup
:0900
	=(6E
	+ Ed
	- Fd

# If we read a nul, means table was empty, normal exit
	?=6a
	=#0 0f00
	J?0 

# Seek to fixup
	=#0 0003
	S+096a  

# Read eight bytes (the address)
	=#0 0001
	S+09Be  

# Load into 0/1
	=(0B
	= 1B
	+ 1d
	=(11

# Search symbol table
	= 2C
	=#x 0950
	J x 

# Symbol search loop
:0950
# Load current symbol into 3/4
	=(32
	= 42
	+ 4d
	=(44

# Zero symbol means error
	?=3a
	=#x 09f0
	J?x 

# Diff this symbol and the lookup symbol
	- 30
	- 41
	| 34
	+ 2e
# Load the symbol address
	= 52
	+ 2d
# If we don't have the right symbol, keep going
	?>3a
	=#x 0950
	J?x 

# Seek to fixup
	=#0 0003
	S+096a  
# Write address/value
	=#0 0002
	= 1d
	S+0951  
# Write NOP
	=#0 0002
	= 5H
	S+0951  

# If fixup length == 0, done
	?>Fa
	J?A 

	=#x 0f00
	J x 

:09f0
	=#2 0002
	=#3 0002
	S+23Be  
	J J 

# Normal exit
:0f00
	=#0 0007
	- 11
	S 01

# Macros
# These could be defined in the next stage compiler, but we'll hard-code them
# for now to avoid adding more code in here
:1000
	ret.000c=(xy+ yd= zx
:1020
	ret?000c=(xy+?yd=?zx
:1040
	jump0004=$z 
:1060
# Conditional jump - works by skipping jump instruction if flag not set
	jmp?0008+^ze=$z 
:1080
	jmp^0008+?ze=$z 
:10a0
# Add 12 to the current address and push that as our return.
# This is not super-efficient as a call pattern but at this point
# in our bootstrap we don't care.
#
# sub sp, 4
# mov tmp, pc
# add tmp, 12
# mov [sp], tmp
# mov pc, address
	call0018- yd=#x 000c+ xz(=yx=$z 
# Support for push/pop for r0-r3
:10c0
	psh00008- yd(=y0
:10e0
	pop00008=(0y+ yd
:1100
	psh10008- yd(=y1
:1120
	pop10008=(1y+ yd
:1140
	psh20008- yd(=y2
:1160
	pop20008=(2y+ yd
:1180
	psh30008- yd(=y3
:11a0
	pop30008=(3y+ yd

# NOP
:1200
	= 00

# Input line buffer
:2000

# Symbol table
# 8-byte symbol, 4-byte address
:3000


# Fixup table
:4000
