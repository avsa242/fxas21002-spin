# fxas21002-spin 
----------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the NXP FXAS21002 3DoF Gyroscope

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Read Gyroscope data (raw, or calculated in millionths of a degree per second)
* Read flags for data ready or overrun
* Set operation mode (power down, sleep, normal/active)
* Set output data rate
* Set high-pass filter cutoff freq for ODR, configure high-pass filter mode
* Set output data low-pass filter cutoff freq
* Set interrupt mask, active pin state, output type, threshold
* Read on-chip temperature sensor
* FIFO: set mode, watermark/threshold level, read overrun & watermark flags, unread samples

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C engine

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81), FlexSpin (tested with 5.5.0)
* P2/SPIN2: FlexSpin (tested with 5.5.0)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [ ] TBD
