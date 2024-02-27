#include <xc886.h> // XC Board Bibliothek
#include <DIP204_XC886.c>  // Display Funktionen

// Definition der Pins f�r den Ultraschall-Sensor
#define TRIGGER_PIN 2  // P1.2 als Trigger-Pin f�r den Ultraschall-Sender
#define ECHO_PIN 5     // P0.5 als Echo-Pin f�r den Ultraschall-Empf�nger

// Variablen f�r die Entfernungsmessung
unsigned long distance;    // Entfernung in Zentimetern
unsigned long TH;          // Zeit in Timer-Ticks

void init(void);
void wait(int t);
void sendTriggerPulse(void);
void lcd_distance(unsigned long value);

// Hauptfunktion
void main(void)
{
    init();  // Initialisiert die Hardware

    while(1)
    {
        sendTriggerPulse();  // Sendet einen Trigger-Impuls

        // Startet Timer 0 f�r die Zeitmessung
        TH0 = 0;
        TL0 = 0;
        TR0 = 1;
        TF0 = 0;  // Timer-Overflow-Flag zur�cksetzen

        // Warten, bis Timer 0 stoppt -> erfolgt im Interrupt
        while(TR0 == 1);

        // Berechnet die Entfernung basierend auf Timer-Werten
        TH = (TH0 * 256 + TL0) - 5703; // Korrigiert um Offset
        distance = (TH * 80) / 55765; // Umrechnung in Zentimeter

        // Zeigt die Entfernung auf dem LCD an
        lcd_distance(distance);
  			
        wait(50000);  // Wartezeit zwischen den Messungen
    }
}

// Initialisierungsfunktion für Hardware und Timer
void init(void)
{
    lcd_init();              // Initialisiert das LCD
    lcd_clr();               // Löscht das LCD

    P0_DIR = 0x00;           // Konfiguriert Port 0 als Eingang 
    P1_DIR = 0xFF;           // Konfiguriert Port 1 als Ausgang 

    TMOD = 0x11;             // Timer0 und Timer1 als 16-Bit-Z�hler initialisiert

    // Timer 1 f�r die Wartefunktion konfigurieren
    TR1 = 1;                 // Startet Timer 1

    // Externer Interrupt f�r Echo-Pin konfigurieren
    EA = 1;                  // Global Interrupt Enable
    EX0 = 1;                 // External Interrupt 0 Enable
    IT0 = 1;                 // Interrupt 0 auf Edge Triggered einstellen
    EXICON0 = 0x00;          // Interrupt auf fallende Flanke einstellen
}

// Wartefunktion, blockiert für 't' Schleifendurchl�ufe
void wait(int t)
{
		// Eine Schleife entspricht 10uS -> 0xffff - ( 10us - 0.0833us) ==  0xff87
	  // Entspricht allerdings laut Messung ca 15us
    unsigned int i;
    for(i = 0; i < t; i++)
    {
        TH1 = 0xFF;
        TL1 = 0x87;
        while(TF1 == 0);
        TF1 = 0;
    }
}

// Interrupt Service Routine f�r das Echo-Signal
void echo_interrupt() interrupt 0 {
    TR0 = 0;    // Stoppt Timer 0 bei Echo-Empfang
    IRCON0 = 0; // L�scht Interrupt-Anforderung
}

// Funktion zur Ausgabe eines langen Wertes auf dem LCD
void lcd_distance(unsigned long value)
{
    unsigned char i;
	
		lcd_curs(0); // Setzt Cursor zur�ck 
		lcd_clr();
		lcd_str("Abstand ");
	
		if(value > 80)
		{
			lcd_str("zu gross!");
			lcd_curs(20);
			lcd_str("Mehr als 80 cm");
		}
		
		else if(value < 10)
		{
			lcd_str("zu klein!");
			lcd_curs(20);
			lcd_str("Kleiner als 10 cm");
		}
		else 
		{
			i = value / 10; 
			value %= 10;
			if(i != 0) asc_out(i + 0x30);  // Hundertstel
			asc_out(value + 0x30);
			lcd_str(" cm");
		}
		lcd_curs(0); // Setzt Cursor zur�ck 
}

// Funktion zum Senden eines Trigger-Impulses an den Ultraschall-Sender
void sendTriggerPulse(void) {
    P1_DATA = (1 << TRIGGER_PIN);  // Setzt Trigger-Pin High
    wait(1);                       // Kurze Wartezeit
    P1_DATA = ~(1 << TRIGGER_PIN); // Setzt Trigger-Pin Low, beendet den Impuls
}