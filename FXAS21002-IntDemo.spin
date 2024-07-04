{
----------------------------------------------------------------------------------------------------
    Filename:       FXAS21002-IntDemo.spin
    Description:    Demo of the FXAS21002 driver
        * interrupt functionality
    Author:         Jesse Burt
    Started:        Jun 9, 2021
    Updated:        Jul 4, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine
'#define FXAS21002_I2C_BC
'#pragma exportdef(FXAS21002_I2C_BC)

CON

    _clkmode    = cfg._clkmode
    _xinfreq    = cfg._xinfreq


OBJ

    cfg:    "boardcfg.flip"
    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.gyroscope.3dof.fxas21002" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=1


PUB main()

    setup()
    sensor.preset_active()                      ' default settings, but enable
                                                ' measurements, and set scale
                                                ' factor

'   set threshold in micro-degrees per second. The axes' thresholds can't be
'   independently set - all three are set to the value passed in the X-axis
'   parameter (first param):
    sensor.gyro_int_set_thresh(100_000000)
    sensor.gyro_int_mask(sensor.INT_ZTHS)

    repeat
        ser.pos_xy(0, 3)
        show_gyro_data()

        ser.pos_xy(0, 4)
        ser.printf1(@"Interrupt flags: %07.7b", sensor.gyro_int())

        if ( ser.getchar_noblock() == "c" )     ' press the 'c' key in the demo
            cal_gyro()                          ' to calibrate sensor offsets


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"FXAS21002 driver started (I2C)")
    else
        ser.strln(@"FXAS21002 driver failed to start - halting")
        repeat

#include "gyrodemo.common.spinh"

DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

