# FPGA Lab 2: Introduction to FPGA Development
<p align="center">
Prof. John Wawrzynek
</p>
<p align="center">
TAs: (ordered by section) Daniel Endraws, Dhruv Vaish, Rohit Kanagal
</p>
<p align="center">
Department of Electrical Engineering and Computer Science
</p>
<p align="center">
College of Engineering, University of California, Berkeley
</p>

## Before You Start This Lab
Make sure that you have gone through and completed the steps involved in Lab 1.
Let the TA know if you are not signed up for this class on Ed or if you do not have a class account (`eecs151-xxx`), so we can get that sorted out.

To fetch the skeleton files for this lab, `cd` to the git repository (`fpga-labs-<username>`) that you had cloned in the first lab and pull from the `staff` repository: `git pull staf main`

You should be comfortable with basic Verilog to complete this lab, be sure to refresh with and refer back to lecture slides or the [Verilog Primer Slides](https://www.eecs151.org/files/verilog/Verilog_Primer_Slides.pdf). *Note the verilog primer slides do not adhere to the no flip-flop inference policy outlined below*

Put yourself on the help queue if you have questions during the FPGA lab session or an FPGA TA's office hours.
The queue form can be found on the EECS151 course website.

**Note: We enforce a no flip-flop inference policy in this class.
You must use the register library in `EECS151.v` whenever creating registers in Verilog.
This policy applies to all labs and projects.**

<details open> 
<summary> Table of Contents (click to close) </summary>

- [FPGA Lab 2: Introduction to FPGA Development](#fpga-lab-2-introduction-to-fpga-development)
  - [Before You Start This Lab](#before-you-start-this-lab)
  - [A Structural and Behavioral Adder Design](#a-structural-and-behavioral-adder-design)
    - [Build a Structural 14-bit Adder](#build-a-structural-14-bit-adder)
      - [Makefile-Based Build Flow](#makefile-based-build-flow)
    - [Build a Behavioral 14-bit Adder](#build-a-behavioral-14-bit-adder)
  - [Simulating the Adder](#simulating-the-adder)
    - [Overview of Testbench Skeleton](#overview-of-testbench-skeleton)
    - [Verilog Style Guide](#verilog-style-guide)
      - [Naming](#naming)
      - [Guidelines for Constructs (excluding testbenches)](#guidelines-for-constructs-excluding-testbenches)
    - [Running the Simulation](#running-the-simulation)
      - [VCS](#vcs)
      - [Icarus Verilog](#icarus-verilog)
    - [Analyzing the Waveform](#analyzing-the-waveform)
      - [Helpful Tip: Reloading Waveforms](#helpful-tip-reloading-waveforms)
    - [Exhaustive Testing vs Random Testing](#exhaustive-testing-vs-random-testing)
  - [Build Your First Sequential Digital Circuit](#build-your-first-sequential-digital-circuit)
    - [Clock Sources](#clock-sources)
    - [Build a 4-bit Counter](#build-a-4-bit-counter)
  - [Simulating the Counter](#simulating-the-counter)
    - [Analyzing the Simulation](#analyzing-the-simulation)
      - [Fixing Unknown Signals](#fixing-unknown-signals)
  - [Put the Counter on the FPGA](#put-the-counter-on-the-fpga)
  - [Lab Deliverables](#lab-deliverables)
    - [Lab Checkoff (due: next lab)](#lab-checkoff-due-next-lab)
  - [Acknowledgement](#acknowledgement)

</details>

## A Structural and Behavioral Adder Design

### Build a Structural 14-bit Adder
To help you with this task, you may wish to refer to the full adder slides and `Code Generation with for-generate loops` slide
in these [Verilog Primer Slides](https://www.eecs151.org/files/verilog/Verilog_Primer_Slides.pdf) (slide 35).

Open `lab2/src/full_adder.v` and **fill in the logic** to produce the full adder outputs from the inputs. You can use either structural or behavior verilog for this.

Open `lab2/src/structural_adder.v` and **construct a ripple carry adder** using the full adder cells you designed earlier and a 'for-generate loop'. This must be in structural verilog. 

Inspect the `z1top.v` top-level module and see how your structural adder is instantiated and hooked up to the top-level signals.
For now, just look at the `user_adder` instance of your structural adder.
As we learned in previous lab, the basic I/O options on the PYNQ-Z1 board are limited.
*How are we getting two 3-bit integers as inputs to the adder from the PYNQ board?*

#### Makefile-Based Build Flow
Here is an overview of the `make` targets available in the `fpga_labs_sp23/labX` folders:
- `make lint` - Lint your Verilog with Verilator; checks for common Verilog typos, mistakes, and syntax errors
- `make elaborate` - Elaborate (but don't synthesize) the Verilog with Vivado and open the GUI to view the schematic
- `make synth` - Synthesize `z1top` and put logs and outputs in `build/synth`
- `make impl` - Implement (place and route) the design, generate the bitstream, and put logs and outputs in `build/impl`
- `make program` - Program the FPGA with the bitstream in `build/impl`
- `make program-force` - Program the FPGA with the bitstream in `build/impl` **without** re-running synthesis and implementation if the source Verilog has changed
- `make vivado` - Launch the Vivado GUI

Running `make program` will run all the steps required to regenerate a bitstream if the Verilog sources have changed.

**Use this flow** to generate a bitstream and program the FPGA.
Try running `make lint` and `make elaborate` before you run `make program`.
*Note*: `make lint` may give you a false warning about a combinational path (`%Warning-UNOPTFLAT`) and might fail - you can safely ignore it.

**Try entering** different binary numbers into your adder with the switches and buttons and see that the correct sum is displayed on the LEDs.
If the circuit doesn't work properly on your first try, don't worry and move on to the next section where we simulate the `structural_adder` and you can easily fix bugs.

### Build a Behavioral 14-bit Adder
Check out `lab2/src/behavioral_adder.v`.
It has already been filled with the appropriate logic for you.
Notice how behavioral Verilog allows you to describe the function of a circuit rather than the topology or implementation.

In `z1top.v`, you can see that the `structural_adder` and the `behavioral_adder` are both instantiated in the self-test section.
A module called `adder_tester` (in `src/adder_tester.v`) has been written for you that will check that the sums generated by both your adders are equal for all possible input combinations of `a` and `b`.

If both your adders are operating identically, both RGB LEDs will light up (with red and blue).
Verify this on your board.

## Simulating the Adder
Let's run some simulations on the `structural_adder` in software to ensure it works.
Typically, this is done before putting our design on the FPGA, but because the adder is simple, we started with the FPGA this time.

To do this, we will need to use a *Verilog testbench*.
A Verilog testbench is designed to test a Verilog module by supplying it with the inputs it needs (stimulus signals) and testing whether the outputs of the module match what we expect.

### Overview of Testbench Skeleton
Check the provided testbench skeleton in `lab2/sim/adder_testbench.v`.
Let's go through what every line of this testbench does.

```verilog
`timescale 1ns/1ns
```

The timescale declaration needs to be at the top of every testbench file.
```verilog
`timescale (simulation time unit)/(simulation resolution)
```

The first argument to the timescale declaration is the simulation time unit.
It specifies how much time *1 unit* of simulation time represents.
In this case, we have defined the simulation time unit to be one nanosecond, so *1 unit* of simulation time equals one nanosecond.

The second argument to the timescale declaration is the simulation resolution, which tells the simulator to model transient behavior of your circuit at that resolution.
In our example it is also 1 nanosecond.
For this lab, we aren't modeling any gate delays, so the resolution can safely equal the time unit.

```verilog
`define SECOND 1000000000
`define MS 1000000
```

These are some macros defined for our testbench.
They are similar to `#define` directives in C.
`define` macros should be used to declare named constants which are used in your RTL or testbench.
For example, in this testbench, `SECOND` is defined as the number of nanoseconds in one second.

```verilog
module adder_testbench();
  // Testbench code goes here
endmodule
```

`adder_testbench` is a testbench module.
It is not intended to be placed on an FPGA, but rather it is to be run by a circuit simulator.
All your testbench code goes in this module.
We will instantiate our DUT (device under test) in this module.

```verilog
reg [13:0] a = 0;
reg [13:0] b;
wire [14:0] sum;
```
Now we declare nets to hold the inputs and outputs that go in and out of the DUT.
Notice that the inputs to the `structural_adder` are declared as `reg` type nets and the outputs are declared as `wire` type nets.
The inputs nets (`a`, `b`) are declared as `reg` since they are assigned inside the testbench's `initial` block.
The output net (`sum`) is declared as `wire` because *any connection to the output of an instantiated module must be a wire*.

*Note*: we can set the initial value of `reg` nets in the testbench to drive a particular value into the DUT at simulation time 0 (e.g. `a`).

Now we instantiate the DUT and connect its ports to the nets we have declared in our testbench:

```verilog
structural_adder sa (
  .a(a),
  .b(b),
  .sum(sum)
);
```

The `initial begin ... end` block is the "main()" function for our testbench, and where the simulation begins execution.

This block enables simulator-specific waveform dumping for the 2 RTL simulators we are using.
Verilog *system tasks* are prefixed by a dollar sign (e.g. `$dumpfile`).
System tasks are similar to function calls, and they are implemented by the simulator.

In the `initial` block we drive the DUT inputs using blocking (`=`) assignments:
```verilog
    a = 14'd1;
    b = 14'd1;
    #(2);
    assert(sum == 'd2);
```

In Verilog we can construct literal values using the syntax `<bit width>'<radix><value>`.
Here are a few examples:
  - `14'd1` = a 14-bit literal with value = 1 (`d` = radix 10 - decimal)
  - `32'hcafef00d` = a 32-bit literal with value = 0xCAFEFOOD (`h` = radix 16 - hexadecimal)
  - `8'b1010_0001` = an 8-bit literal with value = 0b10100001 (`b` = radix 2 - binary)
      - *Note*: Use underscores to make reading the literal easier
  - `'hFFFF_0000` = a 32-bit literal with value = 0xFFFF0000
      - *Note*: You can omit the bit width and let Verilog use the minimum number of bits necessary to construct the literal. This is not recommended for RTL, but is often OK for testbenches.

Since the adder is a combinational circuit, once we set its inputs (`a` and `b`), we must advance time for the inputs to propagate to the output (`sum`) through the circuit, before we can inspect the output.

We can advance simulation time using delay statements.
A delay statement takes the form `#(units);`, where *1 unit* represents the simulation time unit defined in `timescale` declaration.
For instance the statement `#(2);` would advance the simulation for 2 time units = 2 * 1ns = 2ns.

After advancing time, `sum` should have the value `2`.
We can use the `assert` statement to check this condition. If the assertion fails, the simulator will emit an error:

```verilog
    assert(sum == 'd1) else $display("ERROR: Expected sum to be 1, actual value: %d", sum);
```
Note that you can provide an error message using the `$display` system task which takes a format string and arguments similar to `printf()` in C.

You can also use regular `if` statements to check conditions:
```verilog
    if (sum != 'd20) begin
        $error("Expected sum to be 20, a: %d, b: %d, actual value: %d", a, b, sum);
        $fatal(1);
    end
```
The `$error()` system task also takes a format string and prints an error to the console.
Both the `$error()` system task and `assert` *won't* halt and exit the simulation if there's a failure; you must use the `$fatal()` system task if you want to kill the simulation immediately.

Finally, the `$finish()` system task gracefully exits the simulation:
```verilog
    $finish();
end
```

### Verilog Style Guide
We have established a few guidelines to write **synthesizable** high description languages (HDL) that is physically realizable. Because Verilog and SystemVerilog can be used for test harness design and modeling, there exist numerous constructs that **cannot be synthesized**. That is to say, these constructs cannot be mapped into actual hardware. There are also cases in which certain hardware descriptions can be translated into **extremely inefficient hardware**. 

#### Naming
- **lower_snake_case** - declarations, instance names, signals (wires, regs, ports), variables, functions 
```
module my_module ...
wire my_wire;
```
- **CAPS** - Constants, macros 
```
localparam GENERATOR_CONSTANT = 1’b1;
`define FIXED_NUMBER 5
```

#### Guidelines for Constructs (excluding testbenches)
- `initial` -  `initial` is synthesizable on FPGA, but will be ignored by most ASIC tools. Use of `initial` in hardware blocks typically signals improper reset/startup logic. Acceptable in testbenches.
- `delay(#)` - Delays cannot be realized in hardware. Acceptable in testbenches.


### Running the Simulation
There are 2 RTL simulators we can use:
- **VCS** - proprietary, only available on lab machines, fast
- **Icarus Verilog** - open source, runs on Windows/OSX/Linux, somewhat slower

They all take in Verilog RTL and a Verilog testbench module and output:
- A waveform file (.vpd, .vcd, .fst) that plots each signal in the testbench and DUT across time
- A text dump containing anything that was printed during the testbench execution

#### VCS
We recommend using VCS.
Run the Makefile from `fpga_labs_sp23/lab2`
```shell
make sim/adder_testbench.vpd
```
This will generate a waveform file `sim/adder_testbench.vpd`, which you can view using `dve`.
Login to the lab machines physically or use X2go and run:
```shell
dve -vpd sim/adder_testbench.vpd &
```

<p align="center">
<img src="./figs/dve.png" width="800" />
</p>

From left to right, you can see the `Hierarchy`, `Signals`, and `Source Code` windows.
The `Hierarchy` window lets you select a particular module instance in the testbench to view its signals.
In the `Signals` window, you can select multiple signals (by Shift-clicking) and then right-click → 'Add To Waves' → 'New Wave View' to plot the waveforms for the selected signals.

<p align="center">
<img src="./figs/dve_wave.png" width="800" />
</p>

Here are a few useful shortcuts:
- **Click on waveform**: Sets cursor position
- **O**: Zoom out of waveform
- **+**: Zoom into waveform
- **F**: Fit entire waveform into viewer (zoom full)
- **Left Click + Drag Left/Right**: Zoom in on waveform section

#### Icarus Verilog
Icarus Verilog is available on the lab machines.
You can also install Icarus Verilog and gtkwave on your laptop via Homebrew ([iverilog](https://formulae.brew.sh/formula/icarus-verilog), [gtkwave](https://formulae.brew.sh/cask/gtkwave)) or a package manager with Linux or WSL.

Run `make sim/adder_testbench.fst` to launch a simulation with Icarus and to produce a FST waveform file.
You can open the FST by running `gtkwave sim/adder_testbench.fst &` locally or on the lab machines.

### Analyzing the Waveform
Open the waveform file using DVE or `gtkwave`.
**Plot** the `a`, `b`, and `sum` signals.
You should be able to see the signals change as specified in the testbench.
For example, you should see the `a` signal start at 1 and then become 0 after 2 ns.

#### Helpful Tip: Reloading Waveforms
When you re-run your simulation and you want to plot the newly generated signals in DVE or gtkwave, you don't need to close and reopen the waveform viewer.
Use Shift + Ctrl + R in gtkwave or File → Reload Databases in DVE to reload the waveform file.

### Exhaustive Testing vs Random Testing
In the `adder_testbench` we have selected just a few values of `a`, `b`, and `sum` to verify.
Is it reasonable to exhaustively test all possible combinations of `a` and `b` for a 14-bit adder in simulation?
At what adder width is it no longer feasible?

You can use a `for` loop (similar to C) in the `initial` block to construct an exhaustive adder testbench:
```verilog
integer ai, bi;
initial begin
    for (ai = 0; ai < 1024; ai = ai + 1) begin
        for (bi = 0; bi < 1024; bi = bi + 1) begin
            a = ai;
            b = bi;
            // delay + assert
        end
    end
end
```

When exhaustive testing isn't feasible, we often resort to random stimulus instead.
In this case, you can use the `$urandom()` system task to generate an unsigned random number.

```verilog
  a = $urandom();
  b = $urandom();
```

## Build Your First Sequential Digital Circuit
In this section, you will design a 4-bit wrap-around counter that increments every second.
The counter value is shown on the LEDS 0-3 of the PYNQ board.

### Clock Sources
Look at the [PYNQ Reference Manual](https://reference.digilentinc.com/reference/programmable-logic/pynq-z1/reference-manual).
Read Section 11 about the clock sources available on the PYNQ.
We are using the 125 MHz clock from the Ethernet PHY IC on the PYNQ board that connects to pin H16 of the FPGA chip.

Look at the `lab2/src/z1top.v` top-level module and its `CLK_125MHZ_FPGA` input.
```verilog
module z1top (
    input CLK_125MHZ_FPGA,
    ...
);
```

We can access the clock signal from our Verilog top-level module and can propagate this clock signal to any submodules that may need it.

**In `z1top.v`, comment out line 2 to place the counter circuit on the FPGA**, like this:
```verilog
1 | // Comment out this line when you want to instantiate your counter
2 | // `define ADDER_CIRCUIT
```

### Build a 4-bit Counter

Your circuit receives a clock signal with a period of 8 ns (125 MHz). How many clock cycles are equivalent to one second? Note:
```
Time (sec) = Clock Period * Number of cycles
```

Build a 4-bit counter that will increment its value every second (and loop back to 0 once all 4 bits are used), and display the corresponding value on bits `3:0` of the IO LEDs.
There is one caveat: the counter only counts if a 'clock enable' signal (in this case, called `ce`) is 1.
If it's 0, the counter should stay at the same value.

Some initial code has been provided in `src/counter.v` to help you get started.

## Simulating the Counter
See the simulation skeleton in `sim/counter_testbench.v`.

The skeleton has code to generate a clock for the DUT (`counter`):
```verilog
reg clock = 0;
always #(4) clock <= ~clock;
```
We set the value of the clock net to 0 at the very start of the simulation.
The next line toggles the clock signal every 4ns, i.e. half period of 125 MHz clock.

**Your task**: write a testbench for the `counter`.
Set the clock enable (`ce`) signal on and off and step time forward to test your counter.
Use `assert` or `if` statements to verify the proper behavior of the `counter`.

You can use `repeat` and `@(event)` statements, in addition to `#(delay)`, to advance time based on a clock edge.
For example
```verilog
repeat (10) @(posedge clock);
```
will advance time until 10 rising clock edges are seen.

Run the simulation in the same way:
```bash
make sim/counter_testbench.vpd  # vcs
make sim/counter_testbench.fst  # iverilog
```

*Note*: simulating even a simple circuit for 1 second can take a long time.
You may want to modify your `counter` to count up every 1/1000th of a second, so you can run simulation for a shorter duration.
Once your design simulates successfully, you can change a constant in your `counter` to count up every second.

### Analyzing the Simulation
When you open the waveform, you *may* see that your counter signal is just a red line. What’s going on?

#### Fixing Unknown Signals
Blue lines (shown as `Z`) in a waveform viewer indicate high-impedance (unconnected) signals.
We won't be using high-impedance signals in our designs, so blue lines or `Z` indicate something in our testbench or DUT isn't wired up properly.

Red lines (shown as `X`) in a waveform viewer indicate a signal has an unknown value.
This can happen if you create registers with undefined initial values.
However, the registers in the `EECS151.v` library declare initial values, so you shouldn't encounter issues with this.
It is good practice to use a reset signal to force all registers to a known, desired initial state,
but this isn't required for this lab.

**Do not set initial values for 'wire' type nets; this will cause issues with synthesis, and may cause X's in simulation.**

Now run the simulation again until you feel confident in your design.

## Put the Counter on the FPGA

Once you're confident that your counter works, program the FPGA using the make-based flow as before.
`z1top` connects your counter to the 125 MHz clock and connects switch 0 as the clock enable signal. **If you modified `src/counter.v`'s counting period to make the simulation shorter, make sure you undo that change when programming the FPGA (i.e. make sure it counts 1 second when programming).**
If done correctly, LEDs 0 through 3 should continually count up by 1 each second.

This process, where we use simulation to verify the functionality of a module before programming it onto the FPGA, is invaluable and will be the one we use throughout this semester.

## Lab Deliverables
### Lab Checkoff (due: next lab)
To checkoff for this lab, have these things ready to show the TA:
  - Your FPGA, programmed with the adder circuit and with both RGB LEDs (LEDs 4 and 5) lit up showing correctness. Be ready to explain how your structural adder works.
  - A waveform of the testbench you wrote for your counter and its clock enable functionality.
  - Be ready to program your FPGA with the counter and demonstrate that the counter can be enabled/disabled.

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
- Fa21: Vighnesh Iyer, Charles Hong, Zhenghan Lin, Alisha Menon
- Sp22: Alisha Menon, Yikuan Chen, Seah Kim
- Fa22: Simon Guo, Yikuan Chen
- Sp23: Rahul Kumar, Yukio Miyasaka, Dhruv Vaish
