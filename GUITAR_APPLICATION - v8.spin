{{
***INFORMATION*****************************************************************************
*                   DEEPNOTE(tm) Guitar Hero(r) Robot source code                         *
*  File:        GUITAR_APPLICATION.spin                                                   *
*  Created by:  The 2008 Convolve Inc. Interns                                            *
*  Interns:     Jeremy Blum, Zachary Lynn, Brandon Fischer, Ben Shaffer, and Alex Miller  *
*  Supervisor:  Dr. Neil Singer, President, Convolve, Inc.                                *
*                                                                                         *
*  COPYRIGHT 2008 CONVOLVE INC.  ALL RIGHTS RESERVED.                                     *
*******************************************************************************************

***PHOTODIODE CORRECTION CIRCUITRY************************************************
*                                                                                *
*  Use 3.3V for circuitry (Propeller controller takes 3.3V)                      *                                                                                             
*                                                                                *
*                            C1                                                  *                                  
*                      ┌────────────┐                                           *                                  
*                      │     33pF    │                                           *                                  
*                      │             │                                           *                                  
*                      │     R1      │        +3.3V                              *                                             
*                      ┣────────────┫          │                   LED  R6      *
*                      │    22MΩ     │          │        +3.3V     ┌─────┐    *                      
*                      │             │          │          │       │    100     *                                              
*                      │  +3.3V      │       R2  50k    │\│+      │             *                                               
*                      │    │        │          ┣────────┤-\       │             *                                              
*         PhotoDiode   │  │\│+       │          │        │  \──────┻┳────OUT     *
*          ┌─────────┻──┤-\        │   R5     │        │  /       │            *
*                        │  \───────┻─────────┼─────┳──┤+/        │            *
*                         │  /           10kΩ   │     │  │/│-       │            *
*                      ┌──┤+/                   │     │    │        │            *
*                        │/│-                  │     │            │            *
*                           │                R3  50kΩ│             │            *
*                                              │     │    R4       │            *                  
*                                                    └────────────┘            *
*                                                         100k                   *
*                                                                                *
*  R1 adjusts sensitivity                                                        *
*  R4 adjusts hysteresis (sharp output edges)                                    *
*  OPA2340 Dual OpAmp is good choice                                             *
*  Combining R2 and R3 into 100k pot allows adjusting for trip point             *
*                                                                                *
**********************************************************************************


***GUITAR CONNECTIONS******************************************************************************************************
*                                                                                                                         *
*  USB                                                                                                                    *
*    ||                                                                                          *
*    |   4     3     2     1   |                                                                                          *
*    |_||_||_||_||_|                                                                                          *
*                                                                                                                         *
*    1. Red (+5V)                                                                                                         *
*    2. White (Data-)                                                                                                     *
*    3. Green (Data+)                                                                                                     *
*    4. Black (Ground)                                                                                                    *
*                                                                                                                         *
*                                                                                                                         *
*  BUTTONS                                                                                                                *
*    All buttons have 2V of electricity.                                                                                  *
*    Voltage shorts to 0V when ground and Power for a button are connected (button pressed)                               *
*    Accomplished by closing a relay connected accross the two lanes for each button                                      *
*                                                                                                                         *
*                                                                                                                         *
*  BUTTONS CONNECTIONS TO MAIN GUITAR BOARD                                                                               *
*    (Looking at connections from bottom, with D-Pad south of this illustration)                                          *
*           1             2             3             4             5             6             7             8           *
*    |||||||||    *
*    |             |             |             |             |             |             |             |             |    *
*    | GREEN GND   | BLUE+       | YELLOW GND  | ORANGE GND  | ORANGE+     | YELLOW+     | RED+        | GREEN+      |    *
*    | BLUE GND    |             | RED GND     |             |             |             |             |             |    *
*    |             |             |             |             |             |             |             |             |    *
*    |_____________|_____________|_____________|_____________|_____________|_____________|_____________|_____________|    *
*                                                                                                                         *
*                                                                                                                         *
*  RELAY CONNECTIONS                                                                                                      *
*    Green  - 1&8                                                                                                         *
*    Red    - 3&7                                                                                                         *
*    Yellow - 3&6                                                                                                         *
*    Blue   - 1&2                                                                                                         *
*    Orange - 4&5                                                                                                         *
*                                                                                                                         *
*  STRUM CONNECTIONS                                                                                                      *
*           1             2             3                                                                                 *
*    ||||                                                                          *
*    |             |             |             |                                                                          *
*    |             |             |             |                                                                          *
*    |   GROUND    | STRUM DOWN  | STRUM UP    |                                                                          *
*    |             |             |             |                                                                          *
*    |_____________|_____________|_____________|                                                                          *
*                                                                                                                         *
***************************************************************************************************************************
}}

