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
GLOBAL w_temp, status_temp, banderas_7seg, counter_control, counter0, counter0_temp, counter1, counter1_temp, counter2, counter2_temp, max, min, banderas_antirrebote, mode
PSECT udata_bank0
;variables de Interrupciones
w_temp:
    DS 1
status_temp:
    DS 1
banderas_7seg:
    DS 1
dc_flag	    EQU	0
uc_flag	    EQU	1
banderas_antirrebote:
    DS 1
;variables de programa
counter0:
    DS 1
counter0_temp:
    DS 1
counter1:
    DS 1
counter1_temp:
    DS 1
counter2:
    DS 1
counter2_temp:
    DS 1
counter_control:
    DS 1
max:
    DS 1
min:
    DS 1
mode:
    DS 1
u_left:
    DS 1
unidad:
    DS 1
d_left:
    DS 1
decena:
    DS 1
dc:
    DS 1
uc:
    DS 1
;|----------------------------------------------------------------------------|
;|---------------------------------MACROS-------------------------------------|
;|----------------------------------------------------------------------------|
    reset_timer0	macro
    banksel TMR0
    bcf	    INTCON, 2
    movlw   8		    //valor inicial calculado para 250 us
    movwf   TMR0
    banksel OPTION_REG
    movlw   0b11010011	    //Multiplicar por 16 para 4ms
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
    
interrupt_select:
    btfsc   INTCON, 0
    goto    debounce 
    btfsc   INTCON, 2	    ;Flag for TMR0
    goto    mux
    goto    pop
    
debounce:
    banksel PORTB
    btfss   PORTB, 3
    bsf	    banderas_antirrebote, 3
    btfss   PORTB, 4
    bsf	    banderas_antirrebote, 4
    btfss   PORTB, 5
    bsf	    banderas_antirrebote, 5
    bcf	    INTCON, 0
    bsf	    banderas_antirrebote, 7
    goto    interrupt_select

mux:
    reset_timer0
    banksel PORTD
    btfsc   PORTD,  0
    bsf	    banderas_7seg, uc_flag
    btfsc   PORTD,  1
    bsf	    banderas_7seg, dc_flag
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
    
main:
    call port_config
    call interrupt_config
    call inicializar_variables



loop:
    call    active_mode
    
    btfsc   banderas_7seg,  dc_flag
    call    disp_dc
    btfsc   banderas_7seg,  uc_flag
    call    disp_uc
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
    movwf   TRISA
    movwf   TRISC
    movwf   TRISD
    
    movlw   0b00111000	;Volver pines de PORTB inputs con sus pull-ups
    movwf   TRISB
    bcf	    OPTION_REG, 7
    movlw   0b00111000
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
    bsf	INTCON, 5
    bsf	INTCON, 3	;General IOC port B enable
    
    banksel IOCB
    bsf	IOCB,	3	;Specific IOCBs
    bsf	IOCB,	4
    bsf	IOCB,	5
    
    bcf	INTCON, 0
    
    return

inicializar_variables:
    reset_timer0
    banksel PORTA
    movlw   12
    movwf   counter0
    movwf   counter0_temp
    movlw   15
    movwf   counter1
    movwf   counter1_temp
    movlw   18
    movwf   counter2
    movwf   counter2_temp
    movlw   21
    movwf   max
    movlw   9
    movwf   min
    movlw   0
    movwf   mode
    movwf   uc
    movwf   dc
    bsf	    PORTD, 0
    return
    
active_mode:
    movlw   0
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    default_mode
    movlw   1
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    change_counter0
    movlw   2
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    change_counter1
    movlw   3
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    change_counter2
    movlw   4
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    confirm_changes
    return
    
default_mode:
    movlw   0
    movwf   PORTA
    movwf   PORTC
    btfsc   banderas_antirrebote, 7
    call    config_apagado
    return
config_apagado:
    bcf	    banderas_antirrebote, 3
    bcf	    banderas_antirrebote, 4
    btfsc   banderas_antirrebote, 5
    call    change_mode
    bcf	    banderas_antirrebote, 7
    return
