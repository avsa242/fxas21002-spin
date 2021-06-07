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
    STATUS          = $00
    OUT_X_MSB       = $01
    OUT_X_LSB       = $02
    OUT_Y_MSB       = $03
    OUT_Y_LSB       = $04
    OUT_Z_MSB       = $05
    OUT_Z_LSB       = $06
    DR_STATUS       = $07
    F_STATUS        = $08
    F_SETUP         = $09
    F_EVENT         = $0A
    INT_SRC_FLAG    = $0B
    WHO_AM_I        = $0C

    CTRL_REG0       = $0D
    CTRL_REG0_MASK  = $FF
        BW          = 6
        SPIW        = 5
        SEL         = 3
        HPF_EN      = 2
        FS          = 0
        BW_BITS     = %11
        SEL_BITS    = %11
        FS_BITS     = %11
        BW_MASK     = (BW_BITS << BW) ^ CTRL_REG0_MASK
        SPIW_MASK   = (1 << SPIW) ^ CTRL_REG0_MASK
        SEL_MASK    = (SEL_BITS << SEL) ^ CTRL_REG0_MASK
        HPF_EN_MASK = (1 << HPF_EN) ^ CTRL_REG0_MASK
        FS_MASK     = FS_BITS ^ CTRL_REG0_MASK

    RT_CFG          = $0E
    RT_SRC          = $0F
    RT_THS          = $10
    RT_COUNT        = $11
    TEMP            = $12

    CTRL_REG1       = $13
    CTRL_REG1_MASK  = $7F
        RST         = 6
        ST          = 5
        DR          = 2
        ACTIVE      = 1
        READY       = 0
        STATE       = 0                         ' pseudo-field: READY, ACTIVE
        DR_BITS     = %111
        STATE_BITS  = %11
        RST_MASK    = (1 << RST) ^ CTRL_REG1_MASK
        ST_MASK     = (1 << ST) ^ CTRL_REG1_MASK
        DR_MASK     = (DR_BITS << DR) ^ CTRL_REG1_MASK
        ACTIVE_MASK = (1 << ACTIVE) ^ CTRL_REG1_MASK
        READY_MASK  = 1 ^ CTRL_REG1_MASK
        STATE_MASK  = STATE_BITS ^ CTRL_REG1_MASK

    CTRL_REG2       = $14
    CTRL_REG3       = $15

PUB Null{}
' This is not a top-level object