CON

{FREQUENCY SETTINGS}
  _clkmode = xtal1 + pll16x                                  'Sets the 8MHz Clock Frequency (via 16x multiplier)
  _xinfreq = 5_000_000                                       'External Crystal Runs at 5MHz
  
{INPUT PINS}
{{
*********************************************************************************************************
*     The Photodiode inputs are spaced out across the 32 bits of the Propeller's input word.            *
*     We put 6 bits between each input.  For example, the green input is on pin 0 and the               *
*     next one (red) is on bit 6.  This gives us 6 bits (0 thru 5) for processing the green signals     *
*     The purpose of this is to allow for parallel processing of all of the input signals.              *
*     We need to do some filtering on the inputs to remove noise. This involves some math --            *
*     addition and division.  Since the Propeller works on 32 bit longs, we can keep all the inputs     *
*     packed into a 32 bit long, we can do all of the math in parallel!!                                *
*     We just have to make sure that the math operations NEVER overflow beyond                          *
*     the 6 bits we reserved for each colored input.  This packing makes the code really simple         *
*     and REALLY fast.  This was conceived when we wanted to move to assembler to speed up this portion *
*     of the code.  It was prototyped in SPIN.  It worked so well we never had to move to assembler!!!  *
*     We are able to run a 1.1 msec loop time with everything is SPIN -- this is incredible             *
*     given that we are doing a 9 tap filter on all 5 inputs!                                           *
*********************************************************************************************************
}}
  greenIN         =0                                       'Input PIN for Green PhotoDiode
  redIN           =6                                       'Input PIN for Red PhotoDiode
  yellowIN        =12                                      'Input PIN for Yellow PhotoDiode
  blueIN          =18                                      'Input PIN for Blue PhotoDiode
  orangeIN        =24                                      'Input PIN for Orange PhotoDiode

{DELAY SWITCH INPUTS}
{{
********************************************************************************************************
*     This is the switch that sets the delay between when we detect a note and when we play it         *
*     It is a 4 bit binary switch that gives us a hex value bewteen 0 and 15.                          *
********************************************************************************************************
}}
  delay1          =2                                         'Input PIN for Delay Switch (1)
  delay2          =3                                         'Input PIN for Delay Switch (2)
  delay4          =4                                         'Input PIN for Delay Switch (4)
  delay8          =5                                         'Input PIN for Delay Switch (8)

{Output PINS}
{{
***************************************************************************************************************
*     The outputs for each color are located next to the inputs so that after we do a filtering operation,    *
*     the result is a single value (0 or 1). By shifting this bit once (which is a really fast operation on   *
*     the propeller) we can mask the word and ouptut all of the colored bits in parallel.  In fact, we will   *
*     be doing some division by a power of 2 (just right shifts), so we can leave one shift out and the bits  *
*     will all be in the right place for outputting!! (see the code below)                                    *
***************************************************************************************************************
}}
  greenOUT        =1                                     'Output PIN for Green Button
  redOUT          =7                                     'Output PIN for Red Button 
  yellowOUT       =13                                     'Output PIN for Yellow Button
  blueOUT         =19                                     'Output PIN for Blue Button
  orangeOUT       =25                                     'Output PIN for Orange Button
  strumOUT        =21                                     'Output PIN for Strum Bar
  whammyOUT       =22                                     'Output PIN for Whammy Bar
  starOUT         =5                                      'Output PIN for Star Power (select button)
  debugOUT        =23                                     'Output PIN for Debugging

