;
;	Major items to do
;
;	Consider cond jump table
;	Rearrange to maximise use of branches via bsr/bra
;	Random number generator
;	Code to output correct game database format
;	Save and Load
;	Ask Yes/No on Quit
;	Reset machine correctly
;	NESWUDI shortforms
;	Vast amounts of deubugging
;	Encrypt text / compression if needed (upper only so should work
;	well with a simple ETAIONSHRDU style compressor or a 5bit code)
;	Replace zero termination with top bit set or length.8 and list run
;	to save memory if needed (length.7 + '*' bit may even work ?)
;	Justification engine (top and bottom)
;	Condition <= >= 16bit check
;	Ramsave/load
;	MCX graphics ??? 8)
;
	org 17500

LIGHTOUT	equ	16
DARKFLAG	equ	15
LIGHT_SOURCE	equ	9

NUM_OBJ		equ	32
NUM_BITS	equ	32

VERB_GO		equ	1
VERB_GET	equ	10
VERB_DROP	equ	18

start:
	bsr wipe_screen
	bsr start_upper
	ldx #hello
	jsr strout_upper
	bsr end_upper
	ldaa #$7A
	jsr hexout_lower
	ldx #hello2
	jsr strout_lower
	jsr line_input
	ldx #hello3
	jsr strout_lower
	ldx #linebuf
	jsr strout_lower
	ldx #hello4
	jsr strout_lower
	jsr read_key
	rts

;
;	Wipe the screen
;
wipe_screen:
	ldx #$4000
wipeblock:
	ldd #$2020
wiper:
	std ,x
	inx
	inx
	cpx #$4200
	bne wiper
	rts

wipe_lower:
	ldx lowtop
	bra wipeblock
;
;	Scroll the lower window
;
scroll_lower:
	ldx lowtop
lowscrl:
	ldd 32,x
	std ,x
	inx
	inx
	cpx #$4200-32		; last line for scroll work
	bne lowscrl
	ldaa #$20
lowclr:
	staa ,x
	inx
	cpx #$4200
	bne lowclr
	rts

;
;	Start using the upper area. Clear the old upper zone
;
;	Assumption: upper is never empty
;
start_upper:
	ldx #$4000
	ldd #$2020
wipeoldupper:
	std ,x
	inx
	inx
	cpx lowtop
	bne wipeoldupper
	; Move the upper position
	ldx #$4000
	stx nextupper
	rts
;
;	Finished using the upper area. Draw the divider and set up for
;	the low section
;
end_upper:
	ldd nextupper
	addd #$1F
	andb #$E0
	std lowtop
	ldx lowtop
	ldd #$7C20	; 7C is < for 32 bytes
divider:
	staa ,x
	inx
	eora #$2
	decb
	bne divider
	stx lowtop
	rts
;
;	Print to the upper screen area. We never handle characters wrapping
;	as the higher level justifier is responsible for that
;
chout_upper:
	ldx nextupper
	cmpa #10
	beq upper_nl
	anda #63
	staa ,x
	inx
upper_st_out:
	stx nextupper
	rts
upper_nl:
	ldab nextupper+1
	andb #$1f		; X position
	ldaa #$20		; Width
	sba			; A is now bytes to move on
	ldab #$20
upper_spc:			; Clear the rest of the line
	stab ,x
	inx
	deca
	bne upper_spc
	bra upper_st_out
;
;	Print to the lower screen area
;
chout_lower:
	cmpa #10
	beq lower_nl
	anda #63
	ldx nextchar
	cpx #$4200
	bne not_scroll
	psha
	jsr scroll_lower
	ldx #$4200-32
	pula
not_scroll:
	staa ,x
	inx
lower_st_out:
	stx nextchar
	rts
lower_nl:
	jsr scroll_lower
	ldx #$4200-32
	bra lower_st_out

;
;	Print a string of text to the lower window
;
strout_lower:
	ldaa ,x
	beq strout_done
	anda #63
	pshx
	bsr chout_lower
	pulx
	inx
	bra strout_lower
strout_done:
	rts

;
;	Print a string of text to the upper window
;
strout_upper:
	ldaa ,x
	beq strout_done
	pshx
	bsr chout_upper
	pulx
	inx
	bra strout_upper

;
;	Hexadecimal output to lower window (debug only)
;
hexout_lower:
	psha
	rora
	rora
	rora
	rora
	bsr hexdigit
	pula
hexdigit:
	anda #$0F
	cmpa #$0A
	blt hexout_digit
	adda #$07
hexout_digit:
	adda #'0'
	bra chout_lower

;
;	Decimal output to lower window (0-99 is sufficient)
;	
decout_lower:
	clrb
decout_div:
	suba #$0A
	bcs decout_mod
	incb
	bra decout_div
decout_mod:
	adda #$0A		; correct overrun
	psha
	tba
	bsr hexdigit
	pula
	bra hexdigit

	
;
;	Keyboard
;
read_key:
	ldx $FFDC
	jsr ,x
	beq read_key
;
;	0D - newline, 08 - delete
; 
	rts

;
;	Wait for newline
;
wait_cr:
	bsr read_key
	cmpa #$0D
	bne wait_cr
	rts

;
;	Yes or No. Returns B = 0 for Yes, 0xFF for no
;
yes_or_no:
	clrb
	bsr read_key
	cmpa #$'y'
	beq is_yes
	cmpa #$'Y'
	beq is_yes
	cmpa #$'J'
	beq is_yes	; German Gremlins!
	cmpa #$'n'
	beq is_no
	cmpa #$'N'
	bne yes_or_no
