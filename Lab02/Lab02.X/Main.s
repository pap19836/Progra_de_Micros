; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Stefano Papadopolo
; Compilador: 
;
; Programa: Sumador de 4 bits
; Hardware: Leds en puerto C y D, Push-buttons en B
;
; Creado 9 feb, 2021
; Última Actualización: 9 feb, 2021

PROCESSOR 16F887
#include <xc.inc>

// CONFIG1
CONFIG FOSC = XT        // Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
CONFIG WDTE = OFF       // Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG PWRTE = OFF      // Power-up Timer Enable bit (PWRT disabled)
CONFIG MCLRE = OFF      // RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG CP = OFF         // Code Protection bit (Program memory code protection is disabled)
CONFIG CPD = OFF        // Data Code Protection bit (Data memory code protection is disabled)
CONFIG BOREN = OFF      // Brown Out Reset Selection bits (BOR disabled)
CONFIG IESO = OFF       // Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG FCMEN = OFF      // Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG LVP = ON         // Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

// CONFIG2
CONFIG BOR4V = BOR40V   // Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG WRT = OFF        // Flash Program Memory Self Write Enable bits (Write protection off)

// CONFIG statements should precede project file includes.
// Use project enums instead of #define for ON and OFF.


PSECT udata_bank0 ; common memory
    c1: DS 1
    c2: DS 1

    
PSECT resVect, class=CODE, abs, delta=2
;Vector Reset
ORG 00h ;posición 0000h para el reset
resetVec:
    PAGESEL main
    goto main

PSECT code, delta=2, abs
ORG 100h ;Posición para el código
;configuración
main:
    banksel ANSEL   //Select bank of ANSEL
    clrf    ANSEL   //Pins are digital
    clrf    ANSELH
    
    banksel TRISA   //Select bank of TRISA
    clrf    TRISA
    clrf    TRISB
    movlw   0x1F    //bits 0001 1111 para cambiar B a inputs
    movwf   TRISB   //Port B input
    clrf    TRISC   //Port C output
    clrf    TRISD   //Port D output
    
    movlw   0x7F
    movwf   OPTION_REG
    
    movlw   0x1F    //Turn un internal PORTB pull-ups
    movwf   WPUB
    
    banksel PORTA
    clrf    PORTA
    clrf    PORTB
    clrf    PORTC   //Clear Ports c y d para empezar de 0
    clrf    PORTD

    movlw   0x00
    movwf   c1
    
    movlw   0x00
    movwf   c2
    
 
 
//Loop inicial
loop:
    btfss   PORTB,  0
    call    inc_C1
    btfss   PORTB,  1
    call    dec_C1
    btfss   PORTB,  2
    call    inc_C2
    btfss   PORTB,  3
    call    dec_C2
    btfss   PORTB,  4
    call    sum
    goto    loop    

    
//Sub-rutiinas
inc_C1:
    btfss   PORTB, 0
    goto    $-1
    incf    c1
    movf    c1, 0
    andlw   0x0F
    movwf   PORTC
    return
    
dec_C1:
    btfss   PORTB, 1
    goto    $-1
    decf    c1
    movf    c1, 0
    andlw   0x0F
    movwf   PORTC
    return

inc_C2:
    btfss   PORTB, 2
    goto    $-1
    incf    c2
    movf    c2, 0
    andlw   0x0F
    movwf   PORTD
    return
    
dec_C2:
    btfss   PORTB, 3
    goto    $-1
    decf    c2
    movf    c2, 0
    andlw   0x0F
    movwf   PORTD
    return
    
sum:
    btfss   PORTB,  4
    goto    $-1
    movf    PORTC, 0
    addwf   PORTD, 0
    movwf   PORTA
    return