{Recorder PINS}
{{
***************************************************************************************************************
*       These pins are used for debugging purposes.  We can copy values to the pins for looking at them       *
*       on the oscilloscope.  These pins are more accessible on our circuit board than the other output pins  *                    
***************************************************************************************************************
}}
  RGreenOUT     =8
  RRedOUT       =9
  RYellowOUT    =10
  RBlueOUT      =11
  ROrangeOUT    =14
  RStrumOUT     =15

IOpins          =%00000010111010000010000010100010          ' This sets the direction for each of the prop's 32 bits


{Circular Buffer}
bufferLength    =2048                                    'Sets length of circular buffer -  we use this to store
                                                         '   the notes.

{CALCULATED TIME CONSTANTS}
  one_microsecond =80                                        '1 microsecond in processor counts

{DELAY FOR COLOR CHECKING LOOP (in raw clock cycles)}
  delay_time_microseconds = 1100                                                 'Delay time in microseconds  we are running a 1.1 msec loop
  delay_time        =(one_microsecond*delay_time_microseconds)                   'number of clock cycles to wait for
                                                                                 ' each servo cycle.


{Filter Length}                                         
filter_length = 9                                        'This is the length of the filter, 9 means look at the
                                                         '    past nine inputs when determining if the note is there
                                                                      
{minimum length of a note in servo cycles}

{MULTIPLIER FOR DELAY SWITCH}
{{Default dist_mult = 10 (ie. if switch is on 14, and multiplier is 10, distance is 140 milliseconds)}}
  dist_mult     = 10                                         'factor by which the distance is being multiplied

  note_length = 50_000                                        'note length in microseconds  This is the minimum note length
                                                              ' any notes shorter than this are lengthened.
  lookback_distance = (note_length/delay_time_microseconds)-5 'how far to lookback to find the minimum length note
                          

OBJ
   
  Debug: "FullDuplexSerial"                         'Debug object for difficulties
  
VAR
  
{NOTE ARRAYS}
long notes[bufferLength]                                'Buffer space for unfiltered note storage
long notesClean[bufferLength]                           'Buffer space for filtered note storage
long convolveFilter[filter_length]
                                         
{STACK SPACE FOR COGS}
long stack1 [500]                                       'Stack space for cog1 - detect method
long stack2 [500]                                       'Stack space for cog2 - ButtonPress method
long stack3 [500]                                       'Stack space for cog3 - StarPower method
long stack4 [500]                                       'Stack space for cog4 - recording output

long current_position                                   'Current location in the circular buffer
                                                        ' This variable keeps counting up and wraps
                                                        ' around to zero once it reaches bufferLength-1

long debugPIN                                           ' This var gets added to the value which is output by
                                                        ' the propeller.  We set it to do timing tests, etc.
                                                        ' If we want to scope pin 3 for example, set this to
                                                        ' 2^(3-1) = 4 and pin 3 gets set when the next ouput
                                                        '  is made by the propeller.
long recordingPINS                                      ' This var is similar to debugPIN above -- it gets added to the
                                                        ' ouput.  We set several bits to copy the notes after filtering
                                                        ' to pins that we can reach with the scope.

{Star Power Variables}
long starON                                             'Set in StarPower method but tells the ButtonPress method to launch star power

{SCREEN SIZE DISTANCE VARIABLE (set by delay switch)}
long distance                                              'time (in ms) from bar to bottom
                                                           ' the delay switch is decoded into this variable
                                                           ' we use this to set the time we wait before outputing
                                                           ' the notes and strumming

PUB main | x