is_no:	decb
is_yes:	rts

;
;	Line editor
;
line_input:
	ldx nextchar
	ldaa #96
	staa ,x			; initial cursor
	ldx #linebuf
	stx lineptr
	dec nextchar+1		; won't wrap the page so safe
line_loop:
	bsr read_key
	ldx lineptr
	cmpa #$08
	beq delete_key
	cmpa #$0D
	beq enter_key
	cmpa #' '
	blt line_loop
	cpx #linebuf+29		; 32 minus "> " and cursor
	beq line_loop		; didn't fit
	staa ,x
	inx
	stx lineptr
	ldx nextchar
	anda #63
	staa ,x
	inx
	ldaa #96
line_st:
	staa ,x
	stx nextchar
	bra line_loop
delete_key:
	cpx #linebuf
	beq line_loop
	dex
	stx lineptr
	ldx nextchar
	ldaa #' '
	staa ,x
	dex
	ldaa #96
	bra line_st
enter_key:
	clr ,x			; Mark the end of the buffer
	ldx nextchar		; Clean up the cursor
	ldaa #'.'
	staa ,x
	ldaa #10
	jmp chout_lower		; Move on a line and return

	
;
;	Parser
;

;
;	Clear tail of 4 char word
;
word_clear
	ldx #wordbuf
wordclr4l:
	ldaa ,x
	beq zerorest
	cmpa #32
	beq zerorest
	inx
	cpx #wordbuf+4
	bne wordclr4l
	; >= 4 letters
	rts
zerorest:
	clr ,x
	inx
	cpx #wordbuf+4
	bne zerorest
skipdone:
	rts

;
;	Find a word in the verb table
;
whichverb:
	ldx #verbs
	bra whichword
;
;	Find a word in the noun table
;
whichnoun:
	ldx #nouns
;
;	Find a word. The approach used is weird but we copy it to keep the
;	numbering. Aliases are the same as the non alias word, but all words
;	are numbered. So if word 2 is an alias then word 2 returns 1 but
;	word 3 returns 3
;
whichword:
	clr tmp8
	tst wordbuf
	beq foundword		; 0 - none
	ldaa #1
	staa tmp8		; counter
	staa tmp8_2		; word code
	
whichwordl:
	jsr wordeq
	beq foundword
	inc tmp8
	ldab ,x
	bitb #0x80		; alias - don't bump code
	bne alias
	ldaa tmp8
	staa tmp8_2
alias:
	ldab wordsize
	abx
	tst ,x			; 0 - end of list
	bne whichwordl
	ldab #0xff		; Word present but not in vocabulary
	rts
foundword:
	ldab tmp8_2		; Load word into B
	rts

;
;	X points to the input. Skip any spaces
;
skip_spaces:
	ldaa #32
skipl:
	cmpa ,x
	bne skipdone
	inx
	bra skipl
;
;	Copy a word into the wordbuf (max 4 letter matches)
;
copy_word:
	bsr skip_spaces
	stx nounbuf		; we always scan noun second so this is ok
	ldd ,x
	std wordbuf
	ldd 2,x
	std wordbuf+2
	pshx
	bsr word_clear		; clear end of word buf to zero for matching
	pulx
	ldaa #32
copymove:
	cmpa ,x			; Space
	beq nextsp		; Word over
	tst ,x			; End
	beq nextsp		; Word over
	inx			; Move on a byte
	bra copymove		; Keep looking
nextsp:
	rts

;
;	Scan the input for a verb / noun pair. German language games are a
;	bit different so this won't work for them
;
scan_input:
	ldx #linebuf
	bsr copy_word		; Verb hopefully
	pshx
	jsr whichverb
	stab verb
	pulx
scan_noun:			; Extra entry point used for direction hacks
	bsr copy_word
	jsr whichnoun
	stab noun
	rts

;
;	Main game logic runs from here
;
main_loop:
	jsr look
	bra do_command_1

do_command:
;
;	Implement the builtin logic for the lightsource in these games
;
	ldab objloc + LIGHT_SOURCE
	beq do_command_1
	ldaa lighttime
	cmpa #255			; does  not expire
	beq do_command_1
	deca
	bne light_ok
	clr bitflags + LIGHTOUT		; light goes out
	cmpb #255
	beq seelight
	cmpb location
	bne unseenl
seelight:
	ldx #lightout
	jsr strout_lower
unseenl:
; Earliest engine only
;	clr objloc + LIGHT_SOURCE
	inc redraw
	bra do_command_1
light_ok:
	cmpa #25			; warnings start here
	bhi do_command_1		; FIXME: some games do a general
	ldx #lightoutin			; warning every five instead
	psha
	jsr strout_lower
	pula
	psha
	jsr decout_lower
	ldx #turns
	pula
	cmpa #1
	bne turns_it_is
	ldx #turn
turns_it_is:
	jsr strout_lower

; Fall through	
;
;	We start by running the status table. All lines in this table are
;	automatic actions or random %ages. We could possibly squash it a bit
;	more by not using the same format, but it's not clear the code
;	increase versus data decrease is a win
;
do_command_1:
	clr verb		; indicate status
	clr noun
	ldx #status
	jsr run_table		; run through the table
	tst redraw		; do a look if the status table moved
	beq no_redraw		; anything in or out of view, or moved us
	jsr look
	clr redraw
