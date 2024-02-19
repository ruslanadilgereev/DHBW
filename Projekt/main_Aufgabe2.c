#include <xc886.h> // XC Board Bibliothek
#include <DIP204_XC886.c>  // Display Funktionen

// Definition der Pins für den Ultraschall-Sensor
#define TRIGGER_PIN 2  // P1.2 als Trigger-Pin für den Ultraschall-Sender
#define ECHO_PIN 5     // P0.5 als Echo-Pin für den Ultraschall-Empfänger

// Variablen für die Entfernungsmessung
unsigned long distance;    // Entfernung in Zentimetern
unsigned long passed_time; // Zeit in Timer-Ticks
unsigned long passed_ticks; // Zeit in Timer-Ticks
unsigned long t0_ueberlauf; // Überlauf für Messbereichserweiterung

// Eigene Funktionen
void init(void);
void calculate_distance(void);
void wait(int t);
void sendTriggerPulse(void);
void lcd_distance(unsigned long value);

// Hauptfunktion
void main(void)
{
    init();  // Initialisiert die Hardware

		lcd_curs(0); // Setzt Cursor zurück 
		lcd_str("Abstand: ");
	
    while(1)
    {
        sendTriggerPulse();  // Sendet einen Trigger-Impuls
		
        while(TR0 == 1);  // Warten, bis Timer 0 stoppt -> erfolgt im Interrupt
				
				calculate_distance();  // Berechnugn der Distanz
				
				lcd_distance(distance);  // Zeigt die Entfernung auf dem LCD an  
		
        wait(50000);  // Wartezeit zwischen den Messungen
    }
}


// Interrupt Service Routine für das Echo-Signal
void echo_interrupt() interrupt 0 
{
    TR0 = 0;    // Stoppt Timer 0 bei Echo-Empfang
    IRCON0 = 0; // Löscht Interrupt-Anforderung
}


// Interrupt Service Routine für den Überlauf des Timer0
void timer_ueberlauf(void) interrupt 1 
{
		t0_ueberlauf += 65536;  // Addiert die maximale Zählmenge bei einem Überlauf

		TH0 = 0;  // Zurücksetzen des Timer-High-Byte
		TL0 = 0;  // Zurücksetzen des Timer-Low-Byte
}


// Initialisierung der Flags und Bildschirms
void init(void)
{
    lcd_init();              // Initialisiert das LCD
    lcd_clr();               // Löscht das LCD

    P0_DIR = 0x00;           // Konfiguriert Port 0 als Eingang 
    P1_DIR = 0xFF;           // Konfiguriert Port 1 als Ausgang 

    TMOD = 0x11;             // Timer0 und Timer1 als 16-Bit-Zähler initialisiert
    TR1 = 1;                 // Startet Timer 1

    EA = 1;                  // Global Interrupt Enable
    EX0 = 1;                 // External Interrupt 0 Enable
	  ET0 = 1;                 // Interrupt Timer0 Enable
    IT0 = 1;                 // Interrupt 0 auf Edge Triggered einstellen
    EXICON0 = 0x00;          // Interrupt auf fallende Flanke einstellen
}


// Berechnet die Entfernung basierend auf Timer-Werten
void calculate_distance(void) 
{
		passed_ticks = t0_ueberlauf + (TH0 * 256 + TL0) - 5697;  // Korrigiert um Offset: Zeit zwischen Trigger Signal und Echo High
		passed_time = passed_ticks * 43;
		distance = passed_time / 30000;  // Umrechnung in Zentimeter
	
		t0_ueberlauf = 0;  // Zurücksetzen des Überlaufs
}


// Wartefunktion, blockiert für 't' Schleifendurchläufe
void wait(int t)
{
    unsigned int i;
    for(i = 0; i < t; i++)
    {
        TH1 = 0xFF;
        TL1 = 0x87;  // Eine Schleife entspricht 10uS -> 0xffff - ( 10us - 0.0833us) ==  0xff87 ; Entspricht allerdings laut Messung ca 15us
        while(TF1 == 0);  // Wartet auf Timer-Flag
        TF1 = 0;  // Setzt Timer-Flag zurück
    }
}


// Funktion zum Senden eines Trigger-Impulses an den Ultraschall-Sender
void sendTriggerPulse(void) 
{
		TH0 = 0;  //
		TL0 = 0;  // Zur
	
		P1_DATA = (1 << TRIGGER_PIN);  // Setzt Trigger-Pin High
    wait(1);                       // Kurze Wartezeit
    P1_DATA = ~(1 << TRIGGER_PIN); // Setzt Trigger-Pin Low, beendet den Impuls

		TR0 = 1;  // Startet Timer 0 für die Zeitmessung
}



// Funktion zur Ausgabe eines langen Wertes auf dem LCD
void lcd_distance(unsigned long value)
{
    unsigned char i;
		
		lcd_curs(9); // Setzt Cursor zurück 
	
		i = value / 100; 
		value %= 100;
    if(i!=0) asc_out(i + 0x30);  // Hundertstel

    i = value / 10; 
		value %= 10;
    asc_out(i + 0x30);  // Zehner

    value += 0x30;
    asc_out((char)value);  // Einer
	
		lcd_str(" cm  ");
		lcd_curs(9); // Setzt Cursor zurück 
}






