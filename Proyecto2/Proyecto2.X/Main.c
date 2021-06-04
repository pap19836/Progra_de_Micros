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
uint8_t  servo  =   0;
//|----------------------------------------------------------------------------|
//|------------------------------PROTOTYPES------------------------------------|
//|----------------------------------------------------------------------------|
void setup(void);
void UART_write(unsigned char* word);
void __interrupt() isr(void);
void menu(void);
uint16_t concat_bits(uint16_t x, uint16_t y);
void delay_pulse(uint16_t);
void EEPROM_W(uint8_t address, uint8_t data);
uint8_t EEPROM_R(uint8_t address);
//|----------------------------------------------------------------------------|
//|---------------------------------CODE---------------------------------------|
//|----------------------------------------------------------------------------|

void    main(void){
    setup();
    menu();

    while (1){
 
        GO  =   1;
        __delay_us(50);
        
        DC1B1   =   (uint8_t)pot3 &  2;
        DC1B0   =   (uint8_t)pot3 &  1;
        CCPR1L  =   (uint8_t)(pot3>>2);
        
        
        if(RCIF){
            if(RCREG==115){
                RA4 =   1;  //Encender led
                EEPROM_W(0, 40+(uint8_t)(pot0>>3)); //Guardar posicion servo 0
                __delay_ms(10);
                EEPROM_W(1, 40+(uint8_t)(pot1>>3)); //Guardar posicion servo 1
                __delay_ms(10);
                EEPROM_W(2, 40+(uint8_t)(pot2>>3)); //Guardar posicion servo 2
                UART_write("\nNUEVO Estado Guardado!\n");
                __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
                menu();
            }
            if(RCREG==32){
                RA5 =   1;   //Encender led
                pot0    =(uint16_t)(EEPROM_R(0)-40)<<3;
                pot1    =(uint16_t)(EEPROM_R(1)-40)<<3;
                pot2    =(uint16_t)(EEPROM_R(2)-40)<<3;
                UART_write("\nRegresando a estado\n");
                __delay_ms(1000);//Mostrar por un segundo antes de mostrar menu
                menu();
            }
            if(RCREG==102){
                RA4 =   0;
                RA5 =   0;
                UART_write("\n\nMovimiento Libre Habilitado\n");
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

    //TMR0 config
    TMR0    =   8;
    OPTION_REGbits.PS   =   0b101;
    PSA =   0;
    T0CS    =   0;
    TMR0IF  =   0;
    
//Configure PMW CCP1
    
    TRISCbits.TRISC2   =   1;   //CCP1 are as inputs so they don't change in config
    PR2     =   249;    //PR2 for period of PMW
    CCP1M3  =   1;      //Activate PMW mode of CCP
    CCP1M2  =   1;
    CCPR1L  =   0;     //Start at duty cicle of 0
    
    TMR2IF  =   0;
    T2CON   =   3;          //turn on T2 Prescaler to 1:16
    T2CONbits.TMR2ON =  1;  //Turn on timer 2
    while(TMR2IF==0){   
    }
    TRISC   =   128;
    
    //Interrupt config
    GIE     =   1;
    PEIE    =   1;
    TMR0IE  =   1;
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
    UART_write("\nInstrucciones para control de estado\n");
    __delay_ms(50); //Asegurar que se envíe todo
    UART_write("S - Guardar Estado\nSPACE - Regresar a estado\n");
    __delay_ms(50);
    UART_write("F - Movimiento libre de la garra\n");
}

uint16_t concat_bits(uint16_t x, uint16_t y){
    uint16_t    z    =   0;
    z   =   (x<<2)|(y>>6);      //LS ADRESSH and RS ADRESSL then OR results
    return z;
}

void delay_pulse(uint16_t time){
    while(time>0){
        time--;
        __delay_us(1);
    }
}
void EEPROM_W(uint8_t address, uint8_t data){
    EEADR   =   address;
    EEDATA  =   data;
    EEPGD   =   0;      //Data memory
    WREN    =   1;      //Enable write
    GIE     =   0;      //Disable Interrupts
    while(GIE){         //Confirm desabled interrupts
        GIE =   0;
    }         
    EECON2  =   0x55;    //Process
    EECON2  =   0xAA;    //Process
    WR      =   1;      //Proceed to writing
    GIE     =   1;      //Enable interrupts
    WREN    =   0;      //Desable EEPROM write
}
uint8_t EEPROM_R(uint8_t address){
    uint8_t data;
    EEADR   =   address;    //Point to the desired address
    EEPGD   =   0;      //Data Memory
    RD      =   1;      //Proceed to reading
    data    =   EEDATA;
    return data;
}
//|----------------------------------------------------------------------------|
//|------------------------------INTERRUPTS------------------------------------|
//|----------------------------------------------------------------------------|
void __interrupt() isr(void){
    if  (TMR0IF){
        TMR0    =   8;
        OPTION_REGbits.PS   =   0b101;
        PSA =   0;
        if (servo == 0){
            RD0 =   1;
            delay_pulse(40+(pot0>>3));
            RD0 =   0;
            servo++;
        }
        if (servo == 1){
            RD1 =   1;
            delay_pulse(40+(pot1>>3));
            RD1 =   0;
            servo++;
        }
        if (servo   ==  2){
            RD2 =   1;
            delay_pulse(40+(pot2>>3));
            RD2 =   0;
            servo   =   0;
        }
        TMR0IF  =   0;
    }

     if  (ADIF==1){
         if(!RA5){
            if(CHS0==0 && CHS1==0)  {
                pot0   =   concat_bits(ADRESH, ADRESL);
                CHS0    =   1;      //change to channel 1

            }
            else if(CHS0==1 && CHS1==0)  {
                pot1    =   concat_bits(ADRESH, ADRESL);
                CHS0    =   0;      //change to channel 2
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
         }
        ADIF    =   0;
    }
}