no_redraw:
do_command_2:
	ldx #whattodo		; prompt the user
	jsr strout_lower
	jsr wordflush		; avoid buffering problems
do_command_l:
	jsr line_input		; read a command
	ldx #linebuf
	jsr skip_spaces
	tst ,x			; empty ?
	beq do_command_l	; round we go
	pshx
	jsr scan_noun		; take the first input word and see
	ldaa noun		; if its a direction
	beq notdirn
	cmpa #6
	bgt notdirn
	ldaa #VERB_GO
	staa verb		; convert this into "go foo"
	pulx
	bra parsed_ok
;
;	Try a normal verb / noun parse
;
notdirn:
	pulx
	jsr scan_input
	ldaa verb
	beq do_command_l	; no verb given ?
	cmpa #0xff
	bne parsed_ok
	ldx #dontknow		; no verb, error and back to the user
	jsr strout_lower
	jmp do_command_2


parsed_ok:
;
;	We have a verb noun pair
;
;	Hardcoded stuff first (yes this is a bad idea but it's how the
;	engine works)
;
	ldaa verb
	cmpa #VERB_GO		; GO [direction]
	bne not_goto
	ldab #noun
	bne not_goto
	ldx #givedirn		; Error "go" on it's own
	jsr strout_lower
	bra do_command_2
not_goto_null:
	cmpb #6
	bgt not_goto		; not a compass direction
	pshb
	clr tmp8
	jsr islight		; check if it is dark
	beq not_dark_goto
	inc tmp8		; temporary dark flag
	ldx #darkdanger		; warn the user
	jsr strout_lower
not_dark_goto:
	ldx #locdata		; look up direction table
	ldab location
	lslb			; 8 bytes a location
	lslb
	lslb
	abx			; points to location entry
	pulx
	abx			; add direction (1-6)
	inx			; allow for the fact 2 bytes of text ptr
	tst ,x			; valid ?
	bne can_do_goto
	tst tmp8		; falling in the dark ?
	beq movefail		; light so ok
	ldx #brokeneck		; tell the user
	jsr strout_lower
	jsr act88		; do a delay
	jsr act61		; and die
	jmp do_command
movefail:
	ldx #cantgo		; tell the user they can't move
	jsr strout_lower
	jmp do_command_2
can_do_goto			; a goto that works
	ldab ,x			; b is new location
	stab location		; move
	inc redraw		; will need to redraw
	bra do_command_far
;
;	Then the tables (the goto first is a design flaw in the Scott Adams
;	system)
;
not_goto:
	clr linematch		; match state for error reporing.
	clr actmatch
	ldx #actions		; run the action table
	jsr run_table
	tst actmatch		; we did actions, so all was good
	bne do_command_far
	ldx #dontunderstand
	tst linematch		; got as far as conditions
	beq notnotyet		; a match exists but conds failed ?
	ldx #notyet		; give user a clue if so
notnotyet:
	jsr strout_lower		; display error
do_command_far:
	jmp do_command

;
;	Useful Helpers
;

;
;	Check if we are in the light (Z) or not (NZ)
;
islight:
	tst bitflags + DARKFLAG		; if it isn't dark then it's light
	beq lighted
	ldaa objloc + LIGHTSOURCE	; get the lamp
	cmpa #255			; carried ?
	beq lighted
	cmpa location			; in the room ?
lighted:
	rts

;
;	Given X is the objloc pointer of an object return its text string.
;	This looks an odd interface but all our callers happen to have this
;	X value directly to hand and we are quite register limited.
;
getotext_x:
	psha
	pshb
	stx tmp16	; Need to go X to D
	ldab tmp16+1	; Only the low offset matters
	subb #objloc % 256
	ldx #objtext	; Two byte pointer per object
	abx
	abx
	ldx ,x		; Dereference
	pulb
	pula
	rts

;
;	Game Conditions
;
perform_line:
	ldd #args
	std argp
	ldab ,x
	stab condacts		; need again shortly
	rorb
	rorb
	andb #0x7		; B is condition count
condl:
	pshx
	pshb
	bsr cond		; run the condition
	tsta			; did it fail
	bne nextrow		; if so we the line is done
	pulb
	pulx
	inx			; move on a condition
	inx
	decb
	bne condl		; done yet
;
;	Now we can process the actions
;
	inc actmatch
	ldd #args		; reset the arg pointer
	std argp
	ldab condacts		; see how many actions
	andb #3
nextact:
	ldaa ,x			; get the action code
	inx			; move on
	pshx
	pshb
	jsr act			; run the action
	pulb
	pulx
	decb
	bne nextact		; until done
nextrow:
	pulb			; then return
	pulx
	rts

;
;	?? Does this need to sign extend ??
;
arghigh:
	ldaa argh
	rola
	rola
	rola
	anda #0x07		; High bits
	rts

;
;	Run conditions. We do this odd dec/bra sequence to save us
;	registers. It's probably a mistake and we should use a table
;
cond:
	ldd ,x			; A = cond, B = value
	staa argh		; High arg bits saved
	anda #0x1F		; Low bits only
	tsta
	bne cond1
;
;	Condition 0 is "parameter", and always true. It saves a parameter
;	for the actions to use
;
	ldx argp
	stab ,x
	inx
	bsr arghigh
	staa ,x
	inx
	stx argp
;
;	True condition
;
condnp:
	clra
	rts
cond1:
	pshx
