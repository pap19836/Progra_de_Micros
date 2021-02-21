; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Stefano Papadopolo
; Compilador: pic-as (v2.31) [C:\Program Files\Microchip\xc8\v2.31\pic-as\bin]
;
; Programa: Contador Timer 0 y alarma con 7 segmentos
; Hardware: Leds en puerto C para contador de 4 bits, display de 7 segmentos y push-buttons
;
; Creado 16 feb, 2021
; Última Actualización: 16 feb, 2021

PROCESSOR 16F887
#include <xc.inc>
    
CONFIG FOSC = INTRC_NOCLKOUT// Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG WDTE = OFF       // Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG PWRTE = OFF      // Power-up Timer Enable bit (PWRT disabled)
CONFIG MCLRE = OFF      // RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG CP = OFF         // Code Protection bit (Program memory code protection is disabled)
CONFIG CPD = OFF        // Data Code Protection bit (Data memory code protection is disabled)
CONFIG BOREN = ON       // Brown Out Reset Selection bits (BOR enabled)
CONFIG IESO = ON        // Internal External Switchover bit (Internal/External Switchover mode is enabled)
CONFIG FCMEN = ON       // Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is enabled)
CONFIG LVP = ON         // Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

// CONFIG2
CONFIG BOR4V = BOR40V   // Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG WRT = OFF        // Flash Program Memory Self Write Enable bits (Write protection off)


;|----------------------------------------------------------------------------|
;|-------------------------------VARIABLES------------------------------------|
;|----------------------------------------------------------------------------|
    
PSECT udata_shr ; common memory
    counter:
	DS 1
    count_delay:
	DS 1
    count_seven:
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
    movlw   0x08
    bcf	    INTCON, 2
    movwf   TMR0
    banksel OPTION_REG
    movlw   0b11010000
    andwf   OPTION_REG, w
    iorlw   0b00000011	    //Prescaler 1:16
    movwf   OPTION_REG
    endm
    
;|----------------------------------------------------------------------------|
;|----------------------------------CODE--------------------------------------|
;|----------------------------------------------------------------------------|

PSECT resVect, class=CODE, abs, delta=2
;Vector Reset
ORG 00h ;posición 0000h para el reset
resetVec:
    PAGESEL main
    goto main

PSECT loopPrincipal, class=CODE, delta=2, abs
ORG 100h ;Posición para el código
;configuración    
table:
    clrf    PCLATH
    movlw   0x01
    movwf   PCLATH
    movf    count_seven, 0
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
    
    input_b		    //Puerto b es input, puertos c,d y e son output
    clrf    TRISC	
    clrf    TRISD
    clrf    TRISE
    
    movlw   0b11110000	    //PSA to TMR0 and timer as temp
    andwf   OPTION_REG
    
    banksel TMR0	    //Iniciar en 0
    movlw   0x00
    movwf   TMR0
    
    movlw   0x00	    //Iniciar en 0
    movwf   count_seven
    
    clear_ports
    
    

;Loop Inicial
loop:
    call    main_counter
    btfss   PORTB, 0
    call    seven_up
    btfss   PORTB, 1
    call    seven_down
    movf    count_seven, 0
    subwf   PORTC,  0
    bcf	    PORTE,  0
    btfsc   STATUS, 2
    call    alarm
    goto loop
;Sub-Rutinas
main_counter:
    movlw   125		    //inicializar delay grande
    movwf   count_delay
    call    delay
    incf    counter	    //Incrementar counter
    movf    counter,0
    andlw   0x0F	    //And con 00001111 para que solo se usen 4bits
    banksel PORTC
    movwf   PORTC  
    return
    
delay:
    reset_timer0	    
    btfss   INTCON, 2	    //Bandera de timer0 overflow
    goto    $-1		    //repetir hasta que se encienda la bandera
    decfsz  count_delay	    //Decrementar el timer
    goto    delay
    return

seven_up:
    btfss   PORTB, 0	    //Antirebote
    goto    $-1
    bcf	    STATUS, 2	    //Limpiar zero flag
    incf    count_seven	    //Incrementar contador 7segmentos
    movf    count_seven, 0
    andlw   0x0F
    movwf   count_seven
    call    table
    movwf   PORTD	    //Mostrar valor de tabla en PortD
    return
    
    
seven_down:
    btfss   PORTB, 1
    goto    $-1
    bcf	    STATUS, 2
    decf    count_seven
    movf    count_seven, 0
    andlw   0x0F
    movwf   count_seven
    call    table
    movwf   PORTD
    return

alarm:

    bsf	    PORTE,  0	    //Encender bit en E de alarma
    movlw   0x00	    //Reiniciar contador de 4 bits
    movwf   counter
    return
        
END