{{
**********************************************************************************************************************
* General overview                                                                                                   *
*                                                                                                                    *
* The main routine launches the various cogs.                                                                        *
*                                                                                                                    *
* [The detect cog] The most critical cog runs a precisely timed loop that                                            *
* collects the notes and filters them. It stores the filtered notes in the notesClean buffer. It then extends notes  *
* that are too short in time.  (We found that star power notes do not trigger the photodetectors for as              *
* long as we would like -- they have dark sections because of their shape and the fact that they rotate.)            *
*                                                                                                                    *
* [The ButtonPress cog] A second cog runs at the same precise timing and reads the notesClean buffer.                *
* It outputs the notes and strums the guitar.  Note that it is reading from a different part of the notesClean buffer*
* because it must read notes that were collected some time in the past (this is why we need a buffer)                *
*                                                                                                                    *
* [The starPower cog]  this cog has a simple heuristic algorithm for activating star power to get more points.       *
* This code can be improved to make it more clever.  It could be a future enhancement.                               *
*                                                                                                                    *
* [The main cog]  Once it is done launching the other cogs, the main cog runs a loop to constantly press the         *
* "whammy bar" back and forth.  this gets us more points on held notes.                                              *
*                                                                                                                    *
* [The recordingOutput cog]  Only started if debugging.  This is used for measuring notes on the oscilloscope.       *
* We copy notes over because we do not want to put scope probes all over the guitar.                                 *
* We put the signals where we can get to them.                                                                       *
*                                                                                                                    *
**********************************************************************************************************************
}}


{Convolve Filter!!!!!}
{{
***************************************************************************************************************
* The filter code.                                                                                            *
*                                                                                                             *
* The filter code is a bit tricky -- it was programmed to be very computationally efficient so it is          *
* a bit hard to follow.                                                                                       *
*                                                                                                             *
* The filter used is triangular -- it weights the notes in the center more than the ones on either side       *
* It is equivalent to convolving two boxcar (rectangular) filters together which is equivalent to filtering   *
* the notes twice with a boxcar filter.  We use one filter for efficiency.  Note that this particular filter  *
* sums up to 25.                                                                                              *
*                                                                                                             *
* Below, when the filter is used, we multiply the filter coeficients by the uncleaned notes to create a       *
* cleaned note buffer.                                                                                        *
***************************************************************************************************************
}}
  LONG[@convolveFilter][0] := 1
  LONG[@convolveFilter][1] := 2
  LONG[@convolveFilter][2] := 3
  LONG[@convolveFilter][3] := 4
  LONG[@convolveFilter][4] := 5
  LONG[@convolveFilter][5] := 4
  LONG[@convolveFilter][6] := 3
  LONG[@convolveFilter][7] := 2
  LONG[@convolveFilter][8] := 1


{DISTANCE CALCULATIONS}
  DIRA[delay1..delay8]~                                      'Set delay switch pins to inputs
  calcDistance                                               'Set the distance by reading the switch on the guitar
                                                             '        using the calcDistance method 
'Debug.start(31, 30, 0, 57600)                                 'Debugger start  --- if needed
cognew(detect(@notes, @notesClean), @stack1)                   'Tells a new cog to detect the notes
cognew(ButtonPress(@notesClean), @stack2)                      'Tells a new cog to play the notes
cognew(starPower(@notesClean), @stack3)                        'Tells a new cog to launch the star power algorithm
'cognew(recordingOutput(@notesClean), @stack4)                 'Tells a new cog to send played note outputs to a recording device
                                                               '  for debugging

 {WHAMMY AND CALCULATE DISTANCE CONTINUOUSLY}   
  DIRA[whammyOUT]~~                                          'Sets whammy pin to output mode
  repeat                                                     'Repeat endlessly...
    calcDistance                                             'Calculate distance via hex switch  -- we do this constantly
                                                             ' so we can tune the guitar "live"
    if (x>100)    
      !OUTA[whammyOUT]                                       'Change the state of the whammy (switch back and forth)
      x:=0                                                    
    x++
    waitcnt(delay_time +cnt)                             'Wait, then repeat

PUB calcDistance
 {{
***************************************************************************************************************
*   Decode the hexadecimal switch used for delay time -- the time between detecting a note and playing it     *
* distance is in units of microseconds and gets converted to counts when it is used                           *
***************************************************************************************************************
 }}
{CALCULATE DISTANCE} 
  distance := (INA[delay1] + INA[delay2]*2 + INA[delay4]*4 + INA[delay8]*8)*1000*dist_mult  'sets the distance based on pin inputs
  if (distance == 0)
    distance:=170*1000
 
