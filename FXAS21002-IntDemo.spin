{
    --------------------------------------------
    Filename: FXAS21002-IntDemo.spin
    Author: Jesse Burt
    Description: Demo of the FXAS21002 driver:
        interrupt functionality
    Copyright (c) 2022
    Started Jun 9, 2021
    Updated Nov 5, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

' I2C
    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_FREQ    = 400_000
    ADDR_BITS   = 1
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

OBJ

    cfg     : "boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    sensor  : "sensor.gyroscope.3dof.fxas21002"

PUB main{}

    setup{}
    sensor.preset_active{}                        ' default settings, but enable
                                                ' measurements, and set scale
                                                ' factor

'   set threshold in micro-degrees per second. The axes' thresholds can't be
'   independently set - all three are set to the value passed in the X-axis
'   parameter (first param):
    sensor.gyro_int_set_thresh(100_000000)
    sensor.gyro_int_mask(sensor#INT_ZTHS)

    repeat
        ser.pos_xy(0, 3)
        show_gyro_data{}

        ser.pos_xy(0, 4)
        ser.bin(sensor.gyro_int{}, 7)           ' show interrupt flags

        if (ser.rx_check{} == "c")              ' press the 'c' key in the demo
            cal_gyro{}                          ' to calibrate sensor offsets

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if sensor.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS)
        ser.strln(string("FXAS21002 driver started (I2C)"))
    else
        ser.strln(string("FXAS21002 driver failed to start - halting"))
        repeat

#include "gyrodemo.common.spinh"

DAT
{
Copyright 2022 Jesse Burt

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

