{
----------------------------------------------------------------------------------------------------
    Filename:       FXAS21002-Demo.spin
    Description:    Demo of the FXAS21002 driver
        * 3DoF data output
    Author:         Jesse Burt
    Started:        Jul 7, 2021
    Updated:        Jan 9, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine
'#define FXAS21002_I2C_BC
'#pragma exportdef(FXAS21002_I2C_BC)

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.gyroscope.3dof.fxas21002" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=1, ...
                                                RST=24


PUB main() | g[sensor.GYRO_DOF], axis

    setup()

    repeat
        ser.pos_xy(0, 3)
        if ( ser.getchar_noblock() == "c" )     ' press 'c' to calibrate/set the gyro's zero
            cal_gyro()
        repeat
        until sensor.gyro_data_rdy()
        sensor.gyro_dps(@g[sensor.X_AXIS], @g[sensor.Y_AXIS], @g[sensor.Z_AXIS])
        ser.str(@"Gyro (dps): ")
        repeat axis from sensor.X_AXIS to sensor.Z_AXIS
            ser.printf(@"%4.4d.%06.6d     ",    (g[axis] / 1_000_000), ...
                                                ||(g[axis] // 1_000_000) )


PUB cal_gyro()
' Calibrate the gyroscope
    ser.pos_xy(0, 3)
    ser.str(@"Calibrating gyroscope...")
    ser.clear_ln()
    sensor.calibrate_gyro()
    ser.pos_xy(0, 3)
    ser.clear_ln()


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"FXAS21002 driver started")
    else
        ser.strln(@"FXAS21002 driver failed to start - halting")
        repeat

    sensor.preset_active()


DAT
{
Copyright 2025 Jesse Burt

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

