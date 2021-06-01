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
uint16_t pot0    =   0;
uint16_t pot1    =   0;
uint16_t pot2    =   0;
uint16_t pot3    =   0;

//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void UART_write(unsigned char* word);
void __interrupt() isr(void);
void menu(void);
uint16_t concat_bits(uint16_t x, uint16_t y);
void delay_us(uint16_t);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|

void    main(void){
    setup();
    menu();

    while (1){
 
        GO  =   1;
        __delay_us(50);
       
        if(RCIF){
            if(RCREG==115){
            UART_write("\rEstado Guardado!\r");
            __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
            menu();
            }
            if(RCREG==32){
                UART_write("\rRegresando a estado\r");
                __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
                menu();
            }
            if(RCREG==127){
                UART_write("\rEstado Eliminado\rNo hay ningun estado guardado");
                __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
                menu();
            }
        }
    }
}
//|----------------------------------------------------------------------------|
//|------------------------------FUNCTIONS-------------------------------------|
//|----------------------------------------------------------------------------|

void setup(){
    //I/O Setup
    ANSEL   =   0b00001111;
    ANSELH  =   0;
    TRISA   =   0b00001111;
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
    
    //ADC config
    ADCON1bits.ADFM    =   0;   //Left Justified
    ADCON0  =   0b01000001;     //Fosc/8, CH0, enable


    //TMR1 Config
    TMR1ON  =   1;
    TMR1L   =   0b11011111;
    TMR1H   =   0b10110001;
    TMR1IF  =   0;
    
    //Interrupt config
    GIE     =   1;
    PEIE    =   1;
    TMR1IE  =   1;              //TMR1 Interrupt
    ADIE    =   1;              //ADC Interrupt

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

void menu(void){
    UART_write("\rInstrucciones para control de estado\r");
    __delay_ms(50); //Asegurar que se envíe todo
    UART_write("S - Guardar Estado\rSPACE - Regresar a estado\r");
    __delay_ms(50);
    UART_write("DEL - Elminar estado guardado");
}

uint16_t concat_bits(uint16_t x, uint16_t y){
    uint16_t    z    =   0;
    z   =   (x<<2)|(y>>6);      //LS ADRESSH and RS ADRESSL then OR results
    return z;
}

void delay_us(uint16_t time){
    while(time>0){
        time--;
        __delay_us(1);
    }
}

//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|
void __interrupt() isr(void){

    if  (TMR1IF){
        TMR1IF   =   0;
        TMR1L   =   0b11011111;
        TMR1H   =   0b10110001;
        RD0 =   1;
        delay_us(40+(pot0>>3));
        RD0 =   0;
        RD1 =   1;
        delay_us(40+(pot1>>3));
        RD1 =   0;
        RD2 =   1;
        delay_us(40+(pot2>>3));
        RD2 =   0;
    }
    else if  (ADIF==1){
        if(CHS0==0 && CHS1==0)  {
            pot0   =   concat_bits(ADRESH, ADRESL);
            CHS0    =   1;      //change to channel 1
            
        }
        else if(CHS0==1 && CHS1==0)  {
            pot1    =   concat_bits(ADRESH, ADRESL);
            CHS0    =   0;      //change to channel 0
            CHS1    =   1;
        }
        else if(CHS0==0 && CHS1==1)  {
            pot2   =   concat_bits(ADRESH, ADRESL);
            CHS0    =   1;
        }
        else if(CHS0==1 && CHS1==1)  {
            pot3    =   concat_bits(ADRESH, ADRESL);
            CHS0    =   0;      //change to channel 0
            CHS1    =   0;
        }
        
        ADIF    =   0;
    }
}