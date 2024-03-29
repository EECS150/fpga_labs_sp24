# FPGA Lab 4: Tunable Wave Generator, NCO, FSMs, RAMs
<p align="center">
Prof. John Wawryznek 
</p>
<p align="center">
TAs: (ordered by section) Daniel Endraws, Dhruv Vaish, Rohit Kanagal
<p align="center">
Department of Electrical Engineering and Computer Science
</p>
<p align="center">
College of Engineering, University of California, Berkeley
</p>

## Overview
In this lab we will:

- Extend the functionality of the square wave generator we built in lab3
  - Use the buttons to adjust the output wave frequency
- Write a Numerically Controlled Oscillator (NCO)
  - Initialize a ROM with a binary file and use it as an LUT
  - Design a phase accumulator (PA)
- Design an FSM
  - Use buttons to switch between states
  - Use the FSM to control the NCO using a RAM
  - Test the circuit on the FPGA

### Before You Begin

Fetch Latest Lab Skeleton
```shell
cd fpga-labs-<username>
git pull staff main
```
If you face any divergent branch issues, merge the staff changes into your branch with:
```shell
git merge staff/main
```

Copy Sources From Previous Lab
```shell
cp lab3/src/synchronizer.v lab3/src/debouncer.v lab3/src/edge_detector.v lab4/src
```

Look through these documents if you haven't already.

