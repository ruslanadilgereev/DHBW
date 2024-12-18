/*******************************************************************************************/
/***                     Realisierung des 1-Wire-Delays mit Timer0                       ***/
/*******************************************************************************************/
void ow_delay (unsigned int ns)     //in � Sekunden
                                    //Verwendung von Timer0
{
  unsigned int k;
  for (k=0; k<ns; k++)
  {
  	TR0 = 0;							          //Mit TR0=0 den Timer 0 stoppen - falls er noch l�uft.
  	TF0 = 0;							          //Mit TF0=0 zun�chst das Timer Flag zur�cksetzen.
  	TMOD = 0x11;					          //16 Bit Mode f�r Timer0 und Timer1 ausw�hlen
  	TL0 = (0xffff - 120) % 256; 	    //Register TL0 und TH0 mit entsprechenden Werten laden
  	TH0 = (0xffff - 120) / 256;		  //Startwert 10�s/0,0833�s) = 120 => Laufzeit 10�s

  	TR0 = 1;							          //Mit TR0=1 den Timer 0 starten.

  	while (TF0 == 0);					      //While Schleife mit  Abfrage der Bedingung
   }
}

/*******************************************************************************************/
/***                                      1-Wire-Reset                                   ***/
/*******************************************************************************************/

unsigned char ow_reset(void)
{
    unsigned char zw;
	 
	  DQ = 0;                  // DQ auf Low
    ow_delay(50);            // Min. 480�s Resetimpuls abwarten  
	  DQ = 1;                  // DQ auf High
    P0_DIR = 0x00;           // load direction register P3 0 => Input
	  ow_delay(6);             // 65 �s warten
	  zw = DQ;                 // Zustand DQ einlesen
 	  ow_delay(42);            // 424 us warten = Ende des Reset-Vorgangs	war 124
    P0_DIR = 0xFF;           // load direction register P3 1 => Output
	  return(zw);              // Rueckgabe: 0 => Sensor vorhanden, 1 => kein Sensor vorhanden
}

/*******************************************************************************************/
/***                  Ausgabe eines Bits �ber den 1-Wire-Bus                             ***/
/*******************************************************************************************/

void ow_wr_bit(unsigned char bitwert)
{
    DQ = 0;					         // Start Time Slot: DQ auf Low
                                    
    if(bitwert==1) DQ = 1;   // Bei log�1�: sofort wieder
                             // auf High = nur kurzer Low-Impuls
    ow_delay(10);            // ca. 105 us warten bis	
                             // Ende des Time Slots
    DQ = 1;                  // DQ wieder auf High
}

/*******************************************************************************************/
/***                Einlesen eines Bits �ber den 1-Wire-Bus                              ***/
/*******************************************************************************************/
unsigned char ow_rd_bit(void)
{
    unsigned char zw;

    DQ = 0;                  // DQ auf Low
    DQ = 1;
	  P0_DIR = 0x00;           // load direction register P0 0 = Input
	  ow_delay(1);		     	   // 15 us warten
    zw = DQ;                 // DQ einlesen und speichern
    ow_delay(4);
	  P0_DIR = 0xFF;           // load direction register P0 1 = Output
//  DQ = 1;                  // bis Ende Time Slot
    return(zw);              // R�ckgabe von DQ
}

/*******************************************************************************************/
/***                            Ausgabe eines Bytes �ber den 1-Wire-Bus                  ***/
/*******************************************************************************************/

void ow_wr_byte(unsigned char dat)
{
    unsigned char i;
    unsigned char maske = 1;

    // 8 Bits nacheinander raus schieben, LSB zuerst
    for (i=0; i<8; i++)
    {
        if (dat & maske) ow_wr_bit(1);          // log.�1� senden
        else ow_wr_bit(0);                      // log.�0� senden
        maske = maske * 2;                      // n�chstes Bit selektieren
    }
}

/*******************************************************************************************/
/***                   Einlesen von 8 Bytes �ber den 1-Wire-Bus                          ***/
/*******************************************************************************************/
unsigned char ow_rd_byte(void)
{
    unsigned char i;
    unsigned char wert = 0;
    // 8 Bits hintereinander einlesen, LSB zuerst
    for(i=0; i<8; i++)
    {
        if (ow_rd_bit()) wert |=0x01 << i;
		
		ow_delay(2);
	}
	return(wert);
}

/*******************************************************************************************/
/***          Antwort einlesen: 8 Byte = 64 Bit ins globale Array rom_c[i]               ***/
/*******************************************************************************************/

void ow_rd_rom(void)
{
    unsigned char i;

    for (i=0; i<8; i++)
    {
        rom_c[i] = ow_rd_byte();
    }
	ow_delay(10);
}
