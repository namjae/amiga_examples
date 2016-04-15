	include "includes.i"

	xdef SwitchBuffers
	
SwitchBuffers:
	;; offscreen - bitplane address

	move.l	foregroundScrollX,d0
	lsr.l   #3,d0		; bytes to scroll
	move.l	foregroundOffscreen,a0
	move.l	foregroundOnscreen,foregroundOffscreen
	move.l	a0,foregroundOnscreen
	move.l	a0,a1
	lea 	copperListBpl1Ptr,a0
	jsr	PokeBitplanePointers

	;; background is not double buffered
	move.l	backgroundScrollX,d0
	lsr.l   #3,d0		; bytes to scroll		
	move.l	backgroundOnscreen,a1
	lea 	copperListBpl2Ptr,a0
	jsr	PokeBitplanePointers

	rts

PokeBitplanePointers:
	; d0 = frame offset in bytes
	; a0 = BPLP copper list address
	; a1 = bitplanes pointer
	;; 	movem.l	d0-a6,-(sp)
	add.l	d0,a1 ; bitplane offset
	moveq	#SCREEN_BIT_DEPTH-1,d0
.bitplaneloop:
	move.l 	a1,d1
	move.w	d1,2(a0)
	swap	d1
	move.w  d1,6(a0)
	lea	BITPLANE_WIDTH_BYTES(a1),a1
	addq	#8,a0
	dbra	d0,.bitplaneloop
	;; 	movem.l (sp)+,d0-a6
	rts

	

	
