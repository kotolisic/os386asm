; ----------------------------------------------------------------------
PIC1                            equ 0x20   ; IO базовый адрес для master PIC */
PIC2                            equ 0xA0   ; IO базовый адрес для slave PIC */
PIC1_COMMAND                    equ PIC1
PIC1_DATA                       equ (PIC1+1)
PIC2_COMMAND                    equ PIC2
PIC2_DATA                       equ (PIC2+1)
PIC_EOI                         equ 0x20   ; End-of-interrupt command code */
ICW1_ICW4                       equ 0x01   ; ICW4 (not) needed */
ICW1_SINGLE                     equ 0x02   ; Single (cascade) mode */
ICW1_INTERVAL4                  equ 0x04   ; Call address interval 4 (8) */
ICW1_LEVEL                      equ 0x08   ; Level triggered (edge) mode */
ICW1_INIT                       equ 0x10   ; Initialization - required! */
ICW4_8086                       equ 0x01   ; 8086/88 (MCS-80/85) mode */
ICW4_AUTO                       equ 0x02   ; Auto (normal) EOI */
ICW4_BUF_SLAVE                  equ 0x08   ; Buffered mode/slave */
ICW4_BUF_MASTER                 equ 0x0C   ; Buffered mode/master */
ICW4_SFNM                       equ 0x10   ; Special fully nested (not) */

; PIC1
IRQ_TIMER                       equ 0x01
IRQ_KEYB                        equ 0x02
IRQ_CASCADE                     equ 0x04
IRQ_FDC                         equ 0x40

; PIC2
IRQ_PS2                         equ 0x10

; ----------------------------------------------------------------------
pic_reinit:         ; 08-0Fh 70-77h
; ----------------------------------------------------------------------

        ; Отключение APIC
        mov     ecx, 0x1b
        rdmsr
        and     ax, 0xf7ff
        wrmsr

@@:     ; Выполнение запросов
        mov     cx, 10
        xor     dx, dx
        mov     si, .data
@@:     lodsw
        mov     dl, al
        mov     al, ah
        out     dx, al
        jcxz    $+2
        jcxz    $+2
        loop    @b

        ; Выставление векторов прерываний
        mov     si, .irq
        xor     eax, eax
@@:     lodsw
        cmp     al, 0xFF
        je      @f
        mov     di, ax
        shl     di, 2
        lodsw
        stosd
        loop    @b
@@:
        ; Часы на 100 гц
        mov     al, $34
        out     $43, al
        mov     al, $9b
        out     $40, al
        mov     al, $2e
        out     $40, al
        ret

.data:  ; Данные для отправки команд
        db      PIC1_COMMAND, ICW1_INIT + ICW1_ICW4
        db      PIC2_COMMAND, ICW1_INIT + ICW1_ICW4
        db      PIC1_DATA,    0x08 ; IRQ 0-7
        db      PIC2_DATA,    0x70 ; IRQ 8-F
        db      PIC1_DATA,    0x04
        db      PIC2_DATA,    0x02
        db      PIC1_DATA,    ICW4_8086
        db      PIC2_DATA,    ICW4_8086
        db      PIC1_DATA,    0xFF xor (IRQ_TIMER or IRQ_CASCADE or IRQ_KEYB)
        db      PIC2_DATA,    0xFF xor (IRQ_PS2)

; Таблица прерываний
; https://matrix.home.xs4all.nl/system/ivt.html
.irq:   dw      0x08, irq_timer     ; IRQ 0
        dw      0x09, irq_keyb      ; IRQ 1
        dw      0x74, irq_ps2       ; IRQ 12
        dw      0xFF

; ----------------------------------------------------------------------
; Обработчик таймера и задач, если они есть
; ----------------------------------------------------------------------

irq_timer:

        pusha
        ; ..
        mov     al, $20
        out     PIC1, al
        popa
        iret

; ----------------------------------------------------------------------
; Обработчик нажатия клавиш
; ----------------------------------------------------------------------

irq_keyb:

        pusha
        in      al, $60
        ; Какая клавиша нажата?
        mov     al, $20
        out     PIC1, al
        popa
        iret

