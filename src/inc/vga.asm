
; Регистры
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
vga_start:      ; Инициализация VGA. 8 цветов DAC
; ----------------------------------------------------------------------

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
        out     dx, al  ; DX = 8 - CX
        inc     dx
        lodsb           ; RED
        shr     al, 2
        out     dx, al
        lodsb           ; GREEN
        shr     al, 2
        out     dx, al
        lodsb           ; BLUE
        shr     al, 2
        out     dx, al
        loop    .pal

        ; Включение режима записи в память
        mov     dx, VGA_GC_INDEX
        mov     ax, 0x0205
        out     dx, ax
        ret

; ----------------------------------------------------------------------
vga_cls:        ; Учистка в хлам монитора телевизора. AL-цвет
; ----------------------------------------------------------------------

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

        ; Очистить в кеше
        mov     edi, [vesa.cache]
        mov     ecx, 640*480
@@:     mov     [edi], al
        inc     edi
        dec     ecx
        jne     @b
        ret

; ----------------------------------------------------------------------
; Рисовать точку
; ----------------------------------------------------------------------
; ARG0 (x) ARG1 (y) ARG2 (cl)
; ----------------------------------------------------------------------
pset:   intro   0

        ; Поставить точку в кеше
        movzx   ebx, word ARG1
        movzx   eax, word ARG0
        imul    edi, ebx, 640
        add     edi, eax
        add     edi, [vesa.cache]
        mov     al, ARG2
        mov     [edi], al

        ; outw(VGA_GC_INDEX, (0x100 >> (x & 7)) << 8 | 0x08);
        xor     edi, edi
        mov     ax, $8008
        mov     cl, ARG0
        and     cl, 7
        shr     ah, cl
        mov     dx, VGA_GC_INDEX
        out     dx, ax

        ; di = y*80 + (x>>3)
        imul    di, ARG1, 80
        mov     ax, ARG0
        shr     ax, 3
        add     di, ax
        add     edi, 0xA0000

        ; Расчет попадания точки в область мыши
        mov     dl, ARG2        ; Исходный цвет
        and     dl, 0x0F
        mov     ax, [mouse.x]
        cmp     ARG0, ax
        jb      .set            ; x < mouse.x
        add     ax, 11
        cmp     ARG0, ax
        jnb     .set            ; x >= mouse.x + 11
        mov     ax, [mouse.y]
        cmp     ARG1, ax
        jb      .set            ; y < mouse.y
        add     ax, 19
        cmp     ARG1, ax
        jnb     .set            ; y >= mouse.y + 19

        ; Вычисление цвета в зависимости от мыши
        mov     bx, ARG1
        sub     bx, [mouse.y]   ; bx = 4*(y - mouse.y)
        shl     bx, 2

        ; dx=0 -> 30, 1 -> 28, ...
        mov     cx, ARG0
        sub     cx, [mouse.x]   ; ax = x - mouse.x
        shl     cx, 1
        sub     cx, 30
        neg     cx              ; cx = 30 - 2*ax

        ; Получение цвета 2 бит
        mov     eax, [mouse_sprite_data + bx]
        shr     eax, cl
        and     al, 3
        je      .set            ; Цвет не заменяется
        mov     dl, VGA_WHITE   ; =1
        cmp     al, 1
        je      .set
        mov     dl, VGA_BLACK   ; =3
        cmp     al, 3
        je      .set
        mov     dl, VGA_DARKGRAY; =2
.set:   mov     ah, [edi]       ; Установить точку на экране
        mov     [edi], dl
        outro
        ret

; ----------------------------------------------------------------------
; Обновление блока. Этот метод просто берет и обновляет блок, чтобы
; были возможны непрерывные перемещения мышью
; ----------------------------------------------------------------------
; ARG0 (x1) ARG1(y1)
; ARG2 (x2) ARG2(y2)
; ----------------------------------------------------------------------

vga_block_update:

        intro   0
        mov     bx, word ARG1
.y:     mov     ax, word ARG0
.x:     and     eax, $FFFF
        and     ebx, $FFFF
        imul    edi, ebx, 640
        add     edi, eax
        add     edi, [vesa.cache]
        push    ax bx
        invoke  pset, ax, bx, [edi]    ; Записать его же
        pop     bx ax
        inc     ax
        cmp     ax, 640             ; Если вышел за пределы X
        je      @f
        cmp     ax, ARG2
        jbe     .x
@@:     inc     bx
        cmp     bx, 480             ; Вышел за пределы Y
        je      @f
        cmp     bx, ARG3
        jbe     .y
@@:     outro
        ret

; ----------------------------------------------------------------------
; Рисование блока определенного цвета
; ----------------------------------------------------------------------
; ARG0 (x1) ARG1 (y1) ARG2 (x2) ARG3 (y2) ARG4 (cl)
; ----------------------------------------------------------------------
vga_block:

        intro   0
        mov     cx, ARG1
.y:     mov     bx, ARG0
.x:     push    bx cx
        invoke  pset, bx, cx, ARG4
        pop     cx bx
        inc     bx
        cmp     bx, 640
        je      @f
        cmp     bx, ARG2
        jbe     .x
@@:     inc     cx
        cmp     cx, 480
        je      @f
        cmp     cx, ARG3
        jbe     .y
@@:     outro
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

