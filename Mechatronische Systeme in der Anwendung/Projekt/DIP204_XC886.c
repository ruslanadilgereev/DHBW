//******************************************************************
// LCD-Funktionen für XC886 Board
// R. Birk Mai 07 
// Ansteuerung LCD-Display seriell (4 * 20 Zeichen LCD) 
// Filename: lcd_XC886.c
//******************************************************************
#include <xc886clm.h>

void lcd_init(void);		// Init LCD
void lcd_clr(void);	 		// LCD Löschen 
void lcd_byte(char);  		// Ausgabe unsigned char  => 3 stellig
void lcd_str(char *ptr);	// Ausgabe String
void lcd_curs(char);		// Cursor setzen
void wait_bsy1(void);  		// kurz warten
void wait_bsy2(void); 		// lang warten
void asc_out(char);	   		// Ausgabe eines ASCII Zeichens
void lcd_int(unsigned int);	// Ausgabe Int Wert => 4 stellig
void send_byte(unsigned char,unsigned char);
// Anschluss des Displays an:
sbit sclk = P1_DATA^6;	// Clock Anschluss LCD
sbit sid = P1_DATA^5;	// seriell Input LCD

//******************************************************************
// Sende ein Byte zum Display, senddate ist Bytewert
// rs => Command = 0 und Data = 1
void send_byte(unsigned char senddata, unsigned char rs)
{	 
	unsigned char i;
	unsigned long sendwert, zw;
	zw = (unsigned long)senddata;   // Typconvertierung
	sendwert = 0x001f + ((zw & 0xf0)<<12) + ((zw&0x0f)<<8);
	if (rs == 1) sendwert = sendwert + 0x40;
	for (i = 0; i<24;i++)	// serielle Ausgabe von 24Bit
	{  	sclk = 0;
		if ((sendwert & 0x00000001) == 0)sid = 0;
		else sid = 1;
		sclk = 1;
		sendwert = sendwert >> 1;
	}
}
void wait_bsy1(void)	// ca. 50 us warten
{      
	unsigned int zaehler ;
	for (zaehler = 0; zaehler < 0xaf; zaehler++);
}
void wait_bsy2(void)	  // ca. 1.6 ms warten
{      
	unsigned int zaehler ;
	for (zaehler = 0; zaehler < 0xaff; zaehler++);
}
void lcd_init (void)
{ 	// P1 auf Ausgabe
	SFR_PAGE(_pp1, noSST);     	// switch to page 1
  	P1_PUDSEL = 0xFF;         	// load pullup/pulldown select register
  	P1_PUDEN = 0x00;        	// load pullup/pulldown enable register

  	SFR_PAGE(_pp0, noSST);      // switch to page 0
  	P1_DIR = P1_DIR | 0x60;		// load direction register	=> P1.6 und P1.5 => out
	wait_bsy2();
	wait_bsy2();
	 // LCD Init
	send_byte(0x34,0); 			// 8 Bit Mode
	wait_bsy2();
	send_byte(0x09,0); 			// 4 Zeilen Mode
	wait_bsy2();
	send_byte(0x30,0); 			// 8 Bit Datenläge
	wait_bsy2();
	send_byte(0x0f,0); 			// display ein , Cursor ein
	wait_bsy2();
	send_byte(0x01,0); 			// clear Display
	wait_bsy2();
	send_byte(0x07,0); 			// Cursor autoincremet
	wait_bsy2();
	

}
void lcd_clr(void)
{   send_byte( 01 ,0);  // CLR Befehl
	wait_bsy2();
	send_byte( 0x0e ,0); // Cursor on
	wait_bsy1();
}
void asc_out(unsigned char zeichen)
{
	send_byte(zeichen,1);
	wait_bsy1();
	wait_bsy1();
}
void lcd_str(char *ptr)
{ 
	unsigned char i=0;
	while (*ptr != 0 )
	{ 
		asc_out(*ptr);
	  	ptr++;
	  	i++;
	  	if (i == 20) lcd_curs(20);
	  	if (i == 40) lcd_curs(40);
	  	if (i == 60) lcd_curs(60);
	}
}
void lcd_byte(unsigned char wert)
{
	unsigned char i;

	i = wert / 100;
	wert %= 100;
	i += 0x30;
	asc_out(i);
	i = wert / 10;
	wert %= 10 ;
	i += 0x30;
	asc_out(i);
	wert += 0x30;
	asc_out(wert);
}
void lcd_int(unsigned int wert_16)
{	// Ausgabe von 0 bis 9999 !!!!
	unsigned char i;
	
	i = wert_16 / 1000; // Anzahl 1000er
	wert_16 %= 1000;	// Rest nach 1000er Division
	asc_out(i+0x30);    // Ausgabe als ASCII Zeichen
    i= wert_16 / 100;
	wert_16 %= 100;
	asc_out(i+0x30);
	i = wert_16 / 10;
	wert_16 %= 10;
    asc_out(i+0x30);
	wert_16 += 0x30;
	asc_out((char)wert_16);
}
void lcd_curs(unsigned char pos)
{
	pos %=80;
	if ( pos < 20)  send_byte( pos +0x80 ,0);	 // 1. Zeile 
	if (( pos >= 20) && (pos < 40))send_byte( pos -20 + 0x20 + 0x80 ,0);
	if (( pos >= 40) && (pos < 60))send_byte( pos -40 + 0x40 + 0x80 ,0);
	if (( pos >= 60) && (pos < 80))send_byte( pos -60 + 0x60 + 0x80 ,0);	
	
	wait_bsy1();
	wait_bsy1();		
}


	