- [Verilog Primer Slides](https://www.eecs151.org/files/verilog/Verilog_Primer_Slides.pdf) - Overview of the Verilog language
- [FSM](https://www.eecs151.org/files/verilog/verilog_fsm.pdf) - Finite State Machines in Verilog (*Note does note adhere to no-flipflop inference policy)


<details open>

<summary> Table of Contents (click to close) </summary>

- [FPGA Lab 4: Tunable Wave Generator, NCO, FSMs, RAMs](#fpga-lab-4-tunable-wave-generator-nco-fsms-rams)
  - [Overview](#overview)
    - [Before You Begin](#before-you-begin)
  - [Tunable Square Wave Generator](#tunable-square-wave-generator)
    - [Implementation](#implementation)
    - [Verification](#verification)
    - [FPGA](#fpga)
  - [Numerically Controlled Oscillator (NCO)](#numerically-controlled-oscillator-nco)
    - [Overview](#overview-1)
    - [Implementation](#implementation-1)
    - [Verification](#verification-1)
    - [FPGA](#fpga-1)
  - [FSM + Note Sequencer (RAM)](#fsm--note-sequencer-ram)
    - [Sequencer RAM](#sequencer-ram)
    - [FSM Specification](#fsm-specification)
    - [Testbench](#testbench)
  - [Put Everything Together](#put-everything-together)
  - [Lab Deliverables](#lab-deliverables)
  - [Acknowledgement](#acknowledgement)

</details>

## Tunable Square Wave Generator
In lab 3, we built a simple square wave generator which can emit a fixed 440Hz square wave tone. We would like to add more functionality.

### Implementation
Support 2 modes of frequency adjustment which can be achieved by directly adjusting the period:
  - *Linear Period Adjustment*: increase the frequency of the square wave linearly using the `STEP` parameter to determine how much to adjust the square wave period for every button press
    - For example, last lab we inverted the square wave every 139 samples, after an increase with a step of 10 we should now invert the square wave every 149 samples
  - *Exponential Period Adjustment*: double or halve the period of the square wave for every button press (*hint*: use bitshifts)

Use the button inputs as follows:
  - `button[0]` to increase the square wave frequency (decrease period)
  - `button[1]` to decrease the square wave frequency (increas period)
  - `button[2]` to switch between the 2 modes of frequency adjustment (linear period step/exponential)

Use `leds[0]` to display the frequency adjustment mode. The other `leds` can be set as you wish.

Since we now have a working button parser, we will use an explicit reset signal (`rst`) to make sure our registers don't hold undefined values (`X`) during simulation, and to gain the ability to reset our circuits at runtime.

When `rst` is high on a rising clock edge, you should be in:
- 440 Hz square wave frequency
- Linear incrementing mode

by resetting all registers in your circuit to known values.


**Manually copy your DAC** from `lab3/src/dac.v` to `lab4/src/dac.v`. **Use the new `rst` signal** to reset registers inside your DAC *instead of* using initial values. Example:
```verilog
// Explicit global reset
input clk, rst;
wire [4:0] count, count_next;

REGISTER_R #(
  .N(5), 
  .INIT(5'd0) // Reset value
) counter (.q(count), .d(count_next), .rst(rst), .clk(clk));

// ... (code here) ...
```

Use your solution from lab 3 to **implement the new square wave generator** in `src/sq_wave_gen.v`.
You should support a square wave frequency range from 20 Hz to 10 kHz. (hint: calculate the corresponding period...).

### Verification
**Extend the testbench** in `sim/sq_wave_gen_tb.v` to verify the reset and frequency adjustment functionality of your `sq_wave_gen`.

Make sure your RTL can **handle overflow** (what happens when you keep pressing the same button?)

The testbench has 2 simulation threads
  - The first one pulls samples from the `sq_wave_gen` at random intervals
  - The second one is for you **to write by simulating button presses**. You should use the `num_samples_fetched` variable to advance time in the simulation.
    - *Note*: the sample rate is `125e6 / 1024 = 122 kHz`
    - *Example*: to wait for a quarter of a second, you can use the delay statement `@(num_samples_fetched == 30517)`
      - This is computed by `wait_time * sample_rate = 0.25 * (125e6 / 1024) = 30517`

You can use the same script from lab 3 to convert the simulation output to an audio file.
```shell
../scripts/audio_from_sim sim/codes.txt
aplay output.wav
```

### FPGA
Look at `src/z1top.v` to see how the new `sq_wave_gen` is connected.
Use `SWITCHES[1]` to turn the audio output on/off, and keep `SWITCHES[0]` low to use the `sq_wave_gen` module to drive the DAC.

Use `make impl` and `make program` to **put the circuit on the FPGA and test it**.

## Numerically Controlled Oscillator (NCO)
The top level schematic for the rest of this lab is shown below:

<p align=center>
  <img height=400 src="./figs/top.png"/>
</p>

### Overview
Now we can generate tunable square waves using `sq_wave_gen`, but 1) they sound harsh and 2) we want to create a more general wave generation circuit that has frequency control and supports arbitrary waveform types.

Let's use a numerically controlled oscillator (NCO) to generate sine waves.
Here's the math involved:

A **continuous time** sine wave, with a frequency $f_{sig}$, can be written as:

$$f(t) = sin(2 \pi f_{sig} t)$$

If this sine wave is sampled with sampling frequency (so the audio could be stored as a bunch of numbers) $f_{samp}$ (= 125e6 / 1024 = 122 kHz in our case), the resulting stream of discrete time samples is:

$$f[n] = sin (2 \pi f_{sig} \frac{n}{f_{samp}})$$

We want to let our hardware output such stream of samples. One way to do this is to use a **lookup table (LUT)** and a **phase accumulator** (PA, just a register that can increment its value).

Say we have a LUT that contains sampled points for one period of a sine wave with $2^N$ entries. The entries `i` (where $0 \leq i \leq 2^N - 1$) of this LUT are:

$$LUT[i] = sin(i \frac{2\pi}{2^N})$$

To find the index ***i*** of the LUT that stores the ***n-th sample***, we can equate the expressions inside $sin()$:

$$i \frac{2 \pi}{2^N} = 2 \pi f_{sig} \frac{n}{f_{samp}}$$

Which leads to the following:

$$i = \underbrace{\left(\frac{f_{sig}}{f_{samp}} 2^N \right)}_{\text{phase increment}} n$$

This means that to calculate sample `n+1` for a given $f_{sig}$, we should take the LUT index ***i*** that corresponds to sample `n` and increment the index by the **frequency control word (FCW)** (also called the **phase increment** in the equation above).

To find the frequency step, $\Delta_{f,min}$ , of the NCO (a.k.a frequency resolution) we can look at how much of a change in $f_{sig}$ could cause the FCW, or phase increment, to increase by 1:

$$\frac{f_{sig} + \Delta_{f,min}}{f_{samp}} 2^N = \frac{f_{sig}}{f_{samp}}2^N + 1$$
$$\Delta_{f,min} = \frac{f_{samp}}{2^N}$$

In the equaltion above, ${2^N}$ is th total number of frequencies we could represent using N bits. In this lab we will use `N=24`. Recall that in lab 3, our DAC has a frequency of `122kHz`, which means the frequency resolution is `0.007Hz`. We can have very precise frequency control using an NCO.

However, a $2^{24}$ entry LUT is huge and wouldn't fit on the FPGA. So, we will keep the phase accumulator `N` (24-bits) wide, and only use the MSB `M` bits to index the sine wave LUT. This means the LUT only contains $2^M$ entries, where `M` can be chosen based on the tolerable phase error. **We will use `M = 8` in this lab.**

*To learn more about phase error and spurs that occur due to truncation refer to [this article from all about circuits](https://www.allaboutcircuits.com/technical-articles/basics-of-phase-truncation-in-direct-digital-synthesizers), [this analog devices note](https://www.analog.com/media/en/training-seminars/tutorials/MT-085.pdf), and [this MIT paper on phase truncation effects](https://dspace.mit.edu/bitstream/handle/1721.1/15115/14051849-MIT.pdf).*

### Implementation
We’ve generated a file that contains the contents of the LUT for you in `src/sine.bin`. You can run the following command to re-generate it:
```shell
python scripts/nco.py --sine-lut > sine.bin
```

We can use the file to initialize a ROM inside `src/nco.v`. Use the Single-port ROM with asynchronous read in the `EECS151.v` library file (`ASYNC_ROM` module). You can provide a file for it to load the ROM with initial contents like the following example (note how this uses `$readmemb()` under the hood).
```verilog
ASYNC_ROM #(
  .DWIDTH(10), // Data width
  .AWIDTH(8),  // Address width
  .MIF_BIN("sine.bin") // Memory initialization file (binary)
) sine_rom (
  .q(/* output */),
  .addr(/* address */)
);
```

If you are running a simulation in GUI Vivado, you must add this file to sim sources.

**Implement** the NCO in `src/nco.v`. Note that the PA uses the main clock and runs at 125MHz.
When `next_sample` is high, you should output a new DAC code on `out` on the next rising clock edge, similar to the `sq_wave_gen`.
You can assume that `fcw` can change only when `next_sample` isn't high.

### Verification
We have provided a testbench for the NCO in `sim/nco_tb.v`.
It is similar to `sim/sq_wave_gen_tb.v` in that it uses one thread to dump to fetch samples from the `NCO` and dumps them to a file called `nco_codes.txt`, and it uses another thread to set `fcw`.

You can run the testbench as usual, with the provided assertions.
You should also **modify the testbench** to produce a 440 Hz tone using the NCO by setting the correct `fcw`.
You can use the same script to convert the sample outputs to an audio file.

```shell
../scripts/audio_from_sim sim/nco_codes.txt
aplay output.wav
```

Verify the simulated output sounds like a [pure sine tone at 440 Hz](https://www.szynalski.com/tone-generator/) rather than the harsh sound produced by a square wave generator.

### FPGA
Look through `src/z1top.v` for the instantiation of the `nco`.
Note that the `fcw` comes from an FSM which we will implement in the next part.
Also note that `SWITCHES[0]` controls whether the square wave circuit (0) or the NCO (1) is playing through the audio jack and `SWITCHES[1]` can be used to mute the audio (0 = mute, 1 = active).

For now, hard-code `fcw` to the value required to play a 440 Hz tone.
```verilog
    //.fcw(fcw),
    .fcw(24'd____),
```

Run `make impl` and `make program`, and make sure you hear a 440 Hz sine wave when you plug in headphones to the audio jack.

## FSM + Note Sequencer (RAM)

### Sequencer RAM
We want to implement a sequencer that holds 4 notes (FCWs) and plays each note for 1 second through the NCO in a loop.
We have provided a RAM that's used to hold and modify these 4 notes.
See `src/fcw_ram.v` for a skeleton of a RAM with 1 read/write port.
Note that both read and write are *synchronous*.

The RAM contains 4 24-bit values, which correspond to the FCWs for the 4 notes.
Initially (upon reset) the RAM should hold these 4 notes:
  - 440 Hz (A4)
  - 494 Hz (B4)
  - 523 Hz (C5)
  - 587 Hz (D5)

**Calculate** the corresponding FCWs and edit the define statements in `src/fcw_ram.v` with the values you calculated.

### FSM Specification
With the sequencer RAM in place, we want to design and implement an FSM that will use the buttons to play, reverse-play, and pause the playback of the 4 notes in the sequencer RAM.

The FSM takes the lower 3 buttons as inputs and outputs the values for 4 LEDs and the FCW for the NCO.
A skeleton is provided in `src/fsm.v`.

The FSM has 4 states: `REGULAR_PLAY`, `REVERSE_PLAY`, `PAUSED`, `EDIT`.
Here is the state transition diagram:

<p align=center>
  <img height=350 src="./figs/fsm.png"/>
</p>

- The initial state should be `REGULAR_PLAY`. In this state, the FSM should play the notes in the RAM one by one (440Hz -> 494Hz -> 523Hz -> 587Hz). Each note should be played for 1 second.
- Pressing the play-paused button (`button[0]`) should transition you into the `PAUSED` state from either the `REGULAR_PLAY` or `REVERSE_PLAY` states. Pressing the same button while in the `PAUSED` state should transition the FSM to the `REGULAR_PLAY` state.
- In the `PAUSED` state, the RAM address should be held steady at its value before the transition into `PAUSED`, and the NCO should freeze (e.g. set `fcw` to 0). After returning to the `REGULAR_PLAY` state, the RAM address should begin incrementing again from where it left off.
- You can toggle between the `REGULAR_PLAY` and `REVERSE_PLAY` states by using the reverse button (`button[1]`). In the `REVERSE_PLAY` state, you should decrement the RAM address by 1 rather than increment it by 1 every second.
- The `EDIT` state can only be entered when the edit button (`button[2]`) is pressed in the `PAUSED` state. In the `EDIT` state, the current note should come out of the speaker continuously. Pressing `button[0]` will decrease the frequency of the current tone, while pressing `button[1]` should increase the frequency. You can decide the step at will and it doesn’t have to be linear. Pressing the edit button should transition the FSM back to the `PAUSED` stage.
- If the FSM is reset (`rst`) it should return to the `REGULAR_PLAY` state, and the RAM should be reset to its original values.
- If you don't press any buttons, the FSM shouldn't transition to another state.
- Keep in mind, when doing a reset, we cannot write the current note into the ram (what should wr_en look like?)
- **Make sure your note doesn't underflow or overflow** beyond the min/max frequency.

The `leds` output should track which note you are playing (one-hot).
The `leds_state` output should represent the state your FSM is in using 2 bits.

We have provided a skeleton in `src/fsm.v` and a simple RAM in `src/fsm_ram.v`.
If you would like to use a different implementation, feel free to modify it.

Here are some tips to create an FSM in verilog:
- Encode your states as local parameters (i.e. `localparam PLAY = 2'b01` at the top of the module) and use the labels instead of literal values (i.e. `next_state = PLAY`).
- If you are driving a value (such as outputs or internal signals) in `always @(*)` blocks, make sure to only drive that one value in a single block.
  - Not doing so will lead to multi-driven net errors in synthesis; tools will be unsure which driver (always block) should actually drive the wire.
  - `case` statements in the always blocks on the current state can be helpful.
- Recall that any value **assigned to** in an `always @(*)` block must be declared as a `reg`.
  - Note this value still represents combinational logic - `reg wr_en;` can only ever synthesize to a register / represent sequential logic if assigned to in an `always @(posedge clk)` block, but this infers a flip flop which is **not allowed** in this course.

### Testbench
We have provided an FSM testbench skeleton in `sim/fsm_tb.v`.

You should **edit it** to simulate pressing buttons and verifying the FSM behaves correctly.
Make sure you test all the state transitions.

You can override `CYCLES_PER_SECOND` when instantiating `fsm` to speed up simulation (as before).

## Put Everything Together
Check the top-level diagram again.
Make sure that all modules are connected as desired in `src/z1top.v` (remove the `fcw` hardcoding from the previous part).

**Program the FPGA**.
Plug headphones into the audio out port, press the reset button, and verify that you hear the notes in the sequencer RAM play one after the other.
Use the buttons to switch between different states.

## Lab Deliverables
**Lab Checkoff (due: next lab)**

To checkoff for this lab, have these things ready to show the TA:
  - Demonstrate the tunable square wave generator on the FPGA (reset, linear/exponential frequency adjustment)
  - Demonstrate the FSM on the FPGA (FSM with play, reverse play, pause, edit, and reset)

## Acknowledgement
This lab is the result of the work of many EECS151/251 GSIs over the years including:
- Sp12: James Parker, Daiwei Li, Shaoyi Cheng
- Sp13: Shaoyi Cheng, Vincent Lee
- Fa14: Simon Scott, Ian Juch
- Fa15: James Martin
- Fa16: Vighnesh Iyer
- Fa17: George Alexandrov, Vighnesh Iyer, Nathan Narevsky
- Sp18: Arya Reais-Parsi, Taehwan Kim
- Fa18: Ali Moin, George Alexandrov, Andy Zhou
- Sp19: Christopher Yarp, Arya Reais-Parsi
- Fa19: Vighnesh Iyer, Rebekah Zhao, Ryan Kaveh
- Sp20: Tan Nguyen
- Fa20: Charles Hong, Kareem Ahmad, Zhenghan Lin
- Sp21: Sean Huang, Tan Nguyen
- Fa21: Charles Hong, Vighnesh Iyer, Alisha Menon, Zhenghan Lin
- Sp22: Alisha Menon, Yikuan Chen, Seah Kim
- Fa22: Paul Kwon, Yikuan Chen
- Fa23: Viansa Schmulbach
- Sp24: Daniel Endraws
