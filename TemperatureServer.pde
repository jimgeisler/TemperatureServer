#include <SPI.h>
#include <OneWire.h>

/*
 * Web Server
 *
 * A simple web server that shows the temperature of a connected One Wire thermo sensor (DS18B20).
 */

#include <Ethernet.h>

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192, 168, 0, 170 };

#define STRING_BUFFER_SIZE 128
char buffer[STRING_BUFFER_SIZE];

Server server(80);

OneWire  ds(9);  // on pin 9
int HighByte, LowByte, TReading, SignBit, Tc_100, Whole, Fract, Tf;

void setup()
{
  
  Ethernet.begin(mac, ip);
  server.begin();
  
  //For logging
  Serial.begin(9600);
}

void loop()
{
  Client client = server.available();
  if (client) {
    readHTTPRequest(client);

    // give the web browser time to receive the data
    delay(1);
    client.stop();
  }
}

void updateTemperature()
{
  byte i;
  byte present = 0;
  byte data[12];
  byte addr[8];
  
  if ( !ds.search(addr)) {
    Serial.print("No more addresses.\n");
    ds.reset_search();
    delay(250);
    return;
  }

  // check for a valid crc
  if ( OneWire::crc8( addr, 7) != addr[7]) {
      Serial.print("CRC is not valid!\n");
      return;
  }
  
  // make sure it looks like a ds18s20 one wire thermo sensor
  if ( addr[0] != 0x28) {
      Serial.print("Device is not a DS18S20 family device.\n");
      return;
  }

  ds.reset();
  ds.select(addr);
  ds.write(0x44,1);
  
  delay(1000);
  
  present = ds.reset();
  ds.select(addr);    
  ds.write(0xBE);

  for ( i = 0; i < 9; i++) {           // we need 9 bytes
    data[i] = ds.read();
  }
  
  LowByte = data[0];
  HighByte = data[1];
  TReading = (HighByte << 8) + LowByte;
  SignBit = TReading & 0x8000;  // test most sig bit
  if (SignBit) // negative
  {
    TReading = (TReading ^ 0xffff) + 1; // 2's comp
  }
  Tc_100 = (6 * TReading) + TReading / 4;    // multiply by (100 * 0.0625) or 6.25

  Tf = Tc_100 * 9 / 5 + 3200;

  Whole = Tf / 100;  // separate off the whole and fractional portions
  Fract = Tf % 100;

}

void readHTTPRequest(Client client) {
  char c;
  int i;

  int bufindex = 0; // reset buffer

  // reading all rows of header
  if (client.connected() && client.available()) { // read a row
    buffer[0] = client.read();
    buffer[1] = client.read();
    bufindex = 2;
    // read the first line to determinate the request page
    while (buffer[bufindex-2] != '\r' && buffer[bufindex-1] != '\n') { // read full row and save it in buffer
      c = client.read();
      if (bufindex<STRING_BUFFER_SIZE) buffer[bufindex] = c;
      bufindex++;
    }

    // Shows the request
    Serial.println(buffer);

    if ((strncmp(buffer, "GET /temp/", 10) == 0) || (strncmp(buffer, "GET /temp", 9) == 0)) {
      updateTemperature();
      printTemperature(client);
    } else {
      client.println("HTTP/1.1 200 OK");
      client.println("Content-Type: text/html");
      client.println();
      client.println("found me");
    }

    // clean buffer for next row
    bufindex = 0;
  }
}

void printTemperature(Client client)
{
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: application/json");
    client.println();
    client.print("{'temp':");
    if (SignBit)
    {
      client.print("-");
    }
    client.print(Whole);
    client.print(".");
    if (Fract < 10)
    {
       client.print("0");
    }
    client.print(Fract);
    client.println("}");
}


