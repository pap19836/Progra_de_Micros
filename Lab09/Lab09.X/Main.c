// Archivo: main.c
// Dispositivo: PIC16F887
// Autor: Stefano Papadopolo
// Compilador: XC-8 (v2.32)
//
// Programa: ADC
// Hardware: 2 Potenciometros, 2 servomotores
//
// Creado 27 apr, 2021
// Última Actualización: 27 apr, 2021

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

#define _XTAL_FREQ  500000
#include<xc.h>
#include<pic.h>
#include<stdint.h>

//|----------------------------------------------------------------------------|
//|-------------------------------VARIABLES------------------------------------|
//|----------------------------------------------------------------------------|
uint8_t  pot1=0;
uint8_t pulse_width1=0;
uint8_t pot2=0;
uint8_t pulse_width2=0;
//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void __interrupt() isr(void);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|
void    main(void){
    setup();
    while (1){
        GO  =   1;
        __delay_us(10);
        pulse_width1    =   (pot1 >> 3) + 32;
        pulse_width2    =   (pot2 >> 3) + 32;
        DC1B1   =   pulse_width1 &  2;
        DC1B0   =   pulse_width1 &  1;
        CCPR1L  =   pulse_width1 >> 2;
        DC2B1   =   pulse_width2 &  2;
        DC2B0   =   pulse_width2 &  1;
        CCPR2L  =   pulse_width2 >> 2;
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

    OSCCON  =   0b00110000;  //Pic oscilates at 500kHz
    //ADC config
    ADCON1bits.ADFM    =   0;   //Left Justified
    ADCON0  =   0b01000001;     //Fosc/8, CH0, enable
    
    //Configure PMW CCP1
    TRISC   =   6;      //CCP1,CCP2 are as inputs so they don't change in config
    PR2     =   164;    //PR2 for period of PMW
    CCP1M3  =   1;      //Activate PMW mode of CCP
    CCP1M2  =   1;
    CCPR1L  =   32;     //Start at duty cicle of 1/21ms
    
    //configure PMW CCP2
    CCP2M3  =   1;
    CCP2M2  =   1;
    CCPR2L  =   32;
    
    TMR2IF  =   0;
    T2CON   =   3;          //turn on T2 Prescaler to 1:16
    T2CONbits.TMR2ON =  1;  //Turn on timer 2
    while(TMR2IF==0){   
    }
    TRISC   =   0;
    
    //Interrupt Setup
    INTCONbits.GIE  =   1;
    INTCONbits.PEIE =   1;
    PIE1bits.ADIE   =   1;
    
    
    //Port Inicialization
    PORTA   =   0;
    PORTB   =   0;
    PORTC   =   0;
    PORTD   =   0;
    PORTE   =   0;          //Multiplexing Starting point
    
}

//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|

void __interrupt() isr(void){
    if  (ADIF==1){
        if(CHS0==0)  {
            pot1    =   ADRESH;
            CHS0    =   1;      //change to channel 1
        }
        else if(CHS0==1)  {
            pot2    =   ADRESH;
            CHS0    =   0;      //change to channel 0
        }
        ADIF    =   0;
    }
}