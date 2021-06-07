{
    --------------------------------------------
    Filename: FXAS21002-Demo.spin
    Author: Jesse Burt
    Description: Demo of the FXAS21002 driver
    Copyright (c) 2021
    Started Jun 07, 2021
    Updated Jun 07, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    SER_BAUD    = 115_200
    LED         = cfg#LED1

    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000
    ADDR_BITS   = %1
' --

OBJ

    cfg   : "core.con.boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    gyro    : "sensor.gyroscope.3dof.fxas21002.i2c"

PUB Main{} | x, y, z

    setup{}
    gyro.gyroopmode(gyro#ACTIVE)
    repeat
        gyro.gyrodata(@x, @y, @z)
        ser.position(0,3)
        ser.printf3(string("%d   %d   %d    "), x, y, z)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if gyro.startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS)
        ser.strln(string("FXAS21002 driver started"))
    else
        ser.strln(string("FXAS21002 driver failed to start - halting"))
        repeat


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
