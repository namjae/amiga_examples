	include "includes.i"
	
	xdef	copperList
	xdef	copperListBpl1Ptr
	xdef	copperListBpl2Ptr	
	xdef 	backgroundOnscreen
	xdef	backgroundOffscreen
	xdef	foregroundOnscreen
	xdef	foregroundOffscreen
	xdef	foregroundX
	xdef	backgroundX

byteMap:
	dc.l	Entry
	dc.l	endCode-byteMap

Entry:
	lea	userstack,a7
	lea 	CUSTOM,a6

	move	#$7ff,DMACON(a6)	; disable all dma
	move	#$7fff,INTENA(a6) 	; disable all interrupts		
	
	jsr	InstallPalette
	move.w	#$09e,COLOR00(a6)	
	move.w	#$09e,COLOR08(a6)

	
	lea	Level3InterruptHandler,a3
 	move.l	a3,LVL3_INT_VECTOR			

	;; d0 - fg bitplane pointer offset
	;; d1 - bg bitplane pointer offset
	move.l	#0,d0
	move.l	#0,d1
	jsr	SwitchBuffers		
	
	move.w	#(INTF_SETCLR|INTF_VERTB|INTF_INTEN),INTENA(a6)	
 	move.w	#(DMAF_BLITTER|DMAF_SETCLR!DMAF_MASTER),DMACON(a6) 		

	jsr	Init		  	; enable the playfield		

	
Reset:
	move.l	#0,foregroundX		; x pos 	
	move.l	#0,fg_shift		; shift counter
	move.l	#0,fg_tileIndex		; tile index
	move.l	#0,backgroundX
	move.l	#0,bg_shift		; shift counter
	move.l	#0,bg_tileIndex		; tile index	
	move.l	#BACKGROUND_UPDATE_COUNT,d6 (frame count)
	jsr 	BlueFill
	move.l	#0,frameCount		
	
MainLoop:
	move.l	frameCount,d6

	jsr	WaitVerticalBlank
	bsr.s	HoriScrollPlayfield

	bsr	RenderNextForegroundFrame
	bsr 	RenderNextBackgroundFrame	
	
	jsr 	SwitchBuffers	    ; takes bitplane pointer offset in d0

	bsr	RenderNextForegroundFrame	
	
	andi.b	#BACKGROUND_UPDATE_COUNT,d6
	bne	.skipBackgroundUpdates
	;; ---- Background updates ----------------------------------------
.backgroundUpdates:
	add.l	#1,backgroundX		
	add.l	#2,bg_tileIndex    	  ; increment tile index			
	bsr 	UpdateBackgroundShiftCounter	
.skipBackgroundUpdates:

	;; ---- Foreground updates ----------------------------------------	
.foregroundUpdates:
	add.l	#1,foregroundX
	add.l	#2,fg_tileIndex    	  ; increment foreground tile index	
	bsr	UpdateShiftCounter

	add.l	#1,frameCount
	bra	MainLoop

HoriScrollPlayfield:
	move.l	backgroundX,d0	
	move.w	d0,d2
	lsr.w   #3,d0		; bytes to scroll
	and.w   #$F,d2		; pixels = 0xf - (hpos - (hpos_bytes*8))
	move.w  #$F,d0
	sub.w   d2,d0		; bits to delay	
	move.w	d0,d5		; d5 == bg bits to delay

	move.l	foregroundX,d0
	move.w	d0,d2
	lsr.w   #3,d0		; bytes to scroll
	and.w   #$F,d2		; pixels = 0xf - (hpos - (hpos_bytes*8))
	move.w  #$F,d0
	sub.w   d2,d0		; bits to delay

	lsl.w	#4,d5
	or.w	d5,d0	
	move.w  d0,BPLCON1(a6)	
	rts


RenderNextBackgroundFrame:
	lea	backgroundMap,a2
	add.l	bg_tileIndex,a2
	bsr	RenderBackgroundTile	
.s1:
	rts


RenderNextForegroundFrame:
	lea	map,a2
	add.l	fg_tileIndex,a2
	cmp.w	#$FFFF,20(a2)
	bne	.skip
	bra	Reset
.skip:
	bsr	RenderForegroundTile
	rts


