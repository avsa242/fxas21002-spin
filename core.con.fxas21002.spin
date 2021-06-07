{
    --------------------------------------------
    Filename: core.con.fxas21002.spin
    Author: Jesse Burt
    Description: HW-specific low-level constants
    Copyright (c) 2021
    Started Jun 07, 2021
    Updated Jun 07, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $20 << 1                  ' 7-bit format slave address
    T_POR           = 1_000                     ' startup time (usecs)

    DEVID_RESP      = $D7                       ' device ID expected response

' Register definitions
    WHO_AM_I        = $0C

PUB Null{}
' This is not a top-level object