;
;	Many conditions want the object referenced by the argument. We
;	set x up as a pointer to the argument
;
	ldx #objloc
	abx
	deca
;
;	Condition 1: true if the objct is carried
;
	bne cond2
	ldaa ,x
	cmpa #255
;
;	General purpose "true if eq"
;
cbrat:
	beq condnp
condfp:
	ldaa #255
	rts
cond2:
	deca
	bne cond3
;
;	Condition 2: true if the object is in the same room
;
	ldaa ,x
cond2c:
	cmpa location
	bra cbrat
cond3:
	deca
	bne cond4
;
;	Condition 3: true if the object is in the same room or carried
;
	ldaa ,x
	cmpa #255
	beq condnp
	bra cond2c
cond4:
	deca
	bne cond4
;
;	Condition 4: true if the player is in a given place
;
	cmpb location
	bra cbrat
cond5:
	deca
	bne cond6
;
;	Condition 5: true if the object is not in the same room
;
	ldaa ,x
	cmpa location
;
;	General purpose true if not eq
;
cbraf:
	bne condnp
	bra condfp
cond6:
	deca
	bne cond7
;
;	Condition 6: true if the object is not carried
;
	ldaa ,x
	cmpa #255
	bra cbraf
cond7:
	deca
	bne cond8
;
;	Condition 7: true if the player is not in a given place
;
	cmpb location
	bra cbraf
cond8:
	deca
	bne cond9
;
;	Condition 8: True if bitflag n is set
;
	ldx bitflags
	abx
	tst ,x
	bra cbraf
cond9:
	deca
	bne cond10
;
;	Condition 9: True if bitflag n is clear
;
	ldx bitflags
	abx
	tst ,x
	bra cbrat
cond10:
	deca
	bne cond11
;
;	Condition 10: Carrying any objects
;
	tst carried
	bra cbraf
cond11:
	deca
	bne cond12
;
;	Condition 11: Not carrying any objects
;
	tst carried
	bra cbrat
cond12:
	deca
	bne cond13
;
;	Condition 12: Object not carried or in location
;
	ldaa ,x
	cmpa #255
	beq condfp
	cmpa location
	bra cbrat
cond13:
	deca
	bne cond14
;
;	Condition 13: Object not destroyed (room 0)
;
	ldaa ,x
	bra cbraf
cond14:
	deca
	bne cond15
;
;	Condition 14: Object is destroyed (room 0)
;
	ldaa ,x
	bra cbrat_f
cond15:
	deca
	bne cond16
;
;	Condition 15: Current counter is <= arg
;	FIXME: should be a 16bit compare!
;
	cmpb counter + 1
	bgt condnp_f
condfp_f:
	jmp condfp
condnp_f:
	jmp condnp
cond16:
	deca
	bne cond17
;
;	Condition 16: Current counter is >= arg
;	FIXME: should be a 16bit compare!
;
	cmpb counter+1
	blt condnp_f
	bra condfp_f
cond17:
	deca
	bne cond18
;
;	Condition 17: Object is in its original location
;
	ldaa ,x
	ldx #objinit
	abx
	cmpa ,x
	bra cbrat_f
cond18:
	deca
	bne cond19
;
;	Condition 18: Object is not in its original location
;
	ldaa ,x
	ldx #objinit
	abx
	cmpa ,x
	jmp cbraf
cond19:
	deca
	bne condbad
;
;	Condition 19: Counter is equal to value.
;
	cmpb counter+1
	beq cbrat_f
	jsr arghigh
	cmpa counter
	ldab 
cbrat_f
	jmp cbrat
;
;	If we get this far it is not a valid condition
;
condbad:
	ldx #invcond
	jsr strout_lower
halted:
	bra halted


;
;	Game Actions
;

;
;	Print a message given by A-52
;
msg2:
	suba #51
;
;	Print message given by A
;
msg:
	tab
	ldx #msgptr
	abx
	abx
	ldx ,x
	jmp strout_lower