change_mode:
    incf    mode
    movlw   5
    subwf   mode, 0
    btfsc   STATUS, 2
    goto    return_mode0
    bcf	    banderas_antirrebote, 5
    return
    return_mode0:
    movlw   0
    movwf   mode
    bcf	    banderas_antirrebote, 5
    return
change_counter0:
    movlw   0
    movwf   PORTA
    bsf	    PORTA, 0
    movf    counter0_temp,0
    movwf   counter_control
    call    divide_counter_control
    btfsc   banderas_antirrebote, 7
    call    counter_config
    movf    counter_control, 0
    movwf   counter0_temp
    return
change_counter1:
    movlw   0
    movwf   PORTA
    bsf	    PORTA, 1
    movf    counter1_temp,0
    movwf   counter_control
    call    divide_counter_control
    btfsc   banderas_antirrebote, 7
    call    counter_config
    movf    counter_control, 0
    movwf   counter1_temp
    return
change_counter2:
    movlw   0
    movwf   PORTA
    bsf	    PORTA, 2
    movf    counter2_temp,0
    movwf   counter_control
    call    divide_counter_control
    btfsc   banderas_antirrebote, 7
    call    counter_config
    movf    counter_control, 0
    movwf   counter2_temp
    return
counter_config:
    btfsc   banderas_antirrebote, 3
    call    inc_counter
    btfsc   banderas_antirrebote, 4
    call    dec_counter
    btfsc   banderas_antirrebote, 5
    call    change_mode
    bcf	    banderas_antirrebote, 7
    return
    
inc_counter:
    incf    counter_control
    movf    counter_control, 0
    subwf   max, 0
    btfsc   STATUS, 2
    call    loop_over
    bcf	    banderas_antirrebote, 3
    return
loop_over:
    movlw   10
    movwf   counter_control
    return
    
dec_counter:
    decf    counter_control
    movf    counter_control, 0
    subwf   min, 0
    btfsc   STATUS, 2
    call    loop_under
    bcf	    banderas_antirrebote, 4
    return
loop_under:
    movlw   20
    movwf   counter_control
    return

confirm_changes:
    movlw   0b00000111
    movwf   PORTA
    btfsc   banderas_antirrebote, 7
    call    confirmation
    return
confirmation:
    btfsc   banderas_antirrebote, 3
    call    accept
    btfsc   banderas_antirrebote, 4
    call    reject
    btfsc   banderas_antirrebote, 5
    call    change_mode
    bcf	    banderas_antirrebote, 7
    return

accept:
    movf    counter0_temp, 0
    movwf   counter0
    movf    counter1_temp, 0
    movwf   counter1
    movf    counter2_temp, 0
    movwf   counter2
    movlw   0
    movwf   mode
    bcf	    banderas_antirrebote, 3
    return
reject:
    movf    counter0, 0
    movwf   counter0_temp
    movf    counter1, 0
    movwf   counter1_temp
    movf    counter2, 0
    movwf   counter2_temp
    movlw   0
    movwf   mode
    bcf	    banderas_antirrebote, 4
    return
    
    
divide:
    movwf   d_left
    ten:
    movlw   10
    subwf   d_left, f
    btfsc   STATUS, 0
    incf    decena
    btfsc   STATUS, 0
    goto    ten
    movlw   10
    addwf   d_left, f
    movf    d_left, 0
    movwf   u_left
    one:
    movlw   1
    subwf   u_left, f
    btfsc   STATUS, 0
    incf    unidad
    btfsc   STATUS, 0
    goto    one
    movlw   1
    addwf   u_left, f
    return
divide_counter_control:
    movlw   0
    movwf   decena
    movwf   unidad
    movf    counter_control, 0
    call    divide
    movf    decena, 0
    movwf   dc
    movf    unidad, 0
    movwf   uc
    return
    
disp_dc:
    bcf	    PORTD, uc_flag
    bsf	    PORTD, dc_flag
    movf    dc,	0
    call    table
    movwf   PORTC
    bsf	    PORTB, 0
    bcf	    banderas_7seg, dc_flag
    return
disp_uc:
    bcf	    PORTD, dc_flag
    bsf	    PORTD, uc_flag
    movf    uc,	0
    call    table
    movwf   PORTC
    bcf	    PORTB, 0
    bcf	    banderas_7seg, uc_flag
    return