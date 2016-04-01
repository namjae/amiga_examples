	include "includes.i"

	xdef BlitChar8

DESCENDING		equ 1
BLIT_LF_MINTERM		equ $ca		; cookie cut
BLIT_WIDTH_WORDS	equ 1		; blit 2 words to allow shifting
BLIT_WIDTH_BYTES	equ BLIT_WIDTH_WORDS*2
FONTMAP_WIDTH_BYTES	equ 32

	if MASKED_FONT==1
BLTCON0_VALUE		equ BLIT_SRCA|BLIT_SRCB|BLIT_SRCC|BLIT_DEST|BLIT_LF_MINTERM
	else
BLTCON0_VALUE		equ BLIT_SRCB|BLIT_SRCC|BLIT_DEST|BLIT_LF_MINTERM
	endif
	
BlitChar8:
	;; a0 - bitplane
	;; d0 - xpos
	;; d1 - ypos	
	;; d2 - char
	movem.l	d0-d7/a0-a4,-(sp)
	WaitBlitter

	;; blitter config that is shared for every character
	if MASKED_FONT==1
	move.w 	#FONTMAP_WIDTH_BYTES-BLIT_WIDTH_BYTES,BLTAMOD(a6)	; A modulo (only used for masked version)
	endif
	move.w 	#FONTMAP_WIDTH_BYTES-BLIT_WIDTH_BYTES,BLTBMOD(a6)	; B modulo
	move.w 	#BITPLANE_WIDTH_BYTES-BLIT_WIDTH_BYTES,BLTCMOD(a6)	; C modulo
	move.w 	#BITPLANE_WIDTH_BYTES-BLIT_WIDTH_BYTES,BLTDMOD(a6)	; D modulo
        mulu.w	#BITPLANE_WIDTH_BYTES*SCREEN_BIT_DEPTH,d1		; ypos bytes
	move.w	#$ffff,BLTAFWM(a6) 					; don't mask first word
	move.l	#font,a1						; font pointer
	move.l	#fontMask,d7						; font mask pointer
	move.w	#FONTMAP_WIDTH_BYTES*SCREEN_BIT_DEPTH*FONT_HEIGHT,d3 	; bytes per font line

	move.l	a0,a4		; bitplane pointer
	bsr	DrawChar8	; draw it

	movem.l	(sp)+,d0-d7/a0-a4
	rts

DrawChar8:
	;; kills d2,d4,d5,a1,a2,a4
	;; d0  - xpos
	;; d1  - ypos bytes
	;; d2* - char
	;; d3  - bytes per font line
	;; a4* - bitplane
	;; a1  - #font
	;; d7  - #fontMask

	sub.w	#'!',d2		; index = char - '!'
	move.w	d2,d5
	
	lsr.w	#5,d5		; char / 32 = fontmap line
	andi.w	#$1f,d2		; char index in line (char index - start of line index)
	
	add.l	#1,d5		; while we have a weird font image, '!' starts on second line

	mulu.w	d3,d5 		; d5 *= #FONTMAP_WIDTH_BYTES*SCREEN_BIT_DEPTH*FONT_HEIGHT

	if	MASKED_FONT==1
	move.l	d7,a2		; #fontMask
	add.w	d5,a2		; add y offset in lines to fontMask address
	endif

	add.w	d5,a1		; add y offset in lines to font address

	add.w	d2,a1		; add offset into font
	if MASKED_FONT==1
	add.l	d2,a2		; add offset into mask
	endif

.blitChar8:

	add.l	#(FONT_HEIGHT*SCREEN_BIT_DEPTH*FONTMAP_WIDTH_BYTES)-FONTMAP_WIDTH_BYTES+0,a1
	add.l	#(FONT_HEIGHT*SCREEN_BIT_DEPTH*FONTMAP_WIDTH_BYTES)-FONTMAP_WIDTH_BYTES+0,a2
		
	
 	move.l	d0,d4					; xpos
	lsr.w	#3,d4					; d4 = xpos bytes
	
	btst	#0,d2					; check if odd or even char
	beq	.evenChar				;
.oddChar:
	move.w	#$00ff,BLTALWM(a6)			; select the second (odd) character in the word
	move.w	#BLTCON0_VALUE|$8000,BLTCON0(a6)
	move.w	#$8002,BLTCON1(a6)			; set the shift bits 12-15, bits 00-11 cleared
	bra	.continue
.evenChar:
	move.w	#$FF00,BLTALWM(a6)			; select the first character in the word
	move.w	#BLTCON0_VALUE,BLTCON0(a6)	
	move.w	#$2,BLTCON1(a6)				; set the shift bits 12-15, bits 00-11 cleared
.continue:

	
	if MASKED_FONT==1
	move.l 	a2,BLTAPTH(a6)				; mask bitplane
	endif

	move.l 	a1,BLTBPTH(a6)				; source bitplane		

	add.l 	d4,a4					; dest += XPOS_BYTES
	add.l	d1,a4					; dest += YPOS_BYTES

	add.l	#(FONT_HEIGHT*SCREEN_BIT_DEPTH*BITPLANE_WIDTH_BYTES)-BITPLANE_WIDTH_BYTES+0,a4
	
	move.l 	a4,BLTCPTH(a6) 				; background top left corner
	move.l 	a4,BLTDPTH(a6) 				; destination top left corner

	move.w 	#(FONT_HEIGHT*SCREEN_BIT_DEPTH)<<6|(BLIT_WIDTH_WORDS),BLTSIZE(a6)	;rectangle size, starts blit
	rts

font:
	incbin	"out/font8x8.bin"
fontMask:
	incbin	"out/font8x8-mask.bin"
