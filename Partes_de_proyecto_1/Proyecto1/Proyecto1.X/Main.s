; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Stefano Papadopolo
; Compilador: pic-as (v2.32) [C:\Program Files\Microchip\xc8\v2.31\pic-as\bin]
;
; Programa: Proyecto 1 - Semaforo de 3 vías
; Hardware: 12 Leds, 8 displays de 7 segmentos y 3 push-buttons
;
; Creado 9 mar, 2021
; Última Actualización: 

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
GLOBAL w_temp, status_temp, banderas_7seg, banderas_antirrebote, banderas_misc
GLOBAL tiempo0, d0, u0, tiempo1, d1, u1, tiempo2, d2, u2, tiempo_max, tiempo_min
GLOBAL tiempo_control, uc, dc, decena, d_left, unidad, u_left, seconds_delay
GLOBAL s0, s1, s2, tiempo0_temp, tiempo1_temp, tiempo2_temp, mode
GLOBAL disp_time0, disp_time1, disp_time2, banderas_semaforo
PSECT udata_bank0  
;variables de Interrupciones
w_temp:
    DS 1
status_temp:
    DS 1
banderas_7seg:
    DS 1
dc_flag  EQU	0
uc_flag  EQU	1
d0_flag  EQU	2
u0_flag  EQU	3
d1_flag  EQU	4
u1_flag  EQU	5
d2_flag  EQU	6
u2_flag  EQU	7
banderas_antirrebote:
    DS 1
banderas_misc:
    DS 1
s0_flag		EQU	0
s1_flag		EQU	1
s2_flag		EQU	2
on_off		EQU	3
blink0_on	EQU	4
blink1_on	EQU	5
blink2_on	EQU	6

		
banderas_semaforo:
    DS	1
green0_flag	EQU	0
yellow0_flag	EQU	1
green1_flag	EQU	2
yellow1_flag	EQU	3
green2_flag	EQU	4
yellow2_flag	EQU	5
	

;variables de programa

tiempo_control:	    ;Variables pertinentes a mostrar los tiempos
    DS 1
uc:		
    DS 1
dc:
    DS 1
tiempo0:
    DS 1
d0:
    DS 1
u0:
    DS 1
tiempo1:
    DS 1
d1:
    DS 1
u1:
    DS 1
tiempo2:
    DS 1
d2:
    DS 1
u2:
    DS 1
tiempo_max:
    DS 1
tiempo_min:
    DS 1
unidad:
    DS 1
decena:
    DS 1
d_left:
    DS 1
u_left:
    DS 1
seconds_delay:
    DS 1
s0:
    DS 1
s1:
    DS 1
s2:
    DS 1

green	EQU 1
yellow	EQU 2
red	EQU 4
	
disp_time0:
    DS	1
disp_time1:
    DS	1
disp_time2:
    DS	1
mode:		;variables pertinentes al cambio de tiempo
    DS 1
tiempo0_temp:
    DS 1
tiempo1_temp:
    DS 1
tiempo2_temp:
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

reset_timer1	macro
    banksel TMR1H
    bcf	    PIR1, 0
    movlw   0b01100010
    movwf   TMR1H
    movlw   0b11000110
    movwf   TMR1L
    movlw   0b00110001
    movwf   T1CON
    endm
    
reset_timer2	macro
    banksel TMR2
    bcf	    PIR1, 1
    movlw   0
    movwf   TMR2
    movlw   0b00100111	    //1:16 and 1:5 prescaler
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
    btfsc   INTCON, 0	    ;Flag for IOCB
    goto    debounce
    btfsc   INTCON, 2	    ;Flag for TMR0
    goto    sev_seg_mux
    btfsc   PIR1, 1	    ;Flag for TMR2
    goto    delay
    
    goto    pop


sev_seg_mux:
    reset_timer0
    banksel PORTD
    btfsc   PORTE,  0
    bsf	    banderas_misc, s1_flag
    btfsc   PORTE,  1
    bsf	    banderas_misc, s2_flag
    btfsc   PORTE,  2
    bsf	    banderas_misc, s0_flag
    btfsc   PORTD,  0
    bsf	    banderas_7seg, uc_flag
    btfsc   PORTD,  1
    bsf	    banderas_7seg, d0_flag
    btfsc   PORTD,  2
    bsf	    banderas_7seg, u0_flag
    btfsc   PORTD,  3
    bsf	    banderas_7seg, d1_flag
    btfsc   PORTD,  4
    bsf	    banderas_7seg, u1_flag
    btfsc   PORTD,  5
    bsf	    banderas_7seg, d2_flag
    btfsc   PORTD,  6
    bsf	    banderas_7seg, u2_flag
    btfsc   PORTD,  7
    bsf	    banderas_7seg, dc_flag
    goto    interrupt_select

delay:
    bcf	    PIR1, 1
    decf    seconds_delay
    goto    interrupt_select
    
debounce:
    banksel PORTB
    btfss   PORTB, 3
    bsf	    banderas_antirrebote, 3	;push en RB3
    btfss   PORTB, 4
    bsf	    banderas_antirrebote, 4	;push en RB4
    btfss   PORTB, 5
    bsf	    banderas_antirrebote, 5	;push en RB5
    bsf	    banderas_antirrebote, 7	;any push pressed
    bcf	    INTCON, 0
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
    
loop:
    banksel PORTA
;DIVIDE IN TENS AND UNITS
    call    divide_tiempo0
    call    divide_tiempo1
    call    divide_tiempo2
    
    call    active_mode
    
    btfsc   banderas_semaforo, green0_flag
    call    green0
    movf    disp_time0, 0
    btfsc   STATUS, 2
    call    yellow0
    btfsc   banderas_semaforo, green1_flag
    call    green1
    movf    disp_time1, 0
    btfsc   STATUS, 2
    call    yellow1
    btfsc   banderas_semaforo, green2_flag
    call    green2
    movf    disp_time2, 0
    btfsc   STATUS, 2
    call    yellow2
    
    call    test_blink
    btfsc   banderas_misc, blink0_on
    call    blink0
    btfsc   banderas_misc, blink1_on
    call    blink1
    btfsc   banderas_misc, blink2_on
    call    blink2
    

;COUNTDOWN
   movf    seconds_delay, 0
   btfsc   STATUS, 2
   call    decrease_second

;DISPLAY
    banksel PORTD
    btfsc   banderas_misc,  s0_flag
    call    disp_s0
    btfsc   banderas_misc,  s1_flag
    call    disp_s1
    btfsc   banderas_misc,  s2_flag
    call    disp_s2
    btfsc   banderas_7seg,  dc_flag
    call    disp_dc
    btfsc   banderas_7seg,  uc_flag
    call    disp_uc
    btfsc   banderas_7seg,  d0_flag
    call    disp_d0
    btfsc   banderas_7seg,  u0_flag
    call    disp_u0
    btfsc   banderas_7seg,  d1_flag
    call    disp_d1
    btfsc   banderas_7seg,  u1_flag
    call    disp_u1
    btfsc   banderas_7seg,  d2_flag
    call    disp_d2
    btfsc   banderas_7seg,  u2_flag
    call    disp_u2


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
    movwf   TRISB
    movwf   TRISC
    movwf   TRISD
    bcf	    TRISE, 0
    bcf	    TRISE, 1
    bcf	    TRISE, 2
	
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
    
inicializar_variables:
    banksel PR2
    movlw   250		;Compare value of TMR2
    movwf   PR2
    banksel PORTA
    movlw   50		;Delay for tmr2 to change the clock every second
    movwf   seconds_delay
    bsf	    PORTD, 0	;Starting point for mux
    bsf	    PORTE, 0
    movlw   10
    movwf   tiempo0
    movwf   tiempo0_temp
    movlw   10
    movwf   tiempo1
    movwf   tiempo1_temp
    movlw   10
    movwf   tiempo2
    movwf   tiempo2_temp
    movlw   0
    movwf   banderas_misc
    movwf   mode
    movlw   green
    movwf   s0
    movlw   red
    movwf   s1
    movlw   red
    movwf   s2
    bsf	    banderas_semaforo, 0
    bsf	    banderas_misc, on_off
    return
    
interrupt_config:
    banksel PIE1
    bsf	    INTCON, 7	;General Int Enable
    bsf	    INTCON, 6	;Peripheral (timer 2) interrupt enable
    bsf	    INTCON, 5	;Tmr0 Int Enable
    bsf	    INTCON, 3	;IOCB enable
    movlw   0b00111000
    movwf   IOCB
    bsf	    PIE1,   1	;TMR2 int Enable
    return

active_mode:
    movlw   0
    subwf   mode, 0
    btfsc   STATUS, 2
    call    default_mode
    movlw   1
    subwf   mode, 0
    btfsc   STATUS, 2
    call    change_tiempo0
    movlw   2
    subwf   mode, 0
    btfsc   STATUS, 2
    call    change_tiempo1
    movlw   3
    subwf   mode, 0
    btfsc   STATUS, 2
    call    change_tiempo2
    movlw   4
    subwf   mode, 0
    btfsc   STATUS, 2
    call    confirm_changes
    return
config_apagado:
    bcf	    banderas_antirrebote, 3
    bcf	    banderas_antirrebote, 4
    btfsc   banderas_antirrebote, 5
    call    change_mode
    bcf	    banderas_antirrebote, 7
    return
tiempo_config:
    btfsc   banderas_antirrebote, 3
    call    inc_tiempo
    btfsc   banderas_antirrebote, 4
    call    dec_tiempo
    btfsc   banderas_antirrebote, 5
    call    change_mode
    bcf	    banderas_antirrebote, 7
    return


inc_tiempo:
    incf    tiempo_control
    movf    tiempo_control, 0
    subwf   tiempo_max, 0
    btfsc   STATUS, 2
    call    loop_over
    bcf	    banderas_antirrebote, 3
    return
loop_over:
    movlw   10
    movwf   tiempo_control
    return
    
dec_tiempo:
    decf    tiempo_control
    movf    tiempo_control, 0
    subwf   tiempo_min, 0
    btfsc   STATUS, 2
    call    loop_under
    bcf	    banderas_antirrebote, 4
    return
loop_under:
    movlw   20
    movwf   tiempo_control
    return
change_mode:
    incf    mode
    bcf	    banderas_antirrebote, 5
    return
reset_mode:
    movlw   0
    movwf   mode
    bcf	    banderas_antirrebote, 3
    bcf	    banderas_antirrebote, 4
    bcf	    banderas_antirrebote, 5
    return

confirmation:
    btfsc   banderas_antirrebote, 3
    call    accept
    btfsc   banderas_antirrebote, 4
    call    reset_mode
    btfsc   banderas_antirrebote, 5
    call    reset_mode
    bcf	    banderas_antirrebote, 7
    return
accept:
    movf    tiempo0_temp, 0
    movwf   tiempo0
    movf    tiempo1_temp, 0
    movwf   tiempo1
    movf    tiempo2_temp, 0
    movwf   tiempo2_temp
    return
default_mode:
    movlw   16
    movwf   dc
    movwf   uc
    btfsc   banderas_antirrebote, 7
    call    config_apagado
    return
    
green0:
    movlw   green
    movwf   s0
    movlw   red
    movwf   s1
    movwf   s2
    movf    tiempo0, 0
    movwf   disp_time1	    ;muestra el tiempo que falta para cambiar
    movwf   disp_time0
    movlw   3
    subwf   disp_time0, 1
    movf    tiempo0, 0
    addwf   tiempo1, 0
    movwf   disp_time2
    bcf	    banderas_semaforo, green0_flag
    return
yellow0:
    bcf	    banderas_misc, blink0_on
    btfsc   s0, 2			    ;skip this if it was red
    goto    s0_was_red
    btfsc   banderas_semaforo, yellow0_flag
    goto    red0
    movlw   3
    movwf   disp_time0
    movlw   yellow
    movwf   s0
    bsf	    banderas_semaforo, yellow0_flag
    return
    red0:
    bsf	    banderas_semaforo, green1_flag
    bcf	    banderas_semaforo, yellow0_flag
    s0_was_red:
    return

green1:
    movlw   green
    movwf   s1
    movlw   red
    movwf   s0
    movwf   s2
    movf    tiempo0, 0
    movwf   disp_time2	    ;muestra el tiempo que falta para cambiar
    movwf   disp_time1
    movlw   3
    subwf   disp_time1, 1
    movf    tiempo1, 0
    addwf   tiempo2, 0
    movwf   disp_time0
    bcf	    banderas_semaforo, green1_flag
    return
yellow1:
    bcf	    banderas_misc, blink1_on
    btfsc   banderas_semaforo, yellow1_flag
    goto    red1
    movlw   3
    movwf   disp_time1
    movlw   yellow
    movwf   s1
    bsf	    banderas_semaforo, yellow1_flag
    return
    red1:
    bsf	    banderas_semaforo, green2_flag
    bcf	    banderas_semaforo, yellow1_flag
    return

green2:
    movlw   green
    movwf   s2
    movlw   red
    movwf   s1
    movwf   s0
    movf    tiempo2, 0
    movwf   disp_time0	    ;muestra el tiempo que falta para cambiar
    movwf   disp_time2
    movlw   3
    subwf   disp_time2, 1
    movf    tiempo2, 0
    addwf   tiempo0, 0
    movwf   disp_time1
    bcf	    banderas_semaforo, green2_flag
    return
yellow2:
    bcf	    banderas_misc, blink2_on
    btfsc   banderas_semaforo, yellow2_flag
    goto    red2
    movlw   3
    movwf   disp_time2
    movlw   yellow
    movwf   s2
    bsf	    banderas_semaforo, yellow2_flag
    return
    red2:
    bsf	    banderas_semaforo, green0_flag
    bcf	    banderas_semaforo, yellow2_flag
    return
    
test_blink:
    btfsc   s0, 0
    goto    test_blink0
    btfsc   s1, 0
    goto    test_blink1
    btfsc   s2, 0
    goto    test_blink2
    return
    test_blink0:
    movlw   3
    subwf   disp_time0, 0
    btfsc   STATUS, 2
    bsf	    banderas_misc, blink0_on
    return
    test_blink1:
    movlw   3
    subwf   disp_time1, 0
    btfsc   STATUS, 2
    bsf	    banderas_misc, blink1_on
    return
    test_blink2:
    movlw   3
    subwf   disp_time2, 0
    btfsc   STATUS, 2
    bsf	    banderas_misc, blink2_on
    return
 
blink0:
    btfsc   PIR1, 0
    call    blink0_active
    return
blink0_active:
    reset_timer1
    btfsc   banderas_misc, on_off
    goto    on0
    btfss   banderas_misc, on_off
    goto    off0
    on0:
    bsf	    s0, 0		    ;green light
    call    divide_tiempo0
    bcf	    banderas_misc, on_off
    return
    off0:
    bcf	    s0, 0
    movlw   16
    movwf   d0
    movwf   u0
    bsf	    banderas_misc, on_off
    return
blink1:
    btfsc   PIR1, 0
    call    blink1_active
    return
blink1_active:
    reset_timer1
    btfsc   banderas_misc, on_off
    goto    on1
    btfss   banderas_misc, on_off
    goto    off1
    on1:
    bsf	    s1, 0		    ;green light
    call    divide_tiempo1
    bcf	    banderas_misc, on_off
    return
    off1:
    bcf	    s1, 0
    movlw   16
    movwf   d1
    movwf   u1
    bsf	    banderas_misc, on_off
    return
blink2:
    btfsc   PIR1, 0
    call    blink2_active
    return
blink2_active:
    reset_timer1
    btfsc   banderas_misc, on_off
    goto    on2
    btfss   banderas_misc, on_off
    goto    off2
    on2:
    bsf	    s2, 0		    ;green light
    call    divide_tiempo2
    bcf	    banderas_misc, on_off
    return
    off2:
    bcf	    s2, 0
    movlw   16
    movwf   d2
    movwf   u2
    bsf	    banderas_misc, on_off
    return
change_tiempo0:
    movf    tiempo0_temp, 0
    movwf   tiempo_control
    call    divide_tiempo_control
    btfsc   banderas_antirrebote, 7
    call    tiempo_config
    movf    tiempo_control, 0
    movwf   tiempo0_temp
    return
change_tiempo1:
    movf    tiempo1_temp, 0
    movwf   tiempo_control
    call    divide_tiempo_control
    btfsc   banderas_antirrebote, 7
    call    tiempo_config
    movf    tiempo_control, 0
    movwf   tiempo1_temp
    return
change_tiempo2:
    movf    tiempo2_temp, 0
    movwf   tiempo_control
    call    divide_tiempo_control
    btfsc   banderas_antirrebote, 7
    call    tiempo_config
    movf    tiempo_control, 0
    movwf   tiempo2_temp
    return
confirm_changes:
    btfsc   banderas_antirrebote, 7
    call    confirmation
    return
;COUNTDOWN DE LOS SEMÁFOROS
decrease_second:
    decf    disp_time0
    decf    disp_time1
    decf    disp_time2
    movlw   50
    movwf   seconds_delay
    return
;DIVISION A DECENAS Y UNIDADES DE CADA TIEMPO
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
divide_tiempo0:
    movf    s0, 1
    btfss   STATUS, 2		;Esta sección antes de divide_tiempo0 es para que
    goto    divide_tiempo0_on	;no cambie el valor cuando esté apagado por
    return			;el blinking
    divide_tiempo0_on:	
    movlw   0
    movwf   decena
    movwf   unidad
    movf    disp_time0, 0
    call    divide
    movf    decena, 0
    movwf   d0
    movf    unidad, 0
    movwf   u0
    return
divide_tiempo1:
    movf    s1, 0
    btfss   STATUS, 2
    goto    divide_tiempo1_on
    return
    divide_tiempo1_on:
    movlw   0
    movwf   decena
    movwf   unidad
    movf    disp_time1, 0
    call    divide
    movf    decena, 0
    movwf   d1
    movf    unidad, 0
    movwf   u1
    return
divide_tiempo2:
    movf    s2, 0
    btfss   STATUS, 2
    goto    divide_tiempo2_on
    return
    divide_tiempo2_on:
    movlw   0
    movwf   decena
    movwf   unidad
    movf    disp_time2, 0
    call    divide
    movf    decena, 0
    movwf   d2
    movf    unidad, 0
    movwf   u2
    return
    
divide_tiempo_control:
    movlw   0
    movwf   decena
    movwf   unidad
    movf    tiempo_control, 0
    call    divide
    movf    decena, 0
    movwf   dc
    movf    unidad, 0
    movwf   uc
    return

;DISPLAYS DE CADA TIEMPO/SEMAFORO
disp_dc:
    bcf	    PORTD, u2_flag
    bsf	    PORTD, dc_flag
    movf    dc,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, dc_flag
    return
disp_uc:
    bcf	    PORTD, dc_flag
    bsf	    PORTD, uc_flag
    movf    uc,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, uc_flag
    return
disp_d0:
    bcf	    PORTD, uc_flag
    bsf	    PORTD, d0_flag
    movf    d0,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, d0_flag
    return
disp_u0:
    bcf	    PORTD, d0_flag
    bsf	    PORTD, u0_flag
    movf    u0,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, u0_flag
    return
disp_d1:
    bcf	    PORTD, u0_flag
    bsf	    PORTD, d1_flag
    movf    d1,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, d1_flag
    return
disp_u1:
    bcf	    PORTD, d1_flag
    bsf	    PORTD, u1_flag
    movf    u1,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, u1_flag
    return
disp_d2:
    bcf	    PORTD, u1_flag
    bsf	    PORTD, d2_flag
    movf    d2,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, d2_flag
    return
disp_u2:
    bcf	    PORTD, d2_flag
    bsf	    PORTD, u2_flag
    movf    u2,	0
    call    table
    movwf   PORTC
    bcf	    banderas_7seg, u2_flag
    return
disp_s0:
    bcf	    PORTE, s2_flag
    bsf	    PORTE, s0_flag
    movf    s0, 0
    movwf   PORTB
    bcf	    banderas_misc, s0_flag
    return
disp_s1:
    bcf	    PORTE, s0_flag
    bsf	    PORTE, s1_flag
    movf    s1, 0
    movwf   PORTB
    bcf	    banderas_misc,  s1_flag
    return    
disp_s2:
    bcf	    PORTE,  s1_flag
    bsf	    PORTE,  s2_flag
    movf    s2, 0
    movwf   PORTB
    bcf	    banderas_misc,  s2_flag
    return