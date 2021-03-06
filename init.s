        XREF __initial_sp
        XREF __bss_beg, __bss_end
        XREF __data_beg, __data_end
        XREF __rom_data
        XREF _kmain
        XREF _level3_interrupt_handler
        XDEF _memcpy ; GCC emits calls to memcpy, provide it here

        section init,code

custom=$dff000
dmacon=$096
intena=$09a
intreq=$09c
bplcon0=$100
bpl1dat=$110
color=$180

ciaa=$bfe001
pra=$000
ddra=$200

        ; The ROM is located at $fc0000 (for a 256K ROM) but is
        ; mapped at $000000 after reset shadowing RAM.
rom_start:
        dc.l    __initial_sp    ; Initial SP
        dc.l    rom_code        ; Initial PC
rom_code:
        move.b  #3, ciaa+ddra   ; Set port A direction to output
        move.b  #0, ciaa+pra    ; Disable OVL (Memory from $0 onwards available)

        ; Make sure DMA and interrupts are disabled in the custom chips
        move.w  #$7fff, d0
        lea     custom, a6
        move.w  d0, intena(a6)
        move.w  d0, intreq(a6)
        move.w  d0, dmacon(a6)

        ;
        ; Clear BSS
        ;
        move.l  #__bss_beg, a0
        move.l  #__bss_end, d0
        sub.l   a0, d0
        lsr.l   #4, d0
        moveq   #0, d1
        bra.s   .cbl
.clearbss:
        move.l  d1, (a0)+
        move.l  d1, (a0)+
        move.l  d1, (a0)+
        move.l  d1, (a0)+
.cbl:
        dbf     d0, .clearbss

        ;
        ; Copy data segment(s)
        ;
        move.l  #__data_beg, a0
        move.l  #__rom_data, a1
        move.l  #__data_end, d0
        sub.l   a0, d0
        lsr.l   #4, d0
        bra.s   .cdl
.copydata:
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
        move.l  (a1)+, (a0)+
.cdl:
        dbf     d0, .copydata

        ;
        ; Setup exception vectors
        ;
        sub.l   a0, a0
        move.l  #unhandled_exception, d0
        move.w  #256-1, d1
.setupvecs:
        move.l  d0, (a0)+
        dbf     d1, .setupvecs

        ; Level 3 interrupt (for VBLANK)
        move.l  #level3_interrupt, $6c.w

        ; Lower IPL to allow interrupts
        move.w  #$2000, sr

        ;
        ; Off we go
        ;
        jmp     _kmain

        ; assumes -mregparm=2
        ; input:  a0 = destination, a1 = source, d0 = number of bytes
        ; output: d0 = destination
_memcpy:
        move.l  a0, d1
        exg     d0, d1
        bra.s   .loop
.copy:  move.b  (a1)+, (a0)+
.loop:  dbf     d1, .copy
        rts

unhandled_exception:
        ; Put up red screen and stop
        move.w  #$7fff, intena+custom
        move.w  #$7fff, intreq+custom
        move.w  #$7fff, dmacon+custom
        move.w  #$ffff, bpl1dat+custom
        move.w  #$0200, bplcon0+custom
        move.w  #$0f00, color+custom
        stop    #$2700
        bra.s   unhandled_exception

level3_interrupt:
        movem.l d0-d1/a0-a1, -(a7)
        jsr     _level3_interrupt_handler
        movem.l (a7)+, d0-d1/a0-a1
        rte

        section vectors,data
        dc.w  $18,$19,$1a,$1b,$1c,$1d,$1e,$1f
