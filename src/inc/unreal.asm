; ----------------------------------------------------------------------
; Переход в Unreal Mode
; @url https://wiki.osdev.org/Unreal_Mode
; Учесть смещение в памяти CS $800
; ----------------------------------------------------------------------
gdtinfo:    dw  gdt_end - gdt - 1   ; last byte in table
            dd  gdt                 ; start of table
gdt:        dd  0,0
flatdesc:   db  0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
gdt_end:
; ----------------------------------------------------------------------
unreal_enter:
; ----------------------------------------------------------------------

        push    ds es ss

        ; Переход в защищенный режим
        lgdt    [gdtinfo]
        mov     eax, cr0
        or      al, 1
        mov     cr0, eax
        jmp     $+2

        ; Выбор дескриптора с лимитами
        mov     bx, 8
        mov     ds, bx
        mov     es, bx
        mov     ss, bx

        ; Возврат в реальный режим
        and     al, 0xFE
        mov     cr0, eax
        pop     ss es ds
        ret
