# I, Pablo Duboue, dedicate this work to the public domain (CC0 1.0)


extern "C" {
	#include <avr/pgmspace.h>
	#include <inttypes.h>
	#include "wiring_private.h"
	#include "WConstants.h"
	
	#include <HardwareSerial.h>
}

#ifndef staticPrint_H
#define staticPrint_H

#ifndef SPrint
	#define SPrint(str)			SPrint_P(PSTR(str))
#endif

#ifndef SPrintln
	#define SPrintln(str)		SPrintln_P(PSTR(str))
#endif

static inline void SPrint_P(const char *data)
{
    char ch;

    for (;;) {
        ch = pgm_read_byte( data++ );
        if ( !ch ) return;
#if defined(__AVR_ATmega8__)
		while (!(UCSRA & (1 << UDRE)))
			;

		UDR = ch;
#else
		while (!(UCSR0A & (1 << UDRE0)))
			;

		UDR0 = ch;
#endif
    }
}

static inline void SPrintln_P(const char *data)
{
	SPrint_P(data);
	SPrint_P(PSTR("\r\n"));
}

#endif

#include <EEPROM.h>


// #define SPrint(data) Serial.print(data);

// constants won't change. They're used here to 
// set pin numbers:
const int buttonRockPin = 2;
const int buttonPaperPin = 3;
const int buttonScissorsPin = 4;
const int buttonPlayPin = 5;
// const int ledPin =  13;

const unsigned int MAX_INT = 65535;
const int MAX_CASES = 3;

const int ROCK = 0;
const int PAPER = 1;
const int SCISSORS = 2;

// variables will change:
int arduinoChoice;
int playerChoice = -1;

int arduinoWonCounter = 0;
int playerWonCounter = 0;

char text[64];
const char labels[][9]= { "Rock", "Paper", "Scissors" };
unsigned int counts[MAX_CASES][MAX_CASES];
int previous;
const int thisBeatsThat[][2] = {
  { ROCK, SCISSORS },
  { PAPER, ROCK },
  { SCISSORS, PAPER },
  { -1, -1 }
};

unsigned int gameCount = 0;

void setup() {
  // initialize the LED pin as an output:
  // pinMode(ledPin, OUTPUT);      
  // initialize the pushbutton pin as an input:
  pinMode(buttonPlayPin, INPUT);
  digitalWrite(buttonPlayPin, HIGH); // pull up
  pinMode(buttonRockPin, INPUT);
  digitalWrite(buttonRockPin, HIGH); // pull up
  pinMode(buttonPaperPin, INPUT);
  digitalWrite(buttonPaperPin, HIGH); // pull up
  pinMode(buttonScissorsPin, INPUT);
  digitalWrite(buttonScissorsPin, HIGH); // pull up
  Serial.begin(9600);
  randomSeed(analogRead(0));
  SPrintln("Up and running.");
  byte magic0 = EEPROM.read(0);
  byte magic1 = EEPROM.read(1);
  int hasModel = magic0 == 'M' && magic1 == 'R';
  if(hasModel){
    SPrintln("Reading model.");
    int pos = 2;
    for(int i=0;i<MAX_CASES; i++)
      for(int j=0; j<MAX_CASES; j++){
        byte low = EEPROM.read(pos); ++pos;
        byte hi = EEPROM.read(pos); ++pos;
        counts[i][j] = low + hi * 256;
      }
  }else{
    SPrintln("No model, starting from scratch.");
    int pos = 0;
    for(int i=0;i<MAX_CASES; i++)
      for(int j=0; j<MAX_CASES; j++)
        counts[i][j] = 0;
  }
}

void loop(){
  // read the state of the pushbutton value:
  int buttonPlayState = !digitalRead(buttonPlayPin);

  // check if the pushbutton is pressed.
  // if it is, the buttonState is HIGH:
  if (buttonPlayState == HIGH) {     
    // we're game!
    if(playerChoice < 0) {
      // SPrintln("Make a choice first!");
    } else {
      choose();
      sprintf(text, "Arduino choice: %s", labels[arduinoChoice]);
      Serial.println(text);
      
      tallyResults();
      sprintf(text,"I won: %d, You won: %d\n", arduinoWonCounter, playerWonCounter);
      Serial.println(text);
      updateModel();
      previous = playerChoice;
      playerChoice = -1;
      
      ++gameCount;
      if(gameCount % 100 == 0) {
        SPrintln("\n\n\n\nWriting model\n\n\n\n\n");
        EEPROM.write(0, 'M');
        EEPROM.write(1, 'R');
        int pos = 2;
        for(int i=0;i<MAX_CASES; i++)
          for(int j=0; j<MAX_CASES; j++){
            EEPROM.write(pos, counts[i][j] % 256); ++pos;
            EEPROM.write(pos, counts[i][j] / 256); ++pos;
          }
      }
    }
  } else {
    int buttonRockPinState = !digitalRead(buttonRockPin);
    int buttonPaperPinState = !digitalRead(buttonPaperPin);
    int buttonScissorsPinState = !digitalRead(buttonScissorsPin);
    //sprintf(text, "Got: %d %d %d", buttonRockPinState, buttonPaperPinState, buttonScissorsPinState);
    //Serial.println(text);
    if(buttonRockPinState == HIGH){
      if(playerChoice != 0){
        SPrintln("Player choice: Rock");
        playerChoice = 0;
      }
    }else if(buttonPaperPinState == HIGH){
      if(playerChoice != 1){
        SPrintln("Player choice: Paper");
        playerChoice = 1;
      }
    }else if(buttonScissorsPinState == HIGH){
      if(playerChoice != 2){
        SPrintln("Player choice: Scissors");
        playerChoice = 2;
      }
    }
  }
}

void choose(){
  // arduinoChoice = random(0,3);
  long accum = 0;
  // get total accumulated likelihood mass
  for(int i=0;i<MAX_CASES;i++){
    accum += counts[previous][i] + 1; // uniform priors
  }
  // sample according to that
  long sampled = random(0,accum);
  int choice = -1;
  accum = 0;
  for(int i=0;i<MAX_CASES;i++){
    accum += counts[previous][i] + 1;
    if(accum > sampled){
      choice = i;
      break;
    }
  }
  sprintf(text, "Arduino predicts: %s", labels[choice]);
  Serial.println(text);
  // we got our predicted player's choice, now beat it
  arduinoChoice = PAPER;
  int i=0;
  while(true){
    if(thisBeatsThat[i][0] == -1){
      break;
    }
    if(thisBeatsThat[i][1] == choice){
      arduinoChoice = thisBeatsThat[i][0];
      break;
    }
    ++i;
  }  
}

void updateModel(){
  int saturated = false;
  ++counts[previous][playerChoice];
  if(counts[previous][playerChoice] == MAX_INT / 2){ 
    // saturated, scale down
    SPrintln("Saturation, scaling down model.");
    for(int i=0; i<MAX_CASES;i++)
      for(int j=0; j<MAX_CASES;j++)
        counts[i][j] = counts[i][j] >> 1;
  }
}

void tallyResults(){
  int tie = true;
  if(playerChoice == ROCK) {
    if(arduinoChoice == PAPER) {
      SPrintln("My paper envolves your rock!");
      ++arduinoWonCounter; tie = false;
    }else if(arduinoChoice == SCISSORS) {
      SPrintln("Your rock smashes my scissors!");
      ++playerWonCounter; ; tie = false;
    }
  } else if(playerChoice == PAPER) {
    if(arduinoChoice == SCISSORS) {
      SPrintln("My scissors cut your paper!");
      ++arduinoWonCounter; tie = false;
    }else if(arduinoChoice == ROCK) {
      SPrintln("Your paper covers my rock!");
      ++playerWonCounter; ; tie = false;
    }
  } else if(playerChoice == SCISSORS) {
    if(arduinoChoice == ROCK) {
      SPrintln("My  rock smashes your scissors!");
      ++arduinoWonCounter; tie = false;
    }else if(arduinoChoice == PAPER) {
      SPrintln("Your scissors cut my paper!");
      ++playerWonCounter; ; tie = false;
    }
  }
  if(tie){
    SPrintln("Tie!");
  }
}