;
;	Action 0 (shouldn't appear)
;
noop:
	rts

;
;	Process the actions. We handle these via a jump table
;
act:
	tsta
	beq noop
;
;	Codes < 52 are messages, codes >= 102 are the second lot of
;	messages. Historical bad planning ?
;
	cmpa #52
	blt msg
	cmpa #102
	bhi msg2
;
;	Real action
;
	tab
	ldx #actab-104  ; First action is 52, 2 bytes each
	abx
	abx		; Find our entry
	jmp ,x		; Off we go

;
;	Collect a parameter argument (low 8bits) and put it into
;	A. Return with A = arg, X = objloc ptr to object A and B = location
;	of object A
;
get_arg:
	ldx argp
	inx
	ldab ,x		; Low byte
	inx
	stx argp
	ldx #objloc
	abx
	tba		; Argument to A
	ldab ,x		; Location to B
	rts

;
;	Retrieve a 16bit parameter in D
;
get_arg16:
	ldx argp
	ldd ,x
	inx
	inx
	stx argp
	rts

;
;	Action 52: Get an object providing it can be carried. If not display an
;	error message.
;
act52:
	ldaa carried
	cmpa maxcar			; Full up ?
	blt carok
	inc argp			; Eat the argument
	inc argp
	ldx #toomuch			; And error
	jmp strout_lower
carok:
	bsr get_arg		; A argument, X ptr to O(arg), B = O(arg)
	ldaa #255		; Move to carried
	; Fall through
;
;	General purpose object move. Tracks redraw and carried counter
;	status.
;
;	X = object ptr, B = current loc, A = new loc
;	moves object and fixes carried/redraw
;
move_item:
	cmpa ,x			; not moving ?
	beq noop
	cmpb location		; was visible
	bne notrdrw
	inc redraw		; so should redraw
notrdrw:
	cmpb #255		; was carried ?
	bne notlost
	dec carried		; so drop count
notlost:
	staa ,x			; move it
	cmpa #255		; now carried ?
	beq chkloc2
	inc carried		; so raise count
chkloc2:
	cmpa location		; moved into view ?
	beq notrdrw2
	inc redraw
notrdrw2:
	rts

;
;	Action 53: Drop an object into the current location
;
act53:
	bsr get_arg
	ldaa location
	bra move_item

;
;	Action 54: Move to a location
;
act54:
	bsr get_arg
	staa location
redrawit:
	inc redraw
	rts

;
;	Action 55/9: Destroy an object
;
act55:
act59:
	bsr get_arg
	clra
	bra move_item
;
;	Action 56: Set the dark flag
;
act56:
	ldaa #255
	staa bitflags + DARKFLAG
	rts
;
;	Action 57: Clear the dark flag
;
act57:
	clr bitflags + DARKFLAG
	rts
;
;	Action 58: Set bit flag
;
act58:
	tab
	ldx #bitflags
	abx
	ldaa #255
	staa ,x
	rts

;
;	Action 60: Clear bit flag
;
act60:
	tab
	ldx #bitflags
	abx
	clra
	rts

;
;	Action 61: Die, move to end of game
;
act61:
	ldx #dead
	jsr strout_lower
	clr bitflags + DARKFLAG
	ldaa lastloc
	staa location
	; fall through

;
;	Action 64,76: Look
;
act64:
act76:
	; look
	jmp look

;
;	Action 62: Move an object to a given location
;	
act62:
	jsr get_arg
	pshx
	pshb
	jsr get_arg
	tba
	pulb
	pulx
	bra move_item
;
;	Action 63: Game Over
;
act63:
	; throw an exception out of the interpreter (should ask first or
	; exit FIXME)
;	lds #stacktop
	jmp start_game

;
;	Action 67: Set bit flag 0
;
act67:
	ldab #255
	stab bitflags
	rts

;
;	Action 68: Clear bit flag 0
;
act68:
	clr bitflags
	rts

;
;	Action 69: Refill the lamp
;
act69:
	ldaa lightfill
	staa lighttime
	clr bitflags + LIGHTOUT
	ldx #objloc + LIGHT_SOURCE
	ldab ,x
	ldaa #255
	jmp move_item

;
;	Action 70: Clear the screen
;
act70:
	; clear screen (some versions only)
	jmp wipe_lower

;
;	Action 72: Swap two objects over
;
act72:
	jsr get_arg
	pshx		; Save objloc ptr for object 1
	pshb		; Save current location for object 1
	jsr get_arg	; Get object 2
	tba		; A is now the location of object 2
	pulb		; Recover location of object 1
	stab ,x		; Second object to first
	pulx		; Pointer to object 1
	staa ,x		; Swapped over
	cmpa location
	bne noplacerd
	cmpb location
	bne noplacerd
	inc redraw
noplacerd:
	rts
;
;	Action 73: Set the continuation flag
;
act73:
	inc continuation
	rts

;
;	Action 74: Move object to inventory regardless of weight
;
act74:
	jsr get_arg
	ldaa #255
	jmp move_item
;
;	Action 75: Place one object with another
;
act75:
	jsr get_arg
	pshx
	pshb
	jsr get_arg
	tba		; loc of second object is our target
	pulb
	pulx
	jmp move_item
;
;	Action 77: Decrement counter
;
act77:
	ldd counter
	; FIXME - check this sets zero right
	beq nodec
	subd #1
	std counter
nodec:
	rts

;
;	Action 78: Print counter value
;
act78:
	ldd counter
	tba
	jmp decout_lower

;
;	Action 79: Set counter
;
act79:
	jsr get_arg16
	std counter
	rts
;
;	Action 80: Swap player location with saved room (YOHO etc)
;
act80:
	ldaa location
	ldab savedroom
	staa savedroom
	stab location
	inc redraw
	rts
;
;	Action 81: Swap current counter with counter n
;
act81:
	jsr get_arg
	tab
	ldx #counter_array
	abx
	abx
	ldd ,x
	psha
	pshb
	ldd counter
	std ,x
	pulb
	pula
	std counter
	rts

;
;	Action 82: Add to current counter
;
act82:
	jsr get_arg16
	addd counter
	std counter
	rts

;
;	Action 83: Subtract from current counter. Negative values all turn
;	into -1.
;
act83:
	jsr get_arg16
	std tmp16
	ldd counter
	subd tmp16
	bcc notneg
	ldd #-1
notneg:
	std counter
	rts

;
;	Action 84: Print the noun string and a newline 
;
act84:
	bsr act86
;
;	Action 86: Print a newline
;
act86:
	ldx #newline
	jmp strout_lower

;
;	Action 84: Print the noun string
;
act85:
	ldx #nounbuf
	jmp strout_lower
;
;	Action 87: Swap the current location and saveroom flag n
;	(Claymorgue). Interestingly this is broken on the genuine 6809
;	interpreter !
;
act87:
	jsr get_arg
	tab
	ldx #roomsave
	abx
	ldaa ,x
	ldab location
	stab ,x
	staa location
	cmpa ,x
	beq noop2
	inc redraw
noop2:
	rts

;
;	Action 88: Two second delay
;
act88:
	; FIXME - 2 second wait
	ldd #0
snooze:
	addb #1
	adca #0
	bcc snooze
	rts

;
;	Action 89: Various. SAGA uses it to draw pictures, Seas of Blood
;	uses it to start combat.
;
act89:
	; Specials for SAGA etc
	jmp get_arg

;
;	Action 65: Display the score
;
;
;	FIXME: should give percentages
;
;	The score is computed by counting treasures in the treasure room
;	and seeing how many we have. If we have all of them we report so and
;	quit. It's any oddity of the Scott Adams system that you have to
;	type "score" to win !
;
act65:
	ldx #stored_msg
	jsr strout_lower

	ldx #objloc
	ldaa #0
score2:
	ldab treasure
	cmpb ,x
	bne notintreas
	pshx
	jsr getotext_x		; Object texts start * for treasure
	ldab #'*'
	cmpb ,x
	pulx
	bne notintreas
	inca
notintreas:
	inx
	cpx objloc_end
	bne score2
	; A is now the count to print
	psha
	jsr decout_lower
	ldx #stored_msg2
	jsr strout_lower
	pula
	cmpa treasures
	bne not_act63		; quit
	jmp act63
not_act63:
	rts

;
;	Action 66: Display the inventory
;
act66:
	ldx #carrying
	jsr strout_lower
	ldx #objloc
	ldd #255		; A 0 B 255
	clr tmp8
objl:
	cmpb ,x
	bne notgot
	tst tmp8		; first item found ?
	beq inv_1
	pshx
	ldx #dashstr
	jsr strout_lower
	pulx
inv_1:	inc tmp8
	pshx
	jsr getotext_x
	jsr strout_lower
	pulx
notgot:
	inx
	cpx #objloc_end
	bne objl
	tst tmp8
	bne invstuff
	ldx #nothing
	jsr strout_lower
invstuff:
	ldx #dotnewline
	jmp strout_lower

;
;	Table execution engine. Each table is a series of lines in the form
;	[[A][R][U][CCC][AA]][conditions][actions]
;
;	A bit indicates an "auto" or continuation action
;	R bit indicates no random %age is present if an auto action
;	U is unused
;	CCC is the number of conditions
;	AA is the number of actions
;
;	Followed by condition.b, value.b several times and then by action.b
;	several times to form the full line.
;
;	FIXME: conditions are really supposed to allow conds/params > 255,
;	we don't handle that well yet.
;

run_table:
	clr continuation	; will get set by a continuation action
next_action:
	pshx			; Save line start
	ldaa ,x
	bita #0x80		; 0 , 0 flag
	bne not_cont
	tst continuation	; Skip continuations we didn't match
	beq next_line
	bita #0x40
	bne not_random
	; FIXME random %age
not_random
	inx
	bra do_line

;
;	If we are doing continuations and hit a non continuation line
;	then we have finished. Otherwise the verb/noun must match for us
;	to process the line.
;
not_cont:
	tst continuation
	bne action_done		; hit a new block - done
	ldd 1,x
	cmpa verb
	bne next_line
	cmpb noun
	beq match_ok
	tstb
	bne next_line
match_ok:
	;
	;	Verb matches and noun matches or is not given
	;
	inc linematch
do_line:
	pshx
	jsr perform_line	; run the conditions and actions
	pulx
	tst continuation	; continuation - keep scanning
	beq next_line
	ldaa ,x
	bita #0x80		; 0, x lines don't stop processing
	bne next_line
	jmp action_done		; all done and good

;
;	Top of stack is the head byte of the current line. Use this to find
;	the next line.
;
next_line:
	pulx
	ldaa ,x
	bita #0x80		; 0x80 - vocab bytes omitted
	bne squashed
	inx			
	inx
squashed1:
	inx			; move on to the conditions and actions
	tab
	anda #3			; actions
	lsrb
	andb #14		; 2 * conds
	abx
	tab
	abx
	ldaa ,x			; round we go
	inca			; 255 is end of table
	bne next_action
squashed:
	bita #0x40		; 0x40 = random %age suppressed
	bne squashed1		; squashed1 skips the header
	inx			; skip the random %age as well
	bra squashed1

;
;	All completed. If this was an action then consider builtins, if not
;	we are done
;
action_done:
	ldaa verb
	cmpa #255
	bne builtins
all_done:
	rts

builtins:
	tst linematch
	bne all_done
	; FIXME - some games have specials for get/put all. Some games
	; have no builtins (early)
	ldaa verb
	cmpa #VERB_GET		; 10
	bne not_get
	;
	;	Automatic get handler
	;
	ldab noun
	beq ummwhat
	ldab carried
	cmpa maxcar
	blt cancarry
	ldx #toomuch
	jsr strout_lower
	bra all_done
cancarry:
	ldab #255
	bsr autonoun		; Find the object of this noun if any
	cmpa #255
	bne knownobjg
bpower:
	ldx #beyondpower
	jsr strout_lower
	bra all_done
knownobjg:
	ldaa #255
domove:
	ldab ,x
	jsr move_item
	ldx #okmsg
	jsr strout_lower
	bra all_done
not_get:
	;
	;	Automatic drop handler
	;
	cmpa #VERB_DROP		; 18
	bne not_drop
	ldab noun
	beq ummwhat
	ldab location
	bsr autonoun
	cmpa #255
	beq bpower
	ldaa location
	beq domove
not_drop:
	bra all_done

ummwhat:
	ldx #whatstr
	jsr strout_lower
	bra all_done

;
;	On entry B holds the location to scan. We check for
;	any auto entry that matches our word and is in the
;	correct location, then return that or 0xff if no match.
;
autonoun:
	ldx #automap
	stab tmp8		; location to match
	tst wordbuf
	beq noauto		; 0 - none
	ldab #5			; 5 bytes per entry
autonounl:
	jsr wordeq
	beq foundnoun
nextnoun:
	abx
	tst ,x			; 0 - end of list
	bne autonounl
noauto:
	ldab #0xff		; Word present but not in vocabulary
	rts
foundnoun:
	pshx
	pshb
	ldab 4,x		; object id
	ldx #objloc
	abx
	ldaa ,x			; location
	cmpa tmp8
	beq objmatch
	pulb
	pulx
	bra nextnoun
objmatch:
	ins			; discard b
	pulx
	rts

;
;	Look: Display the location details. This ends up in the upper
;	window, as the Scott Adams' system uses a two window output model.
;
look:
	jsr start_upper		; Clear out the old
	jsr islight		; See if it is dark
	beq cansee		; Nope
	ldx #itsdark		; "It is dark"
	jsr strout_upper
	jmp end_upper		; and done

cansee:
	ldab location		; Find the right location data
	lslb
	lslb
	lslb
	ldx #locdata		; base + 8 * location (6 exits, 2 byte msgptr)
	abx
	pshx			; Save our pointer
	ldx ,x			; Get the message ptr
	ldaa #'*'		; Is it *
	cmpa ,x
	bne notshort		; Nope.. just print it
	pshx			; Save it
	ldx #youare		; Standard game prefix ("You are", "I am")
	jsr strout_upper
	pulx
	inx			; Skip *
notshort:
	jsr strout_upper		; Print the location text
	clr tmp8		; No exit seen yet
	ldx #obexit		; Exits string
	jsr strout_upper
	pulx			; Recover the location ptr
	inx			; Move on to exits
	inx
	clrb			; Count exits
exitl:
	tst ,x			; 0 = none
	beq notanexit
	pshx			; Save our pointer
	tst tmp8		; First exit ?
	beq firstexit
	ldx #dashstr		; Print - or , 
	jsr strout_upper
firstexit:
	inc tmp8		; No longer first exit
	ldx #exitmsgptr		; Exit messages
	abx			; Find the right one
	abx
	ldx ,x
	jsr strout_upper	; Print it
	pulx			; Get our exits pointer back
notanexit:
	inx			; Move on
	incb			; Done ?
	cmpb #6
	blt exitl
	tst tmp8		; No exits ?
	bne wasstuff
	ldx #nonestr		; "None"
	jsr strout_upper
wasstuff:
	ldx #dotnewline		; "."
	jsr strout_upper
	clr tmp8		; No objects seen
	ldx #objloc
	ldab location
lookiteml:
	cmpb ,x			; Object here ?
	bne objnothere
	pshx			; Print either - or also see message
	ldx #dashstr
	tst tmp8
	bne notfirsti
	ldx #canalsosee
notfirsti:
	inc tmp8		; Object seen
	jsr strout_upper
	pulx			; Recover our object pointer
	pshx
	jsr getotext_x		; Print the object name
	jsr strout_upper
	pulx
objnothere:
	inx
	cpx #objloc_end		; Done ?
	blt lookiteml		; Keep going
	tst tmp8
	beq nothingtosee
	ldx #dotnewline		; Finish up
	jsr strout_upper
nothingtosee:
	jmp end_upper		; Draw the barrier line and donee

start_game:
	sei
setup_obj:
	ldx #objinit_end
	lds #objloc_end		; FIXME check not off by 1
setup_loop:
	dex
	ldaa ,x
	psha
	cpx #objinit
	bne setup_loop
	ldx #zeroblock		; Range to wipe
;
;	Clear flags and counters
;
clearl:
	clr ,x
	inx
	cpx #zeroblock_end
	bne clearl
	ldaa startloc
	staa location
	lds #stacktop
	cli
	jmp main_loop	

hello:
	fcc "HELLO WORLD"
	fcb 10
	fcc "THIS IS NOT A RECORDING"
	fcb 10
	fcb 0

hello2:
	fcc "HELLO DOWNSTAIRS"
	fcb 10
	fcc "THIS IS NOT A RECORDING EITHER"
	fcb 10
	fcc ">  "	; second space for cursor
	fcb 0

hello3:
	fcc "YOU SAID '"
	fcb 0

hello4:
	fcc "'."
	fcb 10,0	

nextchar:
	fdb $4200
lowtop:
	fdb $4020
nextupper:
	fdb $4000
lineptr:
	fdb linebuf
linebuf:
	zmb 30		; buffer for input
wordbuf:
	zmb 4
nounbuf:
	fdb 0


;
;	System Messages
;
toomuch:
	fcc "YOU ARE CARRYING TOO MUCH. "
	fcb 0
dead:
	fcc "YOU ARE DEAD."
	fcb 10,0
stored_msg:
	fcc "YOU HAVE STORED "
	fcb 0
stored_msg2:
	fcc "TREASURES. ON A SCALE OF 0 TO 100, THAT RATES "
dotnewline:
	fcc "."
newline:
	fcb 10,0
carrying:
	fcc "YOU ARE CARRYING:"
	fcb 10,0
dashstr:
	fcc " - "
	fcb 0
nothing:
	fcc "NOTHING"
	fcb 0
lightout:
	fcc "YOUR LIGHT HAS RUN OUT. "
	fcb 0
lightoutin:
	fcc "YOUR LIGHT RUNS OUT IN "
	fcb 0
turns:
	fcc "TURNS"
	fcb 0
turn:
	fcc "TURN"
	fcb 0
whattodo:
	fcb 10
	fcc "TELL ME WHAT TO DO ? "
	fcb 0
dontknow:
	fcc "YOU USE WORD(S) I DON'T KNOW! "
	fcb 0
givedirn:
	fcc "GIVE ME A DIRECTION TOO ."
	fcb 0
darkdanger:
	fcc "DANGEROUS TO MOVE IN THE DARK! "
	fcb 0
brokeneck:
	fcc "YOU FELL DOWN AND BROKE YOUR NECK. "
	fcb 0
cantgo:
	fcc "YOU CAN'T GO IN THAT DIRECTION. "
	fcb 0
dontunderstand:
	fcc  "I DON'T UNDERSTAND YOUR COMMAND. "
	fcb 0
notyet:
	fcc "YOU CAN'T DO THAT YET. "
	fcb 0
beyondpower:
	fcc "IT IS BEYOND YOUR POWER TO DO THAT. "
	fcb 0
okmsg:
	fcc "O.K. "
	fcb 0
whatstr:
	fcc "WHAT ? "
	fcb 0
itsdark:
	fcc "YOU CAN'T SEE. IT IS TOO DARK!"
	fcb 10
	fcb 0
youare:
	fcc "YOU ARE "
	fcb 0
nonestr:
	fcc "NONE"
	fcb 0
obexit:
	fcb 10
	fcc "OBVIOUS EXITS: "
	fcb 0
canalsosee:
	fcc "YOU CAN ALSO SEE: "
	fcb 0
invcond:
	fcc "INVCOND"
	fcb 0
exit_n:
	fcc "NORTH"
	fcb 0
exit_e:
	fcc "EAST"
	fcb 0
exit_s:
	fcc "SOUTH"
	fcb 0
exit_w:
	fcc "WEST"
	fcb 0
exit_u:
	fcc "UP"
	fcb 0
exit_d:
	fcc "DOWN"
	fcb 0

exitmsgptr:
	fdb exit_n
	fdb exit_e
	fdb exit_s
	fdb exit_w
	fdb exit_u
	fdb exit_d
redraw:			; Top display is dirty
	fcb 0


wordflush:
;
;	Action 71: Save the game position
;
act71:
	rts

;
;	Action Table
;
actab:
	fdb act52
	fdb act53
	fdb act54
	fdb act55
	fdb act56
	fdb act57
	fdb act58
	fdb act59
	fdb act60
	fdb act61
	fdb act62
	fdb act63
	fdb act64
	fdb act65
	fdb act66
	fdb act67
	fdb act68
	fdb act69
	fdb act70
	fdb act71
	fdb act72
	fdb act73
	fdb act74
	fdb act75
	fdb act76
	fdb act77
	fdb act78
	fdb act79
	fdb act80
	fdb act81
	fdb act82
	fdb act83
	fdb act84
	fdb act85
	fdb act86
	fdb act87
	fdb act88
	fdb act89

;
;	Game specific code
;
;
;	Pick right routine for word size. This one does 4 chars
;	Check wordbuf matches our word. Both are zero padded for simplicity
;
wordeq:
	pshx
	ldd ,x
	anda #0x7f
	cmpa wordbuf
	bne notmatch
	cmpb wordbuf+1
	bne notmatch
	inx
	inx
	ldd 2,x
	cmpa wordbuf+2
	bne notmatch
	cmpb wordbuf+3
notmatch:
	pulx
	rts

;
;	Engine temporaries
;
verb:
	fcb 0
noun:
	fcb 0
tmp8:
	fcb 0
tmp8_2:
	fcb 0
tmp16:
	fdb 0
linematch:
	fcb 0
actmatch:
	fcb 0
condacts:
	fcb 0		; condact header byte for this line
argh:
	fcb 0		; argh high byte for last
argp:
	fdb 0
args:
	zmb 10			; max 5 parameters

continuation:
	fcb 0

	zmb 256			; overkill
stacktop:
;
;	Game Block: FIXME - restore these on a restart
;
wordsize:
	fcb 4
lighttime:
	fcb 255
lightfill:
	fcb 0
location:
	fcb 0
carried:
	fcb 0		; FIXME - needs to be set to initial carried items
maxcar:
	fcb 5		; varies by game
treasure:
	fcb 0		; treasure room - varies by game
treasures:
	fcb 0		; varies by game - num treasures
startloc:
	fcb 0
lastloc:
	fcb 0
objloc:			; Object locations
	zmb NUM_OBJ
objloc_end:

;
;	Between here and zeroblock_end is wiped each new game
;
zeroblock:

roomsave:
	zmb 12		; Seem to be sufficient (6 room saves)
savedroom:
	fcb 0		; single flag for this type
bitflags:
	zmb NUM_BITS
counter:
	fdb 0
counter_array
	zmb 32		; 16 counters

zeroblock_end:

locdata:
objinit:
objinit_end:
actions:
status:
msgptr:
objtext:
verbs:
nouns:


zzz: