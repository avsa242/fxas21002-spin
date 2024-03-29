{
    --------------------------------------------
    Filename: sensor.gyroscope.3dof.fxas21002.spin
    Author: Jesse Burt
    Description: Driver for the NXP FXAS21002 3DoF Gyroscope
    Copyright (c) 2022
    Started Jun 07, 2021
    Updated Nov 5, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.gyroscope.common.spinh"
#include "sensor.temp.common.spinh"

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
    ACCEL_DOF       = 0
    GYRO_DOF        = 3
    MAG_DOF         = 0
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL      = 0
    CAL_G_SCL       = 250
    CAL_M_SCL       = 0
    CAL_XL_DR       = 0
    CAL_G_DR        = 200
    CAL_M_DR        = 0

' Bias adjustment (AccelBias(), GyroBias(), MagBias()) read or write
    R               = 0
    W               = 1

' Axis-specific constants
    X_AXIS          = 2
    Y_AXIS          = 1
    Z_AXIS          = 0
    ALL_AXES        = 3

' Temperature scale constants
    C               = 0
    F               = 1

' Operating modes
    SLEEP           = 0
    STANDBY         = 1
    ACTIVE          = 2

' Interrupt flags
    INT_FIFO        = 1 << 6
    INT_RT_THR      = 1 << 4
    INT_DRDY        = 1 << 2

    INT_THS         = 1 << 11
    INT_ZTHS        = 1 << 10
    INT_YTHS        = 1 << 9
    INT_XTHS        = 1 << 8

' Interrupt pin active state/polarity
    ACT_LOW         = 0
    ACT_HI          = 1

' Interrupt output driver modes
    INT_PP          = 0
    INT_OD          = 1

' FIFO modes
    BYPASS          = 0
    FIFO            = 1
    FIFO_ONE        = 2

VAR

    byte _opmd_orig
    byte _addr_bits

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef FXAS21002_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.fxas21002"                  ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ and lookdown(ADDR_BITS: 0, 1)
    ' validate pins, bus freq, I2C address bits
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            _addr_bits := ADDR_BITS << 1
            if (dev_id{} == core#DEVID_RESP)' validate device
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    _opmd_orig := 0

PUB defaults{}
' Set factory defaults
    reset{}

PUB preset_active{}
' Preset: Enable sensor data acquisition and set:
'   full scale: 250dps
    reset{}
    gyro_opmode(ACTIVE)
    gyro_scale(250)

PUB dev_id{}: id
' Read device identification
    id := 0
    readreg(core#WHO_AM_I, 1, @id)

PUB fifo_mode(mode): curr_mode | prev_mode, new_mode
' Set FIFO operation mode
'   Valid values:
'      *BYPASS (0): FIFO disabled
'       FIFO (1): FIFO/circular buffer mode
'       FIFO_ONE (2): fill FIFO buffer, then stop when full
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#F_SETUP, 1, @curr_mode)
    case mode
        BYPASS, FIFO, FIFO_ONE:
            mode <<= core#F_MODE
            new_mode := mode
        other:
            return ((curr_mode >> core#F_MODE) & core#F_MODE_BITS)

    prev_mode := ((curr_mode >> core#F_MODE) & core#F_MODE_BITS)

    { can't switch between FIFO and FIFO_ONE directly, so first switch off FIFO, then switch to the
        new mode }
    if ((mode <> BYPASS) and (prev_mode <> BYPASS))
        mode := (curr_mode & core#F_MODE_MASK)
        writereg(core#F_SETUP, 1, @mode)
        writereg(core#F_SETUP, 1, @new_mode)
    else
        mode := ((curr_mode & core#F_MODE_MASK) | mode)
        writereg(core#F_SETUP, 1, @mode)

PUB fifo_data_overrun{}: flag
' Flag indicating FIFO data has overrun
'   Returns: TRUE (-1) or FALSE (0)
    readreg(core#F_STATUS, 1, @flag)
    return ((flag >> core#F_OVF) & 1) == 1

PUB fifo_full{}: flag
' Flag indicating FIFO is full
'   Returns:
'       FALSE (0): FIFO contains less than FIFOThreshold() samples
'       TRUE(-1): FIFO contains FIFOThreshold() or more samples
    readreg(core#F_STATUS, 1, @flag)
    return ((flag >>core#F_WMKF) & 1) == 1

PUB fifo_int{}: int_src
' Read FIFO interrupts
'   Bits:
'       5: FIFO event (overflow, or watermark/threshold level reached)
'       4..0: number of samples acquired since FIFO event was set
    readreg(core#F_EVENT, 1, @int_src)

PUB fifo_thresh(thresh): curr_thr
' Set FIFO threshold/watermark level, used in interrupt generation
'   Valid values: 0..32 (0 effectively disables this functionality)
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core#F_SETUP, 1, @curr_thr)
    case thresh
        0..32:
        other:
            return (curr_thr & core#F_WMRK_BITS)

    thresh := ((curr_thr & core#F_WMRK_MASK) | thresh)
    writereg(core#F_SETUP, 1, @thresh)

PUB fifo_nr_unread{}: nr_samples
' Number of unread samples stored in FIFO
'   Returns: 0..32
    readreg(core#F_STATUS, 1, @nr_samples)
    return (nr_samples & core#F_CNT_BITS)

PUB gyrobias(x, y, z)
' Read gyroscope calibration offset values
'   x, y, z: pointers to copy offsets to
    long[x] := _gbias[X_AXIS]
    long[y] := _gbias[Y_AXIS]
    long[z] := _gbias[Z_AXIS]

PUB gyro_set_bias(x, y, z)
' Write gyroscope calibration offset values
    _gbias[X_AXIS] := -32768 #> x <# 32767
    _gbias[Y_AXIS] := -32768 #> y <# 32767
    _gbias[Z_AXIS] := -32768 #> z <# 32767

PUB gyro_data(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Gyroscope output registers
    longfill(@tmp, 0, 2)
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ptr_x] := ~~tmp.word[X_AXIS] - _gbias[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS] - _gbias[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS] - _gbias[Z_AXIS]

PUB gyro_data_overrun{}: flag
' Flag indicating gyroscope data overrun
    flag := 0
    readreg(core#DR_STATUS, 1, @flag)
    return ((flag & core#ORUN) <> 0)

PUB gyro_data_rate(rate): curr_rate
' Set gyroscope output data rate, in Hz
'   Valid values:
'       12, 25, 50, 100, 200, 400, 800
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        12, 25, 50, 100, 200, 400, 800:
            rate := lookdownz(rate: 800, 400, 200, 100, 50, 25, 12) << core#DR
        other:
            curr_rate := (curr_rate >> core#DR) & core#DR_BITS
            return lookupz(curr_rate: 800, 400, 200, 100, 50, 25, 12, 12)

    cache_opmode{}

    rate := ((curr_rate & core#DR_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)

    restore_opmode{}

PUB gyro_data_rdy{}: flag
' Flag indicating new gyroscope data available
    flag := 0
    readreg(core#DR_STATUS, 1, @flag)
    return ((flag & core#DRDY) <> 0)

PUB gyro_hpf_freq(freq): curr_freq | hpf_en
' Set Gyroscope high-pass filter cutoff frequency, in milli-Hz
'   Valid values: dependent on gyro_data_rate(), see table below
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    case gyro_data_rate(-2)                     ' check current data rate to
        800:                                    ' determine avail. HPF freqs
            case freq
                15_000, 7_700, 3_900, 1_980:
                    freq := lookdownz(freq: 15_000, 7_700, 3_900, 1_980) << core#SEL
                    hpf_en := 1                 ' if freq is nonzero, enable
                0:
                    hpf_en := 0                 ' otherwise, disable
                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 15_000, 7_700, 3_900, 1_980)
        400:
            case freq
                7_500, 3_850, 1_950, 0_990:
                    freq := lookdownz(freq: 7_500, 3_850, 1_950, 0_990) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 7_500, 3_850, 1_950, 0_990)
        200:
            case freq
                3_750, 1_925, 0_975, 0_495:
                    freq := lookdownz(freq: 3_750, 1_925, 0_975, 0_495) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 3_750, 1_925, 0_975, 0_495)
        100:
            case freq
                1_875, 0_963, 0_488, 0_248:
                    freq := lookdownz(freq: 1_875, 0_963, 0_488, 0_248) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 1_875, 0_963, 0_488, 0_248)
        50:
            case freq
                0_937, 0_481, 0_244, 0_124:
                    freq := lookdownz(freq: 0_937, 0_481, 0_244, 0_124) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0

                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 0_937, 0_481, 0_244, 0_124)
        25:
            case freq
                0_468, 0_241, 0_122, 0_062:
                    freq := lookdownz(freq: 0_468, 0_241, 0_122, 0_062) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0

                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 0_468, 0_241, 0_122, 0_062)
        12:
            case freq
                0_234, 0_120, 0_061, 0_031:
                    freq := lookdownz(freq: 0_234, 0_120, 0_061, 0_031) << core#SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    curr_freq := ((curr_freq >> core#SEL) & core#SEL_BITS)
                    return lookupz(curr_freq: 0_234, 0_120, 0_061, 0_031)

    freq := ((curr_freq & core#SEL_MASK & core#HPF_EN_MASK) | freq | hpf_en)
    cache_opmode{}
    writereg(core#CTRL_REG0, 1, @freq)
    restore_opmode{}

PUB gyro_int{}: int_src
' Read gyroscope interrupts
'   Bit 6..0
'       6 (INT_THS): threshold interrupt detected on one or more axes
'       5 (INT_ZTHS): threshold interrupt detected on Z-axis
'       4: polarity of Z interrupt (0: positive, 1: negative)
'       3 (INT_YTHS): threshold interrupt detected on Z-axis
'       2: polarity of Y interrupt (0: positive, 1: negative)
'       1 (INT_XTHS): threshold interrupt detected on Z-axis
'       0: polarity of X interrupt (0: positive, 1: negative)
    readreg(core#RT_SRC, 1, @int_src)

PUB gyro_int_polarity(state): curr_state
' Set gyroscope interrupt pin active state/polarity
'   Valid values:
'       ACT_LOW (0): active low
'       ACT_HI (1): active high
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG2, 1, @curr_state)
    case state
        ACT_LOW, ACT_HI:
            state <<= core#IPOL
        other:
            return ((curr_state >> core#IPOL) & 1)

    state := ((curr_state & core#IPOL_MASK) | state)
    writereg(core#CTRL_REG2, 1, @state)

PUB gyro_int_mask(mask): curr_mask | reg2, rtcfg, tmp[2]
' Set gyroscope interrupt mask
'   Bits 11..0
'       11: latch interrupts
'       10: z-axis rate threshold interrupt enable
'       9: y-axis rate threshold interrupt enable
'       8: x-axis rate threshold interrupt enable
'       7: not used
'       6 (INT_FIFO): FIFO interrupt enable
'       5: not used
'       4 (INT_RT_THR): rate threshold interrupt enable
'       3: not used
'       2 (INT_DRDY): data ready interrupt enable
'       1: not used
'       0: not used
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG2, 1, @tmp[0])
    readreg(core#RT_CFG, 1, @tmp[1])
    curr_mask.byte[1] := tmp[1]
    curr_mask.byte[0] := tmp[0]
    case mask
        0..%1111_11111111:
            reg2 := mask.byte[0] & core#INT_EN_BITS
            rtcfg := mask.byte[1] & core#RT_CFG_MASK
        other:
            curr_mask.byte[0] &= core#INT_EN_BITS
            return

    mask := ((curr_mask.byte[0] & core#INT_EN_MASK) | reg2)
    writereg(core#CTRL_REG2, 1, @mask)
    mask := ((curr_mask.byte[1] & core#ELE_EFE_MASK) | rtcfg)
    writereg(core#RT_CFG, 1, @mask)

PUB gyro_int_outp_type(type) : curr_type
' Set gyroscope interrupt pin output driver type
'   Valid values:
'       INT_PP (0): push-pull
'       INT_OD (1): open-drain/open-source
'           (when gyro_int_polarity() == 0, 1, respectively)
'   Any other value polls the chip and returns the current setting
    curr_type := 0
    readreg(core#CTRL_REG2, 1, @curr_type)
    case type
        INT_PP, INT_OD:
        other:
            return (curr_type & 1)

    type := ((curr_type & core#PP_OD_MASK) | type)
    writereg(core#CTRL_REG2, 1, @type)

PUB gyro_int_thresh{}: thresh | gscl, lsb
' Get gyroscope interrupt threshold
'   Returns: micro-dps (unsigned)
    gscl := (gyro_scale(-2) * 1_000000)
    lsb := gscl / 128                           ' calc LSB for the thresh reg

    thresh := 0
    readreg(core#RT_THS, 1, @thresh)
    return ((thresh & core#THS_BITS) * lsb)     ' scale to micro-dps

PUB gyro_int_set_thresh(thresh) | gscl, lsb, tmp
' Set gyroscope interrupt threshold, in micro-dps (unsigned)
'   Valid values: 0..(full-scale * 1_000_000); clamped to range
    gscl := gyro_scale(-2) * 1_000000
    lsb := gscl / 128                           ' calc LSB for the thresh reg

    { clamp to range, and preserve DBCNTM bit }
    thresh := (0 #> thresh <# gscl) / lsb
    readreg(core#RT_THS, 1, @tmp)
    thresh := ((tmp & core#THS_MASK) | thresh)

    cache_opmode{}
    writereg(core#RT_THS, 1, @thresh)
    restore_opmode{}

PUB gyro_lpf_freq(freq): curr_freq
' Set gyroscope output data low-pass filter cutoff frequency, in Hz
'   Valid values:
'       4..256 (available values depend on GyroDataRate() setting)
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core#CTRL_REG0, 1, @curr_freq)
    case gyro_data_rate(-2)                     ' check current data rate to
        800:                                    ' determine avail. LPF freqs
            case freq
                256, 128, 64:
                    freq := lookdownz(freq: 256, 128, 64) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 256, 128, 64)
        400:
            case freq
                128, 64, 32:
                    freq := lookdownz(freq: 128, 64, 32) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 128, 64, 32)
        200:
            case freq
                64, 32, 16:
                    freq := lookdownz(freq: 64, 32, 16) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 64, 32, 16)
        100:
            case freq
                32, 16, 8:
                    freq := lookdownz(freq: 32, 16, 8) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 32, 16, 8)
        50:
            case freq
                16, 8, 4:
                    freq := lookdownz(freq: 16, 8, 4) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 16, 8, 4)
        25:
            case freq
                8, 4:
                    freq := lookdownz(freq: 8, 4) << core#BW
                other:
                    curr_freq := ((curr_freq >> core#BW) & core#BW_BITS)
                    return lookupz(freq: 8, 4)
        12:
            case freq
                4:
                    freq := 0
                other:
                    return 4
    freq := ((curr_freq & core#BW_MASK) | freq)
    cache_opmode{}
    writereg(core#CTRL_REG0, 1, @freq)
    restore_opmode{}

PUB gyro_opmode(mode): curr_mode
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

PUB gyro_scale(scale): curr_scl
' Set gyroscope full-scale range, in degrees per second
'   Valid values: 250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#CTRL_REG0, 1, @curr_scl)
    case scale
        250, 500, 1000, 2000:
            scale := lookdownz(scale: 2000, 1000, 500, 250)
            ' find LSB per DPS
            _gres := lookupz(scale: 62_500, 31_250, 15_625, 7_812{5})
        other:
            curr_scl &= core#FS_BITS
            return lookupz(curr_scl: 2000, 1000, 500, 250)

    cache_opmode{}

    scale := ((curr_scl & core#FS_MASK) | scale)
    writereg(core#CTRL_REG0, 1, @scale)

    restore_opmode{}

PUB reset{} | tmp
' Reset the device
    tmp := core#RESET
    writereg(core#CTRL_REG1, 1, @tmp)

PUB temp_data{}: temp_adc
' Temperature ADC data
    readreg(core#TEMP, 1, @temp_adc)
    ~temp_adc

PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp := temp_word * 100
    case _temp_scale
        C:
            return temp
        F:
            return ((temp * 90) / 50) + 32_00
        K:
            return (temp + 273_15)
        other:
            return FALSE

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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

PRI restore_opmode{}
' Restore previously cached opmode, if it wasn't STANDBY
    if (_opmd_orig <> STANDBY)                  ' if original opmode wasn't
        gyro_opmode(_opmd_orig)                 '   STANDBY, switch back to it

PRI cache_opmode{}
' Set chip to STANDBY, if it isn't already, and cache the previous opmode
'   so it can be restored later
    _opmd_orig := gyro_opmode(-2)
    if (_opmd_orig == ACTIVE)
        gyro_opmode(STANDBY)

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $09, $0D, $0E, $10, $11, $13..$15:
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

