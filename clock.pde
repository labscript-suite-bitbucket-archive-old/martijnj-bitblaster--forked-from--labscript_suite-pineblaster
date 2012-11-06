#include <plib.h>


const int max_program_length = 102310;
byte * program_start_addr;

// This is our handler for the hardware trigger. It does nothing, so that control
// returns to the program as soon as possible
void __ISR(_EXTERNAL_0_VECTOR, _INT0_IPL_ISR) ExtInt0Handler(void){Serial.println("In interrupt!");}

void start(int autostart){
  // temporarily disable all interrupts:
  int temp_IPC0 = IPC0;
  int temp_IPC6 = IPC6;
  IPC0 = 0;
  IPC6 = 0;
  // except for our one:
  IEC0bits.INT0IE = 0;
  IFS0bits.INT0IF = 0;
  INTCONbits.INT0EP = 1;
  IPC0bits.INT0IP = _INT0_IPL_IPC;
  IPC0bits.INT0IS = _INT0_SPL_IPC;
  IEC0bits.INT0IE = 1;
  // wait for it....
  __asm__("nop\n\t");
  __asm__("wait\n\t");
  Serial.println("woke up!");
  // Load the RAM address of the start of the program into a temporary register:
  __asm__("lui $t0, 0xa000\n\t");
  __asm__("ori $t0, 0x7000\n\t");
  // go!
  // Jump to the address in that register, and "link" (store a return
  // address in $ra so we can get back here):
  __asm__("jalr $t0\n\t");
  // branch delay slot:
  __asm__("nop\n\t");
  // Declare the interrupt as having been handled:
  IFS0bits.INT0IF=0;
  // Restore other interrupts to their previous state:
  IPC0 = temp_IPC0;
  IPC6 = temp_IPC6;
  Serial.println("got back ok!");
}

void receive_program(int length){
  int i;
  byte b;
  for (i=0;i<length;i++){
    while(1){
      if (Serial.available() > 0){
        b = Serial.read();
        memcpy(program_start_addr + i, &b, 1);
        break;
      }
    }
  }
  Serial.println("ok");
}

String readline(){
  String readstring = "";
  char c;
  byte crfound = 0;
  while (1){
    if (Serial.available() > 0){
      char c = Serial.read();
      if (c == '\r'){
        crfound = 1;
      }
      else if (c == '\n'){
        if (crfound == 1){
          return readstring;
        }
        else{
          readstring += '\n';
        }
      }
      else if (crfound){
        crfound = 0;
        readstring += '\r';
        readstring += c;
      }
      else{
        readstring += c;
      }
    }
  }
}

void setup(){
  // Partitioning RAM,
  // see s3.4.3 of the PIC32 reference for details:
  BMXDKPBA = BMXDRMSZ - max_program_length;
  BMXDUDBA = BMXDRMSZ;
  BMXDUPBA = BMXDRMSZ;
  // Get a pointer to the start of program RAM (using 
  // KSEG1, see s3.4.3.2 of the PIC32 reference for details):
  program_start_addr = (byte *)(BMXDKPBA + 0xA0000000); 
  Serial.begin(115200);
}

void loop(){
  Serial.println("in loop!");
  String readstring = readline();
  if (readstring == "hello"){
    Serial.println("hello");
  }
  else if (readstring == "hwstart"){
    start(0);
  }
  else if ((readstring == "start") || (readstring == "")){
    start(1);
  }
  else if (readstring.startsWith("program ")){
    int firstspace = readstring.indexOf(' ');;
    if (firstspace == -1){
      Serial.println("invalid request");
      return;
    }
    int length = readstring.substring(firstspace+1).toInt();
    
    if (length >= max_program_length){
      Serial.println("program is too long");
    }
    else{
      Serial.println("ok");
      receive_program(length);
    }
  }
  else{
    Serial.println("invalid request");
  }
}

