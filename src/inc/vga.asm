; Регистры VGA
VGA_AC_INDEX        equ 0x3C0
VGA_AC_WRITE        equ 0x3C0
VGA_AC_READ         equ 0x3C1
VGA_MISC_WRITE      equ 0x3C2
VGA_SEQ_INDEX       equ 0x3C4
VGA_SEQ_DATA        equ 0x3C5
VGA_DAC_READ_INDEX  equ 0x3C7
VGA_DAC_WRITE_INDEX equ 0x3C8
VGA_DAC_DATA        equ 0x3C9
VGA_MISC_READ       equ 0x3CC
VGA_GC_INDEX        equ 0x3CE
VGA_GC_DATA         equ 0x3CF

;                           COLOR emulation   MONO
VGA_CRTC_INDEX      equ 0x3D4       ; 0x3B4 */
VGA_CRTC_DATA       equ 0x3D5       ; 0x3B5 */
VGA_INSTAT_READ     equ 0x3DA

VGA_NUM_SEQ_REGS    equ 5
VGA_NUM_CRTC_REGS   equ 25
VGA_NUM_GC_REGS     equ 9
VGA_NUM_AC_REGS     equ 21
VGA_NUM_REGS        equ (1 + VGA_NUM_SEQ_REGS + VGA_NUM_CRTC_REGS + VGA_NUM_GC_REGS + VGA_NUM_AC_REGS)
; ----------------------------------------------------------------------

vga_palette:
; ----------------------------------------------------------------------

    db 0x00, 0x00, 0x00 ; 0 Black
    db 0x00, 0x00, 0x80 ; 1 Blue
    db 0x00, 0x80, 0x00 ; 2 Green
    db 0x00, 0x80, 0x80 ; 3 Cyan
    db 0x80, 0x00, 0x00 ; 4 Red
    db 0x80, 0x00, 0x80 ; 5 Magenta
    db 0x80, 0x80, 0x00 ; 6 Brown
    db 0xCC, 0xCC, 0xCC ; 7 Gray

; ----------------------------------------------------------------------
; Инициализация VGA. 8 цветов DAC
; ----------------------------------------------------------------------

start_vga:

        ; Установка драйвера VGA
        mov     ax, $0012
        int     10h

        ; Простановка палитры
        mov     cx, 8
        mov     si, vga_palette
.pal:   mov     dx, VGA_DAC_WRITE_INDEX
        mov     ax, cx
        dec     ax
        xor     ax, 0x07
        out     dx, al      ; DX = 8 - CX
        inc     dx
        lodsb               ; RED
        shr     al, 2
        out     dx, al
        lodsb               ; GREEN
        shr     al, 2
        out     dx, al
        lodsb               ; BLUE
        shr     al, 2
        out     dx, al
        loop    .pal

        ; Включение режима записи в память
        mov     dx, VGA_GC_INDEX
        mov     ax, 0x0205
        out     dx, ax
        ret

; ----------------------------------------------------------------------
; Учистка в хлам монитора телевизора. AL-цвет
; ----------------------------------------------------------------------
vga_cls:

        ; Очистить в цвет на экране
        xchg    ax, bx
        mov     dx, VGA_GC_INDEX
        mov     ax, 0xFF08          ; Пишется во все 8 битов
        out     dx, ax
        mov     cx, 80*480
        xchg    ax, bx
        mov     ebx, 0xA0000
@@:     mov     dl, [ebx]           ; Защелка
        mov     [ebx], al           ; Запись во все биты
        inc     ebx
        loop    @b
        ret

; ----------------------------------------------------------------------
; Рисовать точку (CL-цвет, BX-x, DX-y)
; ----------------------------------------------------------------------
_pset:  push    ax bx cx dx
        push    cx
        ; di = y*80 + (x>>3)
        mov     edi, $A0000
        imul    di, dx, 80
        mov     cx, bx
        shr     bx, 3
        add     di, bx

        ; outw(VGA_GC_INDEX, (0x100 >> (x & 7)) << 8 | 0x08);
        mov     ax, $8008
        and     cl, 7
        shr     ah, cl
        mov     dx, VGA_GC_INDEX
        out     dx, ax

        ; Запись точки на экране
        pop     cx
        mov     al, [edi]
        mov     [edi], cl

        pop     dx cx bx ax
        ret

; ----------------------------------------------------------------------
mouse_sprite_data:
; ----------------------------------------------------------------------

;   7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0  ;+0 1 2 3 4 5 6 7 8 9 10
dd 11000000000000000000000000000000b ; 3 - - - - - - - - - - 0
dd 11110000000000000000000000000000b ; 3 3 - - - - - - - - - 1
dd 11011100000000000000000000000000b ; 3 1 3 - - - - - - - - 2
dd 11010111000000000000000000000000b ; 3 1 1 3 - - - - - - - 3
dd 11010101110000000000000000000000b ; 3 1 1 1 3 - - - - - - 4
dd 11010101011100000000000000000000b ; 3 1 1 1 1 3 - - - - - 5
dd 11010101010111000000000000000000b ; 3 1 1 1 1 1 3 - - - - 6
dd 11010101010101110000000000000000b ; 3 1 1 1 1 1 1 3 - - - 7
dd 11010101010101011100000000000000b ; 3 1 1 1 1 1 1 1 3 - - 8
dd 11010101010101010111000000000000b ; 3 1 1 1 1 1 1 1 1 3 - 9
dd 11010101010111111111110000000000b ; 3 1 1 1 1 1 3 3 3 3 3 10
dd 11010111010111000000000000000000b ; 3 1 1 3 1 1 3 - - - - 11
dd 11011100110101110000000000000000b ; 3 1 3 - 3 1 1 3 - - - 12
dd 11110000110101110000000000000000b ; 3 3 - - 3 1 1 3 - - - 13
dd 11000000001101011100000000000000b ; 3 - - - - 3 1 1 3 - - 14
dd 00000000001101011100000000000000b ; - - - - - 3 1 1 3 - - 15
dd 00000000000011010111000000000000b ; - - - - - - 3 1 1 3 - 16
dd 00000000000011010111000000000000b ; - - - - - - 3 1 1 3 - 17
dd 00000000000000111100000000000000b ; - - - - - - - 3 3 - - 18
; 3-черный 1-белый

