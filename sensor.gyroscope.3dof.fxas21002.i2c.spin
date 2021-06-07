{
    --------------------------------------------
    Filename: sensor.gyroscope.3dof.fxas21002.i2c.spin
    Author: Jesse Burt
    Description: Driver for the NXP FXAS21002 3DoF Gyroscope
    Copyright (c) 2021
    Started Jun 07, 2021
    Updated Jun 07, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    DEF_ADDR        = %0
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF               = 0
    GYRO_DOF                = 3
    MAG_DOF                 = 0
    BARO_DOF                = 0
    DOF                     = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL              = 0
    CAL_G_SCL               = 0 'tbd
    CAL_M_SCL               = 0
    CAL_XL_DR               = 0
    CAL_G_DR                = 0 'tbd
    CAL_M_DR                = 0

' Bias adjustment (AccelBias(), GyroBias(), MagBias()) read or write
    R                       = 0
    W                       = 1

' Axis-specific constants
    X_AXIS                  = 2
    Y_AXIS                  = 1
    Z_AXIS                  = 0
    ALL_AXES                = 3

' Temperature scale constants
    C                       = 0
    F                       = 1

' Operating modes
    SLEEP                   = 0
    STANDBY                 = 1
    ACTIVE                  = 2

VAR

    long _gres, _gbiasraw[GYRO_DOF]
    byte _addr_bits

OBJ

    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
    core: "core.con.fxas21002"                  ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ and lookdown(ADDR_BITS: 0, 1)
    ' validate pins, bus freq, I2C address bits
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            _addr_bits := ADDR_BITS << 1
            if i2c.present(SLAVE_WR | _addr_bits)' test device bus presence
                if deviceid{} == core#DEVID_RESP' validate device 
                    return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults

PUB CalibrateGyro{} | gyrotmp[GYRO_DOF], axis, x, y, z, samples, scale_orig, drate_orig, fifo_orig, scl
' Calibrate the gyroscope

PUB DeviceID{}: id
' Read device identification
    readreg(core#WHO_AM_I, 1, @id)

PUB GyroAxisEnabled(mask): curr_mask
' Enable data output for gyroscope (all axes)

PUB GyroBias(ptr_x, ptr_y, ptr_z, rw) | tmp[GYRO_DOF]
' Read or write/manually set gyroscope calibration offset values

PUB GyroClearInt{}
' Clears out any interrupts set up on the Gyroscope and resets all Gyroscope interrupt registers to their default values.

PUB GyroData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Gyroscope output registers
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ptr_x] := ~~tmp.word[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS]

PUB GyroDataOverrun{}: flag
' Dummy method

PUB GyroDataRate(rate): curr_rate
' Set gyroscope output data rate, in Hz
'   Valid values:

'   Any other value polls the chip and returns the current setting

PUB GyroDataReady{}: flag
' Flag indicating new gyroscope data available

PUB GyroDPS(ptr_x, ptr_y, ptr_z) | tmp[GYRO_DOF]
' Read the Gyroscope output registers and scale the outputs to micro
    gyrodata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[ptr_x] := tmp[X_AXIS] * _gres
    long[ptr_y] := tmp[Y_AXIS] * _gres
    long[ptr_z] := tmp[Z_AXIS] * _gres

PUB GyroHighPass(freq): curr_freq
' Set Gyroscope high

PUB GyroInactiveDur(duration): curr_dur
' Set gyroscope inactivity timer (use GyroInactiveSleep to define behavior on inactivity)

PUB GyroInactiveThr(thresh): curr_thr
' Set gyroscope inactivity threshold (use GyroInactiveSleep to define behavior on inactivity)

PUB GyroInactiveSleep(state): curr_state
' Enable gyroscope sleep mode when inactive (see GyroActivityThr)

PUB GyroInt{}: flag
' Flag indicating gyroscope interrupt asserted

PUB GyroIntSelect(mode): curr_mode
' Set gyroscope interrupt generator selection

PUB GyroLowPassFilter(freq): curr_freq
' Set gyroscope output data low

PUB GyroLowPower(state): curr_state
' Enable low

PUB GyroOpMode(mode): curr_mode
' Set gyroscope operating mode
'   Valid values:
'       SLEEP (0): lowest-power/sleep mode (no data acquisition)
'       STANDBY (1): medium-power mode (no data acquisition)
'       ACTIVE (2): normal-power mode (full functionality, acquire data)
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        SLEEP, STANDBY, ACTIVE:
        other:
            return (curr_mode & core#STATE_BITS)

    mode := ((curr_mode & core#STATE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)

PUB GyroScale(scale): curr_scl
' Set gyroscope full-scale range, in degrees per second
'   Valid values: 125, 250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting

PUB Reset{}
' Reset the device

PUB Temperature{}: temp
' Read chip temperature

PUB TempDataRate(rate): curr_rate
' Set temperature output data rate, in Hz

PUB TempDataReady{}: flag
' Flag indicating new temperature sensor data available

PUB TempScale(scale): curr_scl
' Set temperature scale used by Temperature method

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $00..$15:
            cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD | _addr_bits)

    ' write MSByte to LSByte
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
    '
        other:                                  ' invalid reg_nr
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $09, $0D, $0E, $100, $11, $13..$15:
            cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

    ' write MSByte to LSByte
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
    '
        other:
            return


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