PUB detect(noteArray, noteArrayClean) | Next_start_time, i, q               'Note checking method
{{  The detect cog
***********************************************************************************************************************
*   Notes are read simultaneously as one 32 bit long.  The 32 bit long is stored in a circular buffer (noteArray).    *
*  The var current_position points to the most recent spot in the buffer where the most recent notes are stored.      *
*  (Remember,  the 5 notes are spaced out over each 32 bit long!!)  The previously stored notes are in the buffer at  *
*  current_position - 1, current_position - 2, current_position - 3, etc.  HOWEVER, if current_position - X is        *
*  less then 0, YOU MUST wrap around to the end of the buffer and start reading from the Buffer_length-1 location!!!! *
*  This is the reason we wrote a lookback function.  Whenever we need to "go back in time" we use lookback so it      *
*  properly does the wraparound.  ALWAYS use lookback or you will trample through memory!!  The only place we did not *
*  use lookback is in the filter code (described below) because we needed to save some computation and did something  *
*  more clever.                                                                                                       *
*                                                                                                                     *
*  Next the notes are filtered using the Cleanup Method and copied to noteArrayClean. Subsequently, the notes that are*
*  too short in time are extended in the buffer by copying the 32 bit note register over to adjacent memory locations.*
***********************************************************************************************************************
}}
DIRA := IOpins                                                    'Turn all input pins to input

  Next_start_time := cnt                                                    'Take note of current clock time
  current_position:=0                                                       'Initializes current position as zero
  
                                                                          ' now loop to detect the notes
  repeat                                                                
    LONG[noteArray][current_position] := INA & %00000001000001000001000001000001      ' mask out so we only have our 5 notes and store them away
    q := CleanUp(current_position, noteArray)                                 ' filter the notes so they are clean
    LONG[noteArrayClean][current_position] := q                             'Stores the filtered notes in the correct buffer location

                                                                            ' This next IF statement checks for the falling edge of a note
                                                                            ' we only run extend note at the end of a note
                                                                            ' the XOR detects ANY note edge because if
                                                                            ' the current input and the previous input are different
                                                                            ' the XOR is TRUE.  we then AND it with NOT the current note
                                                                            ' so if the current note is 0, the NOT will be TRUE and the edge
                                                                            ' must be a falling note edge. Then, and only then, run the extendNote method.
                                                                            ' REMEMBER - this is a parallel operation -- if any one note or a
                                                                            ' chord (two or more notes) has a falling edge, extendNote is run because
                                                                            ' the resulting value is greater than zero (a bit will be in the proper spot for
                                                                            ' any note that has a falling edge).
    if ((LONG[noteArrayClean][current_position] ^ LONG[noteArrayClean][lookback(current_position, 1)]) & (! LONG[noteArrayClean][current_position])) > 0
      extendNote(current_position, noteArrayClean)   
    
    current_position++                                                      'Increments current_position to move forward
    if current_position==bufferLength                                       'If end of circular buffer is reached...
      current_position:=0                                                           'Go back to the beginning
    Next_start_time += delay_time                                           'Delay next loop to prevent overlapping
    waitcnt(Next_start_time)                                                'Waits necessary time

