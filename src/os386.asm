
        macro   brk { xchg bx, bx }
        org     8000h

        cli
        cld      

        ; Первичная инициализация
        call    unreal_enter
        call    pic_reinit
        call    ps2_init
        call    start_vga
        mov     al, 3
        call    vga_cls

        jmp     $

; ----------------------------------------------------------------------
include "inc/unreal.asm"
include "inc/pic.asm"
include "inc/ps2.asm"
include "inc/vga.asm"
; ----------------------------------------------------------------------
