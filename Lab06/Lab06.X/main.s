; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Stefano Papadopolo
; Compilador: pic-as (v2.32) [C:\Program Files\Microchip\xc8\v2.31\pic-as\bin]
;
; Programa: Lab06 - Timer1 y Timer2
; Hardware: 12 Leds, 8 displays de 7 segmentos y 3 push-buttons
;
; Creado 23 mar, 2021
; Última Actualización: 23 mar, 2021

PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = ON            ; Brown Out Reset Selection bits (BOR enabled)
  CONFIG  IESO = ON             ; Internal External Switchover bit (Internal/External Switchover mode is enabled)
  CONFIG  FCMEN = ON            ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is enabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

;|----------------------------------------------------------------------------|
;|-------------------------------VARIABLES------------------------------------|
;|----------------------------------------------------------------------------|
GLOBAL w_temp, status_temp, banderas, counter_delay_var, blinking_delay_var
GLOBAL counter, high_hex, low_hex
PSECT udata_shr
;banderas de interrupciones
w_temp:
    DS	1
status_temp:
    DS	1
banderas:
    DS	1
high_hex_flag	EQU 0
low_hex_flag	EQU 1
on_off		EQU 2
counter_delay_var:
    DS	1
blinking_delay_var:
    DS	1
;banderas de programa
counter:
    DS	1
high_hex:
    DS	1
low_hex:
    DS	1
;|----------------------------------------------------------------------------|
;|---------------------------------MACROS-------------------------------------|
;|----------------------------------------------------------------------------|
reset_timer0	macro
    banksel TMR0
    bcf	    INTCON, 2
    movlw   8		    //valor inicial calculado para 250 us
    movwf   TMR0
    banksel OPTION_REG
    movlw   0b11010010	    //Multiplicar por 16 para 2ms
    andwf   OPTION_REG
    endm

reset_timer1	macro
    banksel TMR1H
    bcf	    PIR1, 0
    movlw   0b10000101
    movwf   TMR1H
    movlw   0b11101110
    movwf   TMR1L
    movlw   0b00110001	    ;1:8 prescaler, TMR1 on, and osc is Tosc/4
    movwf   T1CON
    endm

reset_timer2	macro
    banksel TMR2
    bcf	    PIR1, 1
    movlw   0
    movwf   TMR2
    movlw   0b00111100	    //1:8 postscaler
    movwf   T2CON
    endm
    
;|----------------------------------------------------------------------------|
;|----------------------------------CODE--------------------------------------|
;|----------------------------------------------------------------------------|
PSECT resVect, class=CODE, delta=2
    ;linker: -PresVect=0x0000
    goto main
    
PSECT intVect, class=CODE, delta=2
    ;linker: -PintVect=0x0004

push:
    movwf   w_temp
    banksel STATUS
    swapf   STATUS, w
    movwf   status_temp
    
interrupt_select:
    banksel PIR1
    btfsc   INTCON, 2	    ;Flag for TMR0
    goto    sev_seg_mux
    btfsc   PIR1, 0	    ;Flag for TMR1
    goto    counter_delay_int
    btfsc   PIR1, 1	    ;Flag for TMR2
    goto    blinking_delay_int
    
    goto    pop


sev_seg_mux:
    reset_timer0
    banksel PORTD
    btfsc   PORTD,  high_hex_flag
    bsf	    banderas, low_hex_flag
    btfsc   PORTD,  low_hex_flag
    bsf	    banderas, high_hex_flag
    goto    interrupt_select

counter_delay_int:
    reset_timer1
    decf    counter_delay_var
    goto    interrupt_select

blinking_delay_int:
    bcf	    PIR1, 1
    decf    blinking_delay_var
    goto    interrupt_select
    
pop:
    banksel STATUS
    swapf   status_temp, w
    movf    STATUS
    swapf   w_temp, f
    swapf   w_temp, w
    retfie

PSECT loopPrincipal, class=CODE, delta=2