PUB CleanUp(current_index, noteArrayD) | i, x, j, b, convolve
  x := 0                                                                    ' init the filter result value to 0
  convolve := 0                                                             ' this is the index into the filter buffer
  j := (current_index - filter_length)                                      ' current_index-filter_length is the farthest
                                                                            ' back that we will be looking into the buffer
                                                                            ' we will need this.  If we use the function
                                                                            ' lookback like we do elsewhere, this code is too
                                                                            ' slow.  Since we always are working on consecutive
                                                                            ' memory locations, we can do this once and find the
                                                                            ' memory seam and do a loop.
  if (j < 0)                                                                ' if we are going to look past the end of the buffer,
                                                                            ' do the filter loop on the begining of the buffer
                                                                            ' and the end of the buffer separately
    repeat i from current_index to 0                                        '     do the first part of the buffer
      x += (LONG[noteArrayD][i] * LONG[@convolveFilter][convolve])          '         multiply the note values by the filter coefficients
      convolve++                                                            '         index to the next filter coefficient
    repeat i from bufferLength-1 to (bufferLength+j-1)                      '     do the memory locations at the end of the buffer
      x += (LONG[noteArrayD][i] * LONG[@convolveFilter][convolve])          '         multiply the note values by the filter coefficients
      convolve++                                                            '         index to the next filter coefficient 
  else                                                                      ' otherwise - we only need one loop to do the whole filter
    repeat i from 0 to filter_length-1
      x += (LONG[noteArrayD][(current_index - i)] * LONG[@convolveFilter][convolve]) ' multiply the note values by the filter coefficients   
      convolve++                                                            '         index to the next filter coefficient


      '************************
                                                                            ' this part is efficient but confusing:
                                                                            ' The filter adds up to 25.  If every note in the history were
                                                                            ' on (set to 1), the sum would be 25.  We want to bias the result so that
                                                                            ' if the sum is greater than 8, the note is "on" (set = 1)
                                                                            ' we chose this because by looking at the oscilloscope output from the
                                                                            ' sensors, the noise is almost always when the notes are "on".  Normally
                                                                            ' a filter would trigger when the number is greater than 12 (half of the 25)
                                                                            ' but we wanted to make the notes "stick on" so there is some hysteretic
                                                                            ' effect.  To do this test, we need to sense when the value of the result is
                                                                            ' equal to or greater than eight. To do this in binary, we test if the 8 or
                                                                            ' 16 bit (bits 3 or 4) or both are high. 
  b := x >> 3                                                               ' shift the result by 3 --
                                                                            ' normally we would shift by 4 to divide the result
                                                                            ' by 16,  we only do 3 shifts because later we want to
                                                                            ' shift LEFT by one so the resulting bits are in the
                                                                            ' proper bit location for output. 
                                                                            
  x >>= 2                                                                   ' now shift by 2 --
                                                                            ' again we want to shift 3 bits BUT we only do 2 because
                                                                            ' we want the ouput to wind up in a position that is one
                                                                            ' bit to the left of the original input.
  x |= b                                                                    ' OR the two results because we want EITHER bit 3 or 4 to
                                                                            ' be high to trigger an output.
  x &= %00000010000010000010000010000010                                    ' Now we mask the result so only the output bits remain
                                                                            ' any other bits in the computation are thrown away
                                                                            ' we are left with a filtered result with VERY few, fast
                                                                            ' computations and ALL notes are done in parallel!!!
  return x

PUB extendNote (current_index, colorClean) | x
 {{
***********************************************************************************************************************
*  ExtendNote uses longfill because it is MUCH faster than looping.                                                   *
*   first test to see if we can do it in one operation or split it in two                                             *
***********************************************************************************************************************
 }}
    x := (current_index - lookback_distance)
    if x > 0                                                               ' Test if the lookback needs to wrap around
      longfill(colorClean+4*x, 1, lookback_distance)                        ' Extend the note by copying it into the "future"
    else
      longfill(colorClean, 1, current_index)                                'copy the older part at the begining of the buffer
      longfill(colorClean+4*(bufferLength+x), 1, -x)                        ' copy the newer part over

PUB lookBack (current_index, past_index) |  index_difference     'Buffer edge safety method
{{
***********************************************************************************************************************
*   This method calculates the index in a circular buffer.  It wraps around the begining of the buffer, if needed     *
***********************************************************************************************************************
}}
  index_difference := current_index - past_index                 'Calculate past index
  if index_difference < 0                                        'Check if invalid
     index_difference+=(bufferLength)                                       'Add bufferLength to go back to the end of the buffer
  return index_difference                                        'Return actual index that is needed
                           
   
