; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Stefano Papadopolo
; Compilador: pic-as (v2.32) [C:\Program Files\Microchip\xc8\v2.31\pic-as\bin]
;
; Programa: Interrupciones_y_pullups
; Hardware: Leds contador de 4 bits, 2 displays de 7 segmentos y push-buttons
;
; Creado 22 feb, 2021
; Última Actualización: 22 feb, 2021

PROCESSOR 16F887
#include <xc.inc>
    
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
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
GLOBAL w_temp, status_temp, banderas, counter, l_hex, h_hex, decena, centena, unidad
GLOBAL cent_left, dec_left, units_left  
  PSECT udata_shr
 ;variables de interrupciones
 w_temp:
    DS 1
status_temp:
    DS 1
banderas:
    DS 1
push_up_pressed	    EQU 0
push_down_pressed   EQU	1
high_hex_flag	    EQU 2
low_hex_flag	    EQU	3
unidad_flag	    EQU	4
decena_flag	    EQU	5
centena_flag	    EQU	6
	    

;variables de programa
h_hex:
    DS 1
l_hex:
    DS 1
cent_left:
    DS 1
centena:
    DS 1
decena:
    DS 1
dec_left:
    DS 1
unidad:
    DS 1
units_left:
    DS 1
counter:
    DS 1
;|----------------------------------------------------------------------------|
;|---------------------------------MACROS-------------------------------------|
;|----------------------------------------------------------------------------|

reset_timer0	macro
    banksel TMR0
    bcf	    INTCON, 2
    movlw   8		    //valor inicial calculado para 2 ms
    movwf   TMR0
    banksel OPTION_REG
    movlw   0b11010010
    andwf   OPTION_REG
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
isr:
    btfsc   PORTD, 0
    bsf	    banderas, low_hex_flag
    btfsc   PORTD, 1
    bsf	    banderas, centena_flag
    btfsc   PORTD, 2
    bsf	    banderas, decena_flag
    btfsc   PORTD, 3
    bsf	    banderas, unidad_flag
    btfsc   PORTD, 4
    bsf	    banderas, high_hex_flag
    reset_timer0
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
main:
    call    port_config
    
    banksel PORTD
    bsf	    PORTD, 0	//start 7-display
    
    movlw   0x00
    movwf   h_hex
    movwf   l_hex
    movwf   unidad
    movwf   units_left
    movwf   decena
    movwf   dec_left
    movwf   centena
    movwf   cent_left
    
    reset_timer0
    call    interrupt_config
    
    
    
loop:
    banksel PORTB
    btfss   PORTB,0
    bsf	    banderas, push_up_pressed
    btfsc   PORTB,0
    goto    Push0NotPressed
    goto    skip

Push0NotPressed:
    btfsc   banderas, push_up_pressed
    goto    increase
    goto    skip

increase:
    incf    counter,f
    bcf	    banderas, push_up_pressed

skip:
    btfss   PORTB,1
    bsf	    banderas, push_down_pressed
    btfsc   PORTB,1
    goto    Push1NotPressed
    goto    disp_bit_counter

Push1NotPressed:
    btfsc   banderas, push_down_pressed
    goto    decrease
    goto    disp_bit_counter

decrease:
    decf    counter, f
    bcf	    banderas, push_down_pressed

disp_bit_counter:
    movf    counter, 0
    movwf   PORTA
    
    call    config_hex_counter
    call    divide
    
    btfsc   banderas, high_hex_flag
    call    disp_high_hex
    btfsc   banderas, low_hex_flag
    call    disp_low_hex
    btfsc   banderas, centena_flag
    call    disp_centena
    btfsc   banderas, decena_flag
    call    disp_decena
    btfsc   banderas, unidad_flag
    call    disp_unidad
    
    goto    loop
  
;|----------------------------------------------------------------------------|
;|------------------------------SUB-RUTINAS-----------------------------------|
;|----------------------------------------------------------------------------|
    
port_config:
    
    banksel ANSEL	;Todo es digital
    clrf    ANSEL
    clrf    ANSELH
    
    banksel TRISA	;Configurar outputs
    movlw   0b00000000
    movwf   TRISA
    movwf   TRISC
    movwf   TRISD
	
    movlw   0b00000011	;Volver pines de PORTB inputs con sus pull-ups
    movwf   TRISB
    movlw   0b01111111
    andwf   OPTION_REG
    movlw   0b00000011
    movwf   WPUB
    
    banksel PORTA	;Inicializar todos los puertos en 0
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    return
    
interrupt_config:
    bsf	    INTCON, 7
    bsf	    INTCON, 5
    return

config_hex_counter:
    movf    counter, 0
    andlw   0x0F
    movwf   l_hex
    
    movf    counter, 0
    andlw   0xF0
    movwf   h_hex
    swapf   h_hex
    return
    
disp_high_hex:
    bcf	    PORTD, 4
    bsf	    PORTD, 0
    movf    h_hex, 0
    call    table
    movwf   PORTC
    bcf	    banderas, high_hex_flag
    return
    
disp_low_hex:
    bcf	    PORTD, 0
    bsf	    PORTD, 1
    movf    l_hex, 0
    call    table
    movwf   PORTC
    bcf	    banderas, low_hex_flag
    return

disp_centena:
    bcf	    PORTD, 1
    bsf	    PORTD, 2
    movf    centena, 0
    call    table
    movwf   PORTC
    bcf	    banderas, centena_flag
    return
 
disp_decena:
    bcf	    PORTD, 2
    bsf	    PORTD, 3
    movf    decena, 0
    call    table
    movwf   PORTC
    bcf	    banderas, decena_flag
    return
    
disp_unidad:
    bcf	    PORTD, 3
    bsf	    PORTD, 4
    movf    unidad, 0
    call    table
    movwf   PORTC
    bcf	    banderas, unidad_flag
    return


divide:
    movlw   0x0
    movwf   centena
    movwf   cent_left
    movwf   decena
    movwf   dec_left
    movwf   unidad
    movwf   units_left
    movf    counter, 0
hundred:
    movwf   cent_left
    movlw   100
    subwf   cent_left, f
    btfsc   STATUS, 0
    incf    centena
    btfsc   STATUS, 0
    goto    hundred
    movlw   100
    addwf   cent_left, f
    movf    cent_left,0
    movwf   dec_left
    

ten:
    movlw   10
    subwf   dec_left, f
    btfsc   STATUS, 0
    incf    decena
    btfsc   STATUS, 0
    goto    ten
    movlw   10
    addwf   dec_left, f
    movf    dec_left, 0
    movwf   units_left
one:
    movlw   1
    subwf   units_left, f
    btfsc   STATUS, 0
    incf    unidad
    btfsc   STATUS, 0
    goto    one
    movlw   1
    addwf   units_left, f
    return