RenderForegroundTile:
	;; a2 - map
	move.l	foregroundX,d0
	lsr.w   #3,d0		; bytes to scroll
	move.l	foregroundOffscreen,a0
	add.l	d0,a0
	lea 	tilemap,a1	
	add.l	#BITPLANE_WIDTH_BYTES-2,a0 ; dest
	add.w	(a2),a1 	; source tile
	move.l	fg_shift,d2
	jsr	BlitTile
	rts


RenderBackgroundTile:	
	;; a2 - map
	move.l	backgroundX,d0
	lsr.w   #3,d0		; bytes to scroll
	move.l	backgroundOffscreen,a0
	add.l	d0,a0
	lea 	backgroundTilemap,a1	
	add.l	#BITPLANE_WIDTH_BYTES-2,a0 ; dest
	add.w	(a2),a1 	; source tile
	move.l	bg_shift,d2
	jsr	BlitTile
	rts	


UpdateShiftCounter:	
	cmp.l	#15,fg_shift	
	bne	.s1
	move.l	#0,fg_shift
	bra	.s2
.s1:
	add.l	#1,fg_shift
.s2:
	rts

UpdateBackgroundShiftCounter:	
	cmp.l	#15,bg_shift	
	bne	.s1
	move.l	#0,bg_shift
	bra	.s2
.s1:
	add.l	#1,bg_shift
.s2:
	rts	


Level3InterruptHandler:
	movem.l	d0-a6,-(sp)
	lea	CUSTOM,a6
.checkVerticalBlank:
	move.w	INTREQR(a6),d0
	and.w	#INTF_VERTB,d0	
	beq.s	.checkCopper

.verticalBlank:
	move.w	#INTF_VERTB,INTREQ(a6)	; clear interrupt bit	
.checkCopper:
	move.w	INTREQR(a6),d0
	and.w	#INTF_COPER,d0	
	beq.s	.interruptComplete
.copperInterrupt:
	move.w	#INTF_COPER,INTREQ(a6)	; clear interrupt bit	
	
.interruptComplete:
	movem.l	(sp)+,d0-a6
	rte	


copperList:
copperListBpl1Ptr:
	;; this is where bitplanes are assigned to playfields
	;; http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node0079.html
	;; 3 bitplanes per playfield, playfield1 gets bitplanes 1,3,5
	dc.w	BPL1PTL,0
	dc.w	BPL1PTH,0
	dc.w	BPL3PTL,0
	dc.w	BPL3PTH,0
	dc.w	BPL5PTL,0
	dc.w	BPL5PTH,0
copperListBpl2Ptr:
	;; 3 bitplanes per playfield, playfield2 gets bitplanes 2,4,6
	dc.w	BPL2PTL,0
	dc.w	BPL2PTH,0
	dc.w	BPL4PTL,0
	dc.w	BPL4PTH,0
	dc.w	BPL6PTL,0
	dc.w	BPL6PTH,0
	dc.l	$fffffffe	

	
InstallPalette:
	include	"out/tilemap-palette.s"
	rts

foregroundOnscreen:
	dc.l	foregroundBitplanes1
foregroundOffscreen:
	dc.l	foregroundBitplanes2

backgroundOnscreen:
	dc.l	backgroundBitplanes1
backgroundOffscreen:
	dc.l	backgroundBitplanes2	

tilemap:
	incbin "out/foreground.bin"

backgroundTilemap:
	incbin "out/background.bin"	
		
map:
	include "out/foreground-map.s"
	dc.w	$FFFF

backgroundMap:
	include "out/background-map.s"
	
fg_shift:
	dc.l	0
foregroundX:
	dc.l	0
fg_tileIndex:
	dc.l	0

bg_shift:
	dc.l	0
backgroundX:
	dc.l	0
bg_tileIndex:
	dc.l	0

frameCount:
	dc.l	0
	
	section .bss

foregroundBitplanes1:
	ds.b	IMAGESIZE
	ds.b	BITPLANE_WIDTH_BYTES*20
foregroundBitplanes2:
	ds.b	IMAGESIZE
	ds.b	BITPLANE_WIDTH_BYTES*20

backgroundBitplanes1:
	ds.b	IMAGESIZE
	ds.b	BITPLANE_WIDTH_BYTES*20
backgroundBitplanes2:
	ds.b	IMAGESIZE
	ds.b	BITPLANE_WIDTH_BYTES*20	

startUserstack:
	ds.b	$1000		; size of stack
userstack: