// Archivo: main.c
// Dispositivo: PIC16F887
// Autor: Stefano Papadopolo
// Compilador: XC-8 (v2.32)
//
// Programa: EUSART
// Hardware: 16 Leds, virtual terminal
//
// Creado 4 may, 2021
// Última Actualización: 9 may, 2021

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

//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void UART_write(unsigned char* word);
void __interrupt() isr(void);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|

void    main(void){
    setup();
    while (1){
 
        UART_write("\rQue desea Hacer\r(1)Desplegar Cadena de Caracteres\r");
        __delay_ms(50); //Asegurar que se envíe todo
        UART_write("(2)Cambiar PORTA\r(3)Cambiar PORTB\r");
        while(!RCIF){
            __delay_us(1);  //Loop until RCIF is set (get an instruction)
        }
        if(RCREG==49){
            UART_write("Prueba cadena de caracteres\r");
            __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu 
        }
        if(RCREG==50){
            UART_write("\rIndique el valor para PORTA\r");
            while(!RCIF){
                __delay_us(1);  //Loop until RCIF is set (get an instruction)
            }
            PORTA   =   RCREG;
            __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
        }
        if(RCREG==51){
            UART_write("Indique el valor para PORTB\r");
            while(!RCIF){
                __delay_us(1);  //Loop until RCIF is set (get an instruction)
            }
            PORTB   =   RCREG;
            __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
        }
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
    TRISC   =   128;
    TRISD   =   0;
    TRISE   =   0;

    //Config Transmitter
    TXSTAbits.TXEN  =   1;      //habilitar tranmision
    TXSTAbits.SYNC  =   0;      //asincrono
    RCSTAbits.SPEN  =   1;      //enable serial port
    TXSTAbits.BRGH  =   1;      //high baud rate
    BRG16   =   0;
    SPBRGH  =   0;              //Calibrate SPBRGH:SPBRG for desired BaudRate
    SPBRG   =   25;
    
    //Config Reciever
    RCSTAbits.CREN  =   1;      //Habilitar reciever
    //Port Inicialization
    PORTA   =   0;
    PORTB   =   0;
    PORTC   =   0;
    PORTD   =   0;
    PORTE   =   0;
}
       
void UART_write(unsigned char* word){   
    while (*word != 0){                 //Loop until NULL
        TXREG = (*word);                //Send current array value pointed
        while(!TXSTAbits.TRMT);         //Make sure TSR is full (value sent)
        word++;                         //Go to next value in the array
    }
}
//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|
