// Archivo: main.c
// Dispositivo: PIC16F887
// Autor: Stefano Papadopolo
// Compilador: XC-8 (v2.32)
//
// Programa: ADC
// Hardware: 8 Leds, 2 Potenciometros, 3 7segmentos
//
// Creado 20 apr, 2021
// Última Actualización: 20 apr, 2021

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

#define _XTAL_FREQ  4000000
#include<xc.h>
#include<pic.h>
#include<stdint.h>


//|----------------------------------------------------------------------------|
//|-------------------------------VARIABLES------------------------------------|
//|----------------------------------------------------------------------------|
uint8_t centena =   0;
uint8_t decena  =   0;
uint8_t unidad  =   0;
uint8_t pot2    =   0;
uint8_t flag_7seg=  0;
uint8_t display[10];

//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void reset_timer0(void);
void __interrupt() isr(void);
void divide(uint8_t *a, uint8_t *b, uint8_t *c);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|

void    main(void){
    setup();
    while (1){
        GO  =   1;
        divide(&centena, &decena, &unidad);
        __delay_us(10);
        
    switch(flag_7seg){
            case 0:
                RE0=0;
                PORTD=display[decena];
                RE1=1;
                RE2=0;
                break;

            case 1:
                RE1=0;
                PORTD=display[unidad];
                RE2=1;
                RE0=0;
                break;
                
            case 2:
                RE2=0;
                PORTD=display[centena];
                RE0=1;
                RE1=0;
                break;
            
        }
    }
}
//|----------------------------------------------------------------------------|
//|------------------------------FUNCTIONS-------------------------------------|
//|----------------------------------------------------------------------------|

void setup(){
    //I/O Setup
    ANSEL   =   3;          //RA0 y RA1 son analogicos
    ANSELH  =   0;
    TRISA   =   3;          //RA0 y RA1 inputs
    TRISB   =   0;
    TRISC   =   0;
    TRISD   =   0;
    TRISE   =   0;

    //ADC config
    ADCON1bits.ADFM    =   0;   //Left Justified
    ADCON0  =   0b01000001;     //Fosc/8, CH0, enable
    
    //Interrupt Setup
    INTCONbits.GIE  =   1;
    INTCONbits.T0IF =   0;
    INTCONbits.T0IE =   1;
    INTCONbits.PEIE =   1;
    
    
    
    //Set Timer0
    INTCONbits.T0IF     =   0;
    TMR0                =   8;
    OPTION_REGbits.T0CS =   0;
    OPTION_REGbits.PS   =   0;
    OPTION_REGbits.PS0  =   0;
    OPTION_REGbits.PS1  =   1;
    OPTION_REGbits.PS2  =   1;
    
    //Port Inicialization
    PORTA   =   0;
    PORTB   =   0;
    PORTC   =   0;
    PORTD   =   0;
    PORTE   =   1;          //Multiplexing Starting point
    
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
void divide(uint8_t *a, uint8_t *b, uint8_t *c){
    *a=pot2/100;
    *b=(pot2-100*centena)/10;
    *c=pot2-100*centena-10*decena;
    
}

//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|

void __interrupt() isr(void){
    if  (T0IF==1){              // Multiplexer rotate from 0 to 2
        reset_timer0();
        flag_7seg ++;
        if  (flag_7seg==3){
            flag_7seg=0;
        }
        T0IF    =   0;
    }
    if  (ADIF==1){
        if(CHS0==0)  {
            PORTC   =   ADRESH;
            CHS0    =   1;      //change to channel 1
        }
        else if(CHS0==1)  {
            pot2    =   ADRESH;
            CHS0    =   0;      //change to channel 0
        }
        ADIF    =   0;
    }
}