// Archivo: main.c
// Dispositivo: PIC16F887
// Autor: Stefano Papadopolo
// Compilador: XC-8 (v2.32)
//
// Programa: Introducción a C
// Hardware: 12 Leds, 8 displays de 7 segmentos y 3 push-buttons
//
// Creado 13 apr, 2021
// Última Actualización: 13 apr, 2021

// CONFIG1
#pragma config FOSC = INTRC_NOCLKOUT// Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
#pragma config WDTE = OFF       // Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
#pragma config PWRTE = OFF      // Power-up Timer Enable bit (PWRT disabled)
#pragma config MCLRE = ON       // RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
#pragma config CP = OFF         // Code Protection bit (Program memory code protection is disabled)
#pragma config CPD = OFF        // Data Code Protection bit (Data memory code protection is disabled)
#pragma config BOREN = ON       // Brown Out Reset Selection bits (BOR enabled)
#pragma config IESO = ON        // Internal External Switchover bit (Internal/External Switchover mode is enabled)
#pragma config FCMEN = ON       // Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is enabled)
#pragma config LVP = ON         // Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

// CONFIG2
#pragma config BOR4V = BOR40V   // Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
#pragma config WRT = OFF        // Flash Program Memory Self Write Enable bits (Write protection off)

// #pragma config statements should precede project file includes.
// Use project enums instead of #define for ON and OFF.

#define _XTAL_FREQ 4000000
#include<xc.h>
#include<pic.h>
#include<stdint.h>
#include<stdio.h>
#include<stdlib.h>
//|----------------------------------------------------------------------------|
//|-------------------------------VARIABLES------------------------------------|
//|----------------------------------------------------------------------------|
unsigned char centena;
unsigned char decena;
unsigned char unidad;
unsigned char display[10];
unsigned char banderas_7seg;


//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void reset_timer0(void);
void __interrupt() isr(void);
void divide(unsigned char *a, unsigned char *b, unsigned char *c);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|

void    main(void){
    setup();
    while (1){
        divide(&centena, &decena, &unidad);
        /*if(PORTA==1){
            
            PORTD=display[centena];
        }
        else if(PORTA==2){
            PORTD=display[decena];
        }
        else if(PORTA==4){
            PORTD=display[unidad];
        }
    */
    }
}
//|----------------------------------------------------------------------------|
//|------------------------------FUNCTIONS-------------------------------------|
//|----------------------------------------------------------------------------|

void setup(){
    //I/O Setup
    ANSEL   =   0;
    ANSELH  =   0;
    TRISA   =   0;
    TRISB   =   0;
    TRISC   =   0;
    TRISD   =   0;
    TRISE   =   0;
    TRISBbits.TRISB0    =   1;
    TRISBbits.TRISB1    =   1;
    OPTION_REGbits.nRBPU    =   0;
    WPUBbits.WPUB0  =   1;
    WPUBbits.WPUB1  =   1;
    
    //Interrupt Setup
    INTCONbits.GIE  =   1;
    INTCONbits.T0IF =   0;
    INTCONbits.RBIF =   0;
    INTCONbits.RBIE =   1;
    INTCONbits.T0IE =   1;
    IOCBbits.IOCB0  =   1;
    IOCBbits.IOCB1  =   1;
    
    //Set Timer0
    INTCONbits.T0IF     =   0;
    TMR0                =   8;
    OPTION_REGbits.T0CS =   0;
    OPTION_REGbits.PS   =   0;
    OPTION_REGbits.PS0  =   0;
    OPTION_REGbits.PS1  =   1;
    OPTION_REGbits.PS2  =   1;
    
    //Port Inicialization
    PORTA   =   1;
    PORTB   =   0;
    RB0     =   1;
    RB1     =   1;
    PORTC   =   15;
    PORTD   =   0;
    PORTE   =   0;
    //7seg display options
    display[0]=0b00111111;
    display[1]=0b00000110;
    display[2]=0b01011011;
    display[3]=0b01001111;
    display[4]=0b01100110;
    display[5]=0b01101101;
    display[6]=0b01111101;
    display[7]=0b00000111;
    display[8]=0b01111111;
    display[9]=0b01100111;
}
void reset_timer0(void){
    INTCONbits.T0IF     =   0;
    TMR0                =   8;
    OPTION_REGbits.T0CS =   0;
    OPTION_REGbits.PS   =   0;
    OPTION_REGbits.PS0  =   0;
    OPTION_REGbits.PS1  =   1;
    OPTION_REGbits.PS2  =   1;
}
void divide(unsigned char *a, unsigned char *b, unsigned char *c){
    *a=PORTC/100;
    *b=(PORTC-centena)/10;
    *c=PORTC-100*centena-10*decena;
    
}

//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|

void __interrupt() isr(void){
    if  (T0IF==1){
        reset_timer0();
        switch(PORTA){
            case 1:
                RA0=0;
                PORTD=display[decena];
                RA1=1;
                RA2=0;
                break;
            
            case 2:
                RA1=0;
                PORTD=display[unidad];
                RA2=1;
                RA0=0;
                break;
                
            case 4:
                RA2=0;
                PORTD=display[centena];
                RA0=1;
                RA1=0;
                break;
            
        }
        T0IF    =   0;
    }
    if  (RBIF==1){
        if  (RB0==0){
            PORTC++;
            RBIF = 0;
        }
        else if(RB1==0){
            PORTC--;
            RBIF = 0;
        }
        else{
            RBIF = 0;
        }
    }
}