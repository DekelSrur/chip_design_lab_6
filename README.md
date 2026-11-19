# Lab 6 – PWM Controller for an RGB LED

SystemVerilog design for the Nexys A7-100T (Xilinx Artix-7) that receives an sRGB pixel over UART and lights an RGB LED in that color with PWM. The board sends the translated LED values back to the PC, and the color can also be edited with the push-buttons.

Built as part of the Chip Design and Verification program (Google & Reichman University, 2026). It extends the UART TX/RX controller of [Lab 5](https://github.com/DekelSrur/chip_design_lab_5), and is extended in [Lab 7](https://github.com/DekelSrur/chip_design_lab_7).

**Team:** Dekel Srur, Avi Shevel

## Features

- **UART**, 57,600 baud, 8N1, with a 16x oversampling receiver. The baud rate is defined in the package.
- **Two messages**: pixel value `{R___,G___,B___}` (each field 000–255) and LED select `{L016}` / `{L017}`. Out-of-range and malformed messages are rejected.
- **Color translation** (`color_translate`): gamma correction through a lookup table, scaling to the PWM resolution and CIE brightness scaling, with one identical datapath per color channel.
- **PWM generation** (`pwm_ctrl`) for two RGB LEDs (LED16, LED17). A new duty cycle is loaded only at the end of a period, so the output never glitches in the middle of a period.
- **Feedback to the PC**: the translated R, G, B values are sent back on the TX line.
- **Push-button editor** (`param_ctrl`): Left / Right select the field (LED, R, G, B), Up / Down change it without wrap-around, Center applies it. Every button is debounced.
- **7-segment display** shows the LED and the color being edited in hex.
- Parameterized and generate-based code, with shared parameters and types in `pkg_lab6`.

## Architecture

```
 uart_rxd -> RX_fsm -> parser -> param_ctrl -> color_translate -> pwm_ctrl -> LED16 / LED17
                                     ^                |
 buttons -> sync -> debouncer -------+                v
                                                   tx_fsm -> uart_tx -> uart_txd

 param_ctrl -> display_mux -> seg7_ctrl -> 7-segment display
```

| Module | Role |
| --- | --- |
| `sync` | Reset synchronizer and input synchronizers |
| `debouncer` | Per-bit debouncer for buttons and switches |
| `RX_fsm` | UART receiver (PHY), 16x oversampling |
| `parser` | Decodes and validates the ASCII messages |
| `param_ctrl` | Button editor; holds the selected LED and color |
| `color_translate` | sRGB to PWM duty cycle (gamma table, CIE scaling) |
| `pwm_ctrl` | PWM counter and comparators for 2 LEDs x 3 channels |
| `tx_fsm`, `uart_tx` | Build and send the response to the PC |
| `display_mux`, `seg7_ctrl` | 7-segment display driver |

## Verification

One self-checking testbench per module and one for the complete chip (`tb_chip_top`), in `tb/`. The testbenches override the timing parameters (for example the number of clocks per bit) to keep simulations short, so the same RTL runs in simulation and on hardware without code changes.

## Repository layout

| Folder | Content |
| --- | --- |
| `src/` | RTL modules and `pkg_lab6` |
| `tb/` | Testbenches |
| `constr/` | Pin and timing constraints (`lab6.xdc`) |
| `vivado/` | Vivado project |
| `doc/` | Diagrams |

## Sending a color from a terminal

Connect to the board's USB-UART port at 57,600 baud, 8N1, and send for example:

```
{L016}
{R255,G000,B000}
```