PUB ButtonPress (cleanNoteArray) | counter, Next_start_time, masked, strum, strumOn    'General Playing Method
{{
**************************************************************************************************************************
*  ButtonPress reads the notesClean buffer.                                                                              *
*  It outputs the notes and strums the guitar.  Note that it is reading from a different part of the notesClean          *
*  buffer than detect because it must read notes that were collected some time in the past (this is why we need a buffer)*
**************************************************************************************************************************
}}
  DIRA := IOpins                                         'Activates output pins
  strumOn := 0                                       ' initialize the variable that sets the strum relay
  Next_start_time := cnt                            'Takes note of current clock time
  repeat                                            'Loops indefinately
    OUTA := LONG[cleanNoteArray][counter]  + strumOn + starON + debugPIN + recordingPINS        'Copy the clean notes from the past
                                                                                                ' to the output while setting the strum,
                                                                                                ' star power, debugging and recording pins
    if (LONG[cleanNoteArray][counter] >0)                                                       ' test if we are supposed to be playing a note
      strumOn := |< strumOut                                                                    ' we are playing a note so the correct strum
                                                                                                'bit must be set, StrumOut is that bit number
    else
      strumOn := 0                                                                              ' otherwise the strum should be off
{{    counter:= current_position - (distance/delay_time_microseconds)   'Sets correct delay to allow the notes to reach the bottom of the screen
    if counter < 0                                                       ' this code handles the wrap around
      counter += bufferLength
      }}
    counter := lookBack(current_position,distance/delay_time_microseconds)    ' set the proper location to play next
    Next_start_time += delay_time                      'Sets delay time in clock ticks 
    waitcnt(Next_start_time)                           'Waits necessary time

PUB starPower (cleanNoteArraySP) | sp_var, spWatch, sp_zero, sp_count
{{
**************************************************************************************************************************
*  StarPower reads the notesClean buffer and looks for the right conditions to trigger star power                        *                  
*  This version is real primative -- it checks for a stream of high density notes and hits the star power relay          *
*  It seems to work fairly well in practice because when the notes are dense we get alot of points                       *
**************************************************************************************************************************
}}
  sp_count := 0 
  sp_zero := 0
  sp_var := 0
  starON := 0
  repeat                                                                             ' this loop looks for a continuous stream of fast notes 
    sp_count++                                                                       ' sp_count keeps counting up until star power is used
                                                                                     '        then it is rest to zero
    spWatch:= LONG[cleanNoteArraySP][current_position]                               ' get the current note
    if (spWatch>0)                                                                   ' was a note played?
      sp_var++                                                                       ' count each time a note is played
       if ((sp_zero==0) and (sp_var>1) and (sp_count < ((note_length*2)/delay_time_microseconds)))  ' sp_var must be greater than one
                                                                                                    '     so it won't run the first time a note is detected
                                                                                                    '     we are looking for a streamof at least 2 notelengths
         starON := |< starOUT
         sp_var:=0
         sp_count:=0
      if (sp_count > ((note_length*20)/delay_time_microseconds))                       ' reset the everything if we exceed a streak of 20 note lengths
                                                                                       '   without triggering star power (not dense enough)
         sp_count:=0
         sp_var:=0    
      sp_zero:=1                                                                       ' set sp_zero so it can do a star power on the
                                                                                       '    next cycle if the other conditions are met
    else                                                                                  
      starON := 0                                                                      ' if no note played, reset starON
      sp_zero:=0                                                                       ' reset sp_zero
   waitcnt(delay_time + cnt)
   
PUB recordingOutput (cleanNoteArray) | counter
{{
**************************************************************************************************************************
*  recordingOutput copies the notes to extra debug pins that are easy to get to                                          *
*  Only  used for debugging                                                                                              *
**************************************************************************************************************************
}}
  repeat
    counter := lookBack(current_position,distance/delay_time_microseconds)    ' set the proper location to play next
    recordingPINS := 0
    recordingPINS += OUTA[RGreenOUT] := (LONG[cleanNoteArray][counter]<<(RGreenOUT - GreenOUT)) & |<RGreenOUT
    recordingPINS += OUTA[RRedOUT] := (LONG[cleanNoteArray][counter]<<(RRedOUT - RedOUT)) & |<RRedOUT
    recordingPINS += OUTA[RYellowOUT] := (LONG[cleanNoteArray][counter]<<(RYellowOUT - YellowOUT)) & |<RYellowOUT
    recordingPINS += OUTA[RBlueOUT] := (LONG[cleanNoteArray][counter]<<(RBlueOUT - BlueOUT)) & |<RBlueOUT
    recordingPINS += OUTA[ROrangeOUT] := (LONG[cleanNoteArray][counter]<<(ROrangeOUT - OrangeOUT)) & |<ROrangeOUT
    recordingPINS += OUTA[RStrumOUT] := (LONG[cleanNoteArray][counter]<<(RStrumOUT - StrumOUT)) & |<RStrumOUT          
    waitcnt(delay_time/10 + cnt)
    