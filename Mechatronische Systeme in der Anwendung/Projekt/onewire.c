#include <xc886.h> // XC Board Bibliothek
#include <ow_ok.h> // OneWire Bibliothek
#include <stdio.h>

unsigned int temp;
unsigned int temp_z;
// Wartefunktion, blockiert für 't' Schleifendurchl?ufe. Ein Schleifendurchlauf entspricht 15uS.
void wait(int t)
{
    unsigned int i;
    for(i = 0; i < (t*100); i++)
    {
        TH1 = 0xFF;
        TL1 = 0x87;  // Eine Schleife entspricht 10uS -> 0xffff - ( 10us - 0.0833us) ==  0xff87 ; Entspricht allerdings laut Messung ca 15us
        while(TF1 == 0);  // Wartet auf Timer-Flag
        TF1 = 0;  // Setzt Timer-Flag zur?ck
    }
}


void main(void)
{
	lcd_init();
	lcd_clr();
	lcd_curs(0);
	
	TMOD = 0x11;
	TR1 = 1;
	lcd_str("Temperatur: ");
	while(1)
	{
		lcd_curs(12);
		// 1 Wirte Reset Funktion
		ow_reset();
		
		// Skip ROM Befehl 0xCC
		ow_wr_byte(0xCC);
		
		// Start Temperaturwandlung Befehl 0x44
		ow_wr_byte(0x44);
		
		// Wait 750ms
	  wait(30000);
		
		// Resetpuls Master
		ow_reset();
		
		// Presence Puls vom Slave
		
		ow_wr_byte(0xCC); // Skip ROM Befehl 0xCC
		ow_wr_byte(0xBE); // Read Scratchpad Befehl 0xBE (9 Bytes)
		
		ow_rd_rom();
		temp = rom_c[0] / 2;
		asc_out(temp/10 + 0x30);
		asc_out(temp%10 + 0x30);
		lcd_str(",");
		temp_z = rom_c[0]%2*5;
		asc_out(temp_z + 0x30);
		asc_out(260);
		asc_out(67);
	}
	
}
