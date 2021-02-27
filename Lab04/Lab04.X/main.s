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
GLOBAL w_temp, status_temp, main_counterf, auto_counterf, counter, count_display, auto_counter, auto_delay
  PSECT udata_shr
 ;variables de interrupciones
 w_temp:
    DS 1
status_temp:
    DS 1
main_counterf:
    DS 1
    DS 1
auto_counterf:
    DS 1
;variables de programa
counter:
    DS 1
count_display:
    DS 1
auto_delay:
    DS 1
auto_counter:
    DS 1
;|----------------------------------------------------------------------------|
;|---------------------------------MACROS-------------------------------------|
;|----------------------------------------------------------------------------|

all_digital macro
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH
    endm

input_b	    macro
    banksel TRISB
    movlw   0xFF
    movwf   TRISB
    movlw   0b01111111
    andwf   OPTION_REG
    movlw   0xFF
    movwf   WPUB
    endm

clear_ports macro
    banksel PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    endm

reset_timer0 macro
    banksel TMR0
    movlw   193		    //valor inicial calculado para 1s
    bcf	    INTCON, 2
    movwf   TMR0
    banksel OPTION_REG
    movlw   0b11010000
    andwf   OPTION_REG, w
    iorlw   0b00000011	    //Prescaler 1:16
    movwf   OPTION_REG
    endm
    
movlf macro arg1, arg2
    movlw   arg1
    movwf   arg2
    endm

end_delay_check macro
    movf    auto_delay, 0
    iorlw   0x00
    btfsc   STATUS, 2
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
    bcf	    INTCON, 1
    banksel PORTB
    btfss   PORTB,1
    bsf	    main_counterf,1	//Bandera para aumentar contador
    btfss   PORTB,0
    bsf	    main_counterf,0	//Bandera para disminuir contador
    bcf	    INTCON, 0
    
    btfsc   T0IF
    bsf	    auto_counterf,0	//Bandera para contador automático
    reset_timer0
    decfsz  auto_delay	    //Decrementar el timer
    bcf	    T0IF

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
    all_digital
    
    input_b
    clrf TRISA
    clrf TRISC
    clrf TRISD
    
    movlw   0b11110000	    //PSA to TMR0 and timer as temp
    andwf   OPTION_REG
    
    bsf	    INTCON, 7	    //Habilitar interrupciones generales, IOC y TMR0
    bsf	    INTCON, 3
    bsf	    INTCON, 5
    bsf	    IOCB,   0
    bsf	    IOCB,   1
    
    banksel TMR0	    //Iniciar en 0
    movlw   0x00
    movwf   TMR0
    
    movlw   0x00	    //Iniciar en 0
    movwf   counter
    movwf   main_counterf
    movwf   auto_counterf
    movwf   auto_counter

    movlw   250
    movwf   auto_delay
    clear_ports
    reset_timer0
    
;Loop Principal
loop:
    btfsc   main_counterf,0
    call    count_up
    btfsc   main_counterf,1
    call    count_down
    btfsc   auto_counterf,0
    call    auto
    goto    loop
    
;Sub-rutinas
count_up:

    banksel PORTB
    btfss   PORTB, 0
    goto    $-1
    incf    counter
    movf    counter,0
    andlw   0x0F	
    banksel PORTA	//solo tomar en cuenta los 4bits menos significativos
    movwf   PORTA
    call    display
    bcf	    main_counterf,0
    return
    
count_down:
    banksel PORTB
    btfss   PORTB, 1
    goto    $-1
    bcf	    main_counterf,1
    decf    counter
    movf    counter,0
    andlw   0x0F	//solo tomar en cuenta los 4bits menos significativos
    banksel PORTA
    movwf   PORTA
    call    display
    return
    
display:
    movf    counter,0
    andlw   0x0F	//solo tomar en cuenta los 4bits menos significativos
    call    table
    movwf   PORTC
    return
    
auto:
    bcf	    auto_counterf,0
    end_delay_check	    //Verificar que el contador de delay haya sido reducido a 0
    incf    auto_counter    //Incrementar counter
    end_delay_check
    movlw   250
    end_delay_check
    movwf   auto_delay
    banksel PORTD
    movf    auto_counter,0
    andlw   0x0F	    //solo tomar en cuenta los 4bits menos significativos
    call    table
    movwf   PORTD  
    return
