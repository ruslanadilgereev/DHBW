#include <xc886.h> // XC Board Bibliothek
#include <DIP204_XC886.c>  // Display Funktionen

// Definition der Pins f�r den Ultraschall-Sensor
#define TRIGGER_PIN 2  // P1.2 als Trigger-Pin f�r den Ultraschall-Sender
#define ECHO_PIN 5     // P0.5 als Echo-Pin f�r den Ultraschall-Empf�nger

// Variablen f�r die Entfernungsmessung
unsigned long distance;    // Entfernung in Zentimetern
unsigned long passed_time; // Zeit in Timer-Ticks
unsigned long passed_ticks; // Zeit in Timer-Ticks
unsigned long t0_ueberlauf; // �berlauf f�r Messbereichserweiterung

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
		
    while(1)
    {
        sendTriggerPulse();     // Sendet einen Trigger-Impuls
		
        while(TR0 == 1);        // Warten, bis Timer 0 stoppt -> erfolgt im Interrupt
				
		calculate_distance();   // Berechnugn der Distanz
		
		lcd_distance(distance); // Zeigt die Entfernung auf dem LCD an  

        wait(50000);            // Wartezeit zwischen den Messungen
    }
}


// Interrupt Service Routine f�r das Echo-Signal
void echo_interrupt() interrupt 0 
{
    TR0 = 0;    // Stoppt Timer 0 bei Echo-Empfang
    IRCON0 = 0; // L�scht Interrupt-Anforderung
}


// Interrupt Service Routine f�r den �berlauf des Timer0
void timer_ueberlauf(void) interrupt 1 
{
		t0_ueberlauf += 65536;  // Addiert die maximale Z�hlmenge bei einem �berlauf
}


// Initialisierung der Flags und Bildschirms
void init(void)
{
    lcd_init();              // Initialisiert das LCD
    lcd_clr();               // Löscht das LCD

    P0_DIR = 0x00;           // Konfiguriert Port 0 als Eingang 
    P1_DIR = 0xFF;           // Konfiguriert Port 1 als Ausgang 

    TMOD = 0x11;             // Timer0 und Timer1 als 16-Bit-Z�hler initialisiert
    TR1 = 1;                 // Startet Timer 1

    EA = 1;                  // Global Interrupt Enable
    EX0 = 1;                 // External Interrupt 0 Enable
	ET0 = 1;                 // Interrupt Timer0 Enable
    IT0 = 0;                 // Interrupt 0 auf Edge Triggered einstellen
    //EXICON0 = 0x00;          // Interrupt auf fallende Flanke einstellen
}


// Berechnet die Entfernung basierend auf Timer-Werten
void calculate_distance(void) 
{
		passed_ticks = t0_ueberlauf + (TH0 * 256 + TL0) - 5703;  // Korrigiert um Offset: Zeit zwischen Trigger Signal und Echo High
		passed_time = passed_ticks * 43; // 
		distance = passed_time / 30000;  // Umrechnung in Zentimeter
	
		t0_ueberlauf = 0;  // Zur�cksetzen des �berlaufs
}


// Wartefunktion, blockiert für 't' Schleifendurchl�ufe. Ein Schleifendurchlauf entspricht 15uS.
void wait(int t)
{
    unsigned int i;
    for(i = 0; i < t; i++)
    {
        TH1 = 0xFF;
        TL1 = 0x87;  // Eine Schleife entspricht 10uS -> 0xffff - ( 10us - 0.0833us) ==  0xff87 ; Entspricht allerdings laut Messung ca 15us
        while(TF1 == 0);  // Wartet auf Timer-Flag
        TF1 = 0;  // Setzt Timer-Flag zur�ck
    }
}


// Funktion zum Senden eines Trigger-Impulses an den Ultraschall-Sender
void sendTriggerPulse(void) 
{
	TH0 = 0;  // Timer 0 zurücksetzen
	TL0 = 0;  // Timer 0 zurücksetzen

	P1_DATA = (1 << TRIGGER_PIN);  // Setzt Trigger-Pin High
    wait(1);                       // Kurze Wartezeit
    P1_DATA = ~(1 << TRIGGER_PIN); // Setzt Trigger-Pin Low, beendet den Impuls

	TR0 = 1;  // Startet Timer 0 f�r die Zeitmessung
}



// Funktion zur Ausgabe eines langen Wertes auf dem LCD
void lcd_distance(unsigned long value)
{
    unsigned char i, j;
		lcd_curs(0); // Setzt Cursor zur�ck 
		lcd_clr();
		lcd_str("Abstand ");
		//lcd_curs(8); // Setzt Cursor zur�ck 
	
		if(value > 300)
		{
			lcd_str("zu gross!");
			lcd_curs(20);
			lcd_str("Mehr als 3m");
		}
		
		else if(value < 3)
		{
			lcd_str("zu klein!");
			lcd_curs(20);
			lcd_str("Kleiner als 3cm");
		}
		
		else
		{ 
			i = value / 100; 
			value %= 100;
			if(i != 0) asc_out(i + 0x30);  // Hundertstel

			j = value / 10; 
			value %= 10;
			if(j != 0 || (j == 0 && i != 0)) asc_out(j + 0x30);  // Zehner, korrigiert: ausgegeben nur wenn j nicht 0

			value += 0x30;
			asc_out((char)value);  // Einer

			lcd_str(" cm");
		}
		
}


