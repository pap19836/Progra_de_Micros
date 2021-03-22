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
GLOBAL w_temp, status_temp, banderas, count_delay, auto_counter, manual_counter
PSECT udata_shr
;variables de Interrupciones
w_temp:
    DS 1
status_temp:
    DS 1
banderas:
    DS 1
banderas_antirrebote:
    DS 1
;variables de programa
count_delay:
    DS 1
auto_counter:
    DS 1
manual_counter:
    DS 1
  
;|----------------------------------------------------------------------------|
;|---------------------------------MACROS-------------------------------------|
;|----------------------------------------------------------------------------|
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
    btfsc   INTCON, 2
    goto    timer0
    btfsc   INTCON, 0
    goto    debounce
    
    goto    pop
timer0:
    reset_timer0
    decf  count_delay
    goto interrupt_select
    
debounce:
    banksel PORTB
    btfss   PORTB, 0
    bsf	    banderas_antirrebote, 0
    btfss   PORTB, 1
    bsf	    banderas_antirrebote, 1
    bcf	    INTCON, 0
    bsf	    banderas_antirrebote, 7
    goto    interrupt_select
    
pop:
    banksel STATUS
    swapf   status_temp, w
    movf    STATUS
    swapf   w_temp, f
    swapf   w_temp, w
    retfie

PSECT loopPrincipal, class=CODE, delta=2
    
main:
    call port_config
    call interrupt_config
    movlw   0x00
    movwf   auto_counter
    movwf   manual_counter
    
    movlw   0b11110000	    //PSA to TMR0 and timer as temp
    andwf   OPTION_REG
    
    banksel TMR0	    //Iniciar en 0
    movlw   0x00
    movwf   TMR0
    
    movlw   125		    //inicializar delay grande
    movwf   count_delay
    
    reset_timer0

loop:
    call    a_counter
    btfsc   banderas_antirrebote, 7
    call    push_button
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
    
    movlw   0b00000011	;Volver pines de PORTB inputs con sus pull-ups
    movwf   TRISB
    bcf	    OPTION_REG, 7
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
    bsf	INTCON, 7	;General interrupt enable
    bsf	INTCON, 5	;timer0 interrupt enable
    bsf	INTCON, 3	;General IOC port B enable
    
    banksel IOCB
    bsf	IOCB,	0	;Specific IOCBs
    bsf	IOCB,	1
    
    bcf	INTCON, 0
    bcf	INTCON, 2
    
    return
    
a_counter:
    movf    count_delay
    btfsc   STATUS, 2
    call    a_increase
    return

a_increase:
    incf    auto_counter	    //Incrementar counter
    movf    auto_counter,0
    andlw   0x0F	    //And con 00001111 para que solo se usen 4bits
    banksel PORTC
    movwf   PORTC
    movlw   125
    movwf   count_delay
    return

push_button:
    btfsc   banderas_antirrebote, 0
    call    m_counter_inc
    btfsc   banderas_antirrebote, 1
    call    m_counter_dec
    movf    manual_counter, 0
    andlw   0x0F
    banksel PORTD
    movwf   PORTD
    bcf	    banderas_antirrebote, 7
    return
    
m_counter_inc:
    incf    manual_counter
    bcf	    banderas_antirrebote, 0
    return
m_counter_dec:
    decf    manual_counter
    bcf	    banderas_antirrebote, 1
    return


