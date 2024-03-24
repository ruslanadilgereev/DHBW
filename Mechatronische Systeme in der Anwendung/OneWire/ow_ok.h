/********************************************************************************************/
/*                                                                                          */
/*                                                                                          */
/*     1-Wire-Bus:   Header-Datei zur C-Source-Code-Datei ´DS18S20_LCD.c                    */
/*                                                                                          */
/*                                                                                          */
/*     Autore :           M. Wuehrl   .                                                     */
/*                                                                                          */
/*     Zielsystem:        8051er-Mikrocontroller, hier: CL886 (Infineon)                    */
/*                                                                                          */
/*                                                                                          */
/*                                                                                          */
/*     IDE/C-Compiler:    Keil                                                              */
/*                                                                                          */
/*     Letzte Änderung:   24.04.2010                                                        */
/*                                                                                          */
/*     Datei:             ow.h                                                              */
/*                                                                                          */
/********************************************************************************************/

#ifndef  _ow_H_
  
  #define  _ow_H_

        // Port-Pin zur Realisierung des 1-Wire-Busses
        sbit DQ =  P0_DATA^4;      // Port-Pin P0.4


        // Gloable Variablen
        unsigned char rom_c[8];             // Array zur Aufnahme des ROM-Codes
		    unsigned int i,Temperatur,k;

        /****************************/
	      /*** Funktions-Prototypen ***/
        /****************************/

        /*** Realisierung des 1-Wire-Delays ***/
        extern void ow_delay(unsigned int ns);

        /*** 1-Wire-Reset ***/
        extern unsigned char ow_reset(void);

        /*** Ausgabe eines Bits über den 1-Wire-Bus ***/
        extern void ow_wr_bit(unsigned char bitwert);

        /*** Einlesen eines Bits über den 1-Wire-Bus ***/
        extern unsigned char ow_rd_bit(void);

        /*** Ausgabe eines Bytes über den 1-Wire-Bus ***/
        extern void ow_wr_byte(unsigned char dat);

        /*** Einlesen eines Bytes über den 1-Wire-Bus ***/
        extern unsigned char ow_rd_byte(void);

        /*** Lesen des 64-Bit-ROM-Identifiers ***/
        extern void ow_rd_rom(void);

		/*** Initialisieren der Ports  ***/
		extern void init_port3(void);

		/*** Initialisieren LCD ***/
		extern void init_LCD(void);

		/*** Anzeige der Temperatur dezimal in der 4. Zeile des LCD ***/
		extern void anzeige(void);

		/*** Ausgabe des Scratch-Pad an den Port_P3 LEDs ***/
		extern void Ausgabe_Temp(void);
		
		/*** Ausgabe des ROM Identifiers auf dem LCD ***/
		extern void Ausgabe_ROM(void);

		/*** Warteschleife ***/
		extern void warten(unsigned int ms);

		/*** LCD-Routinen aus dem File lcd800.c ***/
		extern void lcd_init(void);	    	// Init LCD
		extern void lcd_clr(void);	 		// LCD Löschen 
		extern void lcd_str(char *ptr); 	// Ausgabe String
		extern void lcd_curs(char);	    	// Cursor setzen
		extern void asc_out(char);	    	// Ausgabe eines ASCII Zeichens
		extern void lcd_int(unsigned int);  // Ausgabe Int Wert => 4 stellig
		extern void lcd_byte(char);  		// Ausgabe unsigned char  => 3 stellig

#endif