table:
    addwf   PCL, F
    retlw   0b00111111	;show 0
    retlw   0b00000110	;show 1
    retlw   0b01011011	;show 2
    retlw   0b01001111	;show 3
    retlw   0b01100110	;show 4
    retlw   0b01101101	;show 5
    retlw   0b01111101	;show 6
    retlw   0b00000111	;show 7
    retlw   0b01111111	;show 8
    retlw   0b01100111	;show 9
    retlw   0b01110111	;show A
    retlw   0b01111100	;show B
    retlw   0b00111001	;show C
    retlw   0b01011110	;show D
    retlw   0b01111001	;show E
    retlw   0b01110001	;show F
    retlw   0b00000000	;show off

;configuración
main:
    call port_config
    call inicializar_variables
    reset_timer0
    reset_timer1
    reset_timer2
    call interrupt_config
    banksel PORTA
loop:
    movf    counter_delay_var,	0
    btfsc   STATUS, 2
    call    inc_counter
    movf    blinking_delay_var,	0
    btfsc   STATUS, 2
    call    blink
    
    ;Display
    btfsc   banderas,  high_hex_flag
    call    disp_high_hex
    btfsc   banderas,  low_hex_flag
    call    disp_low_hex
    
    goto loop
;|----------------------------------------------------------------------------|
;|------------------------------SUB-RUTINAS-----------------------------------|
;|----------------------------------------------------------------------------|
    
port_config:
    banksel ANSEL	;Todo es digital
    clrf    ANSEL
    clrf    ANSELH
    
    banksel TRISA	;Configurar outputs
    movlw   0b00000000
    movwf   TRISC
    movwf   TRISD
    bcf	    TRISE, 0
    
    banksel PORTA	;Inicializar todos los puertos en 0
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    return
    
inicializar_variables:
    banksel PR2
    movlw   250		;Compare value of TMR2
    movwf   PR2
    movlw   125		;Delay for tmr2 to blink every 250ms
    movwf   blinking_delay_var
    movlw   4		;Delay for tmr1 to increase a variable every second
    movwf   counter_delay_var
    banksel PORTD
    movlw   0
    movwf   counter
    movwf   high_hex
    movwf   low_hex
    movwf   banderas
    bsf	    PORTD, high_hex_flag	;Starting point for mux
    bsf	    banderas, on_off;Starting point for blink
    
    return
    
interrupt_config:
    banksel PIE1
    bsf	    INTCON, 7	;General Int Enable
    bsf	    INTCON, 6	;Peripheral (timer1 y timer2) interrupt enable
    bsf	    INTCON, 5	;Tmr0 Int Enable
    bsf	    PIE1,   0	;Tmr1 Int Enable
    bsf	    PIE1,   1	;TMR2 int Enable
    return

inc_counter:
    incf    counter
    movlw   4
    movwf   counter_delay_var
    return
blink:
    btfsc   banderas, on_off
    goto    turn_on
    btfss   banderas, on_off
    goto    turn_off
    return

turn_on:
    bsf	    PORTE,  0
    call    separate_hex
    movlw   125
    movwf   blinking_delay_var
    bcf	    banderas, on_off
    return
turn_off:
    bcf	    PORTE,  0
    movlw   16
    movwf   high_hex
    movwf   low_hex
    movlw   125
    movwf   blinking_delay_var
    bsf	    banderas, on_off
    return
    
separate_hex:
    movf    counter, 0
    andlw   0x0F
    movwf   low_hex
    swapf   counter, 0
    andlw   0x0F
    movwf   high_hex
    return

disp_high_hex:
    banksel PORTD
    bcf	    PORTD, low_hex_flag
    bsf	    PORTD, high_hex_flag
    movf    high_hex, 0
    call    table
    movwf   PORTC
    bcf	    banderas, high_hex_flag
    return
    
disp_low_hex:
    banksel PORTD
    bcf	    PORTD, high_hex_flag
    bsf	    PORTD, low_hex_flag
    movf    low_hex, 0
    call    table
    movwf   PORTC
    bcf	    banderas, low_hex_flag
    return