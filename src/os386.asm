
        macro   brk { xchg bx, bx }
        org     8000h

        cli
        cld

        ; Первичная инициализация
        call    unreal_enter
        call    pic_reinit
brk        


        jmp     $

include "inc/unreal.asm"
include "inc/pic.asm"
include "inc/ps2.asm"
