{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.gyroscope.3dof.fxas21002.spin
    Description:    Driver for the NXP FXAS21002 3DoF Gyroscope
    Author:         Jesse Burt
    Started:        Jun 7, 2021
    Updated:        May 28, 2026
    Copyright (c) 2026 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.gyroscope.common.spinh"
#include "sensor.temp.common.spinh"


CON

    { default I/O configuration - these can be overridden by the parent object }
    SCL             = 28
    SDA             = 29
    I2C_FREQ        = 100_000
    I2C_ADDR        = 0
    RST             = 0


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

    SLAVE_WR        = core.SLAVE_ADDR
    SLAVE_RD        = core.SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    DEF_ADDR        = %0
    I2C_MAX_FREQ    = core.I2C_MAX_FREQ


VAR

    byte _opmd_orig
    byte _addr_bits
    byte _RST


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef FXAS21002_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.fxas21002"                ' hw-specific constants
    time:   "time"                              ' basic timing functions


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(SCL, SDA, I2C_FREQ, I2C_ADDR, RST)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS, RST_PIN): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   RST_PIN:    reset, 0..31 (optional; use -1 to disable)
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   ADDR_BITS:  I2C alternate address bit, 0..1
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            { promote any non-zero value for ADDR_BITS to '1' }
            _addr_bits := ((ADDR_BITS <> 0) & 1) << 1
            _RST := RST_PIN
            if ( dev_id() == core.DEVID_RESP )  ' validate device
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    _opmd_orig := 0


PUB defaults()
' Set factory defaults
    reset()


PUB preset_active()
' Preset: Enable sensor data acquisition and set:
'   full scale: 250dps
    reset()
    gyro_opmode(ACTIVE)
    gyro_scale(250)


PUB dev_id(): id
' Read device identification
    return readreg(core.WHO_AM_I)


PUB fifo_mode(mode=-2): cm | prev_mode, new_mode
' Set FIFO operation mode
'   Valid values:
'      *BYPASS (0): FIFO disabled
'       FIFO (1): FIFO/circular buffer mode
'       FIFO_ONE (2): fill FIFO buffer, then stop when full
'   Any other value polls the chip and returns the current setting
    cm := readreg(core.F_SETUP)
    case mode
        BYPASS, FIFO, FIFO_ONE:
            mode <<= core.F_MODE
            new_mode := mode
            prev_mode := ((cm >> core.F_MODE) & core.F_MODE_BITS)

            { can't switch between FIFO and FIFO_ONE directly, so first switch off FIFO,
                then switch to the new mode }
            if ( (mode <> BYPASS) and (prev_mode <> BYPASS) )
                mode := (cm & core.F_MODE_MASK)
                writereg(core.F_SETUP, mode)
                writereg(core.F_SETUP, new_mode)
            else
                mode := ((cm & core.F_MODE_MASK) | mode)
                writereg(core.F_SETUP, mode)
        other:
            return ((cm >> core.F_MODE) & core.F_MODE_BITS)


PUB fifo_data_overrun(): fl
' Flag indicating FIFO data has overrun
'   Returns: TRUE (-1) or FALSE (0)
    return ( (readreg(core.F_STATUS) >> core.F_OVF) & 1) == 1


PUB fifo_full(): fl
' Flag indicating FIFO is full
'   Returns:
'       FALSE (0): FIFO contains less than FIFOThreshold() samples
'       TRUE(-1): FIFO contains FIFOThreshold() or more samples
    return ( (readreg(core.F_STATUS) >> core.F_WMKF) & 1) == 1


PUB fifo_int(): i
' Read FIFO interrupts
'   Bits:
'       5: FIFO event (overflow, or watermark/threshold level reached)
'       4..0: number of samples acquired since FIFO event was set
    return readreg(core.F_EVENT)


PUB fifo_thresh(thresh=-2): ct
' Set FIFO threshold/watermark level, used in interrupt generation
'   Valid values: 0..32 (0 effectively disables this functionality)
'   Any other value polls the chip and returns the current setting
    ct := readreg(core.F_SETUP)
    case thresh
        0..32:
            thresh := ((ct & core.F_WMRK_MASK) | thresh)
            writereg(core.F_SETUP, thresh)
        other:
            return (ct & core.F_WMRK_BITS)


PUB fifo_nr_unread(): n
' Number of unread samples stored in FIFO
'   Returns: 0..32
    return (readreg(core.F_STATUS) & core.F_CNT_BITS)


PUB gyrobias(x, y, z)
' Read gyroscope calibration offset values
'   x, y, z: pointers to variables to copy offsets to
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
    i2c.start()
    i2c.write(SLAVE_WR|_addr_bits)
    i2c.write(core.OUT_X_MSB)
    i2c.start()
    i2c.write(SLAVE_RD|_addr_bits)
    i2c.rdblock_msbf(@tmp, 6, i2c.NAK)
    i2c.stop()

    long[ptr_x] := ~~tmp.word[X_AXIS] - _gbias[X_AXIS]
    long[ptr_y] := ~~tmp.word[Y_AXIS] - _gbias[Y_AXIS]
    long[ptr_z] := ~~tmp.word[Z_AXIS] - _gbias[Z_AXIS]


PUB gyro_data_overrun(): f
' Flag indicating gyroscope data overrun
    return ( (readreg(core.DR_STATUS) & core.ORUN) <> 0)


PUB gyro_data_rate(rate=-2): cr
' Set gyroscope output data rate, in Hz
'   Valid values:
'       12, 25, 50, 100, 200, 400, 800
'   Any other value polls the chip and returns the current setting
    cr := readreg(core.CTRL_REG1)
    case rate
        12, 25, 50, 100, 200, 400, 800:
            rate := lookdownz(rate: 800, 400, 200, 100, 50, 25, 12) << core.DR
            cache_opmode()

            rate := ((cr & core.DR_MASK) | rate)
            writereg(core.CTRL_REG1, rate)

            restore_opmode()
        other:
            cr := (cr >> core.DR) & core.DR_BITS
            return lookupz(c: 800, 400, 200, 100, 50, 25, 12, 12)


PUB gyro_data_rdy(): f
' Flag indicating new gyroscope data available
    return ( (readreg(core.DR_STATUS) & core.DRDY) <> 0)


PUB gyro_hpf_freq(freq=-2): cf | hpf_en
' Set Gyroscope high-pass filter cutoff frequency, in milli-Hz
'   Valid values: dependent on gyro_data_rate(), see table below
'   Any other value polls the chip and returns the current setting
    cf := readreg(core.CTRL_REG0)
    case gyro_data_rate()                       ' check current data rate to
        800:                                    ' determine avail. HPF freqs
            case freq
                15_000, 7_700, 3_900, 1_980:
                    freq := lookdownz(freq: 15_000, 7_700, 3_900, 1_980) << core.SEL
                    hpf_en := 1                 ' if freq is nonzero, enable
                0:
                    hpf_en := 0                 ' otherwise, disable
                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(c: 15_000, 7_700, 3_900, 1_980)
        400:
            case freq
                7_500, 3_850, 1_950, 0_990:
                    freq := lookdownz(freq: 7_500, 3_850, 1_950, 0_990) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(c: 7_500, 3_850, 1_950, 0_990)
        200:
            case freq
                3_750, 1_925, 0_975, 0_495:
                    freq := lookdownz(freq: 3_750, 1_925, 0_975, 0_495) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(c: 3_750, 1_925, 0_975, 0_495)
        100:
            case freq
                1_875, 0_963, 0_488, 0_248:
                    freq := lookdownz(freq: 1_875, 0_963, 0_488, 0_248) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(cf: 1_875, 0_963, 0_488, 0_248)
        50:
            case freq
                0_937, 0_481, 0_244, 0_124:
                    freq := lookdownz(freq: 0_937, 0_481, 0_244, 0_124) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0

                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(cf: 0_937, 0_481, 0_244, 0_124)
        25:
            case freq
                0_468, 0_241, 0_122, 0_062:
                    freq := lookdownz(freq: 0_468, 0_241, 0_122, 0_062) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0

                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(cf: 0_468, 0_241, 0_122, 0_062)
        12:
            case freq
                0_234, 0_120, 0_061, 0_031:
                    freq := lookdownz(freq: 0_234, 0_120, 0_061, 0_031) << core.SEL
                    hpf_en := 1
                0:
                    hpf_en := 0
                other:
                    cf := ((cf >> core.SEL) & core.SEL_BITS)
                    return lookupz(cf: 0_234, 0_120, 0_061, 0_031)

    freq := ((cf & core.SEL_MASK & core.HPF_EN_MASK) | freq | hpf_en)
    cache_opmode()
    writereg(core.CTRL_REG0, freq)
    restore_opmode()


PUB gyro_int(): i
' Read gyroscope interrupts
'   Bit 6..0
'       6 (INT_THS): threshold interrupt detected on one or more axes
'       5 (INT_ZTHS): threshold interrupt detected on Z-axis
'       4: polarity of Z interrupt (0: positive, 1: negative)
'       3 (INT_YTHS): threshold interrupt detected on Z-axis
'       2: polarity of Y interrupt (0: positive, 1: negative)
'       1 (INT_XTHS): threshold interrupt detected on Z-axis
'       0: polarity of X interrupt (0: positive, 1: negative)
    return readreg(core.RT_SRC)


PUB gyro_int_polarity(state=-2): cp
' Set gyroscope interrupt pin active state/polarity
'   Valid values:
'       ACT_LOW (0): active low
'       ACT_HI (1): active high
'   Any other value polls the chip and returns the current setting
    cp := readreg(core.CTRL_REG2)
    case state
        ACT_LOW, ACT_HI:
            state <<= core.IPOL
            state := ((cp & core.IPOL_MASK) | state)
            writereg(core.CTRL_REG2, state)
        other:
            return ((cp >> core.IPOL) & 1)


PUB gyro_int_mask(mask=-2): cm | reg2, rtcfg, tmp[2]
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
    cm := 0
    tmp[0] := readreg(core.CTRL_REG2)
    tmp[1] := readreg(core.RT_CFG)
    cm.byte[1] := tmp[1]
    cm.byte[0] := tmp[0]
    case mask
        0..%1111_11111111:
            reg2 := mask.byte[0] & core.INT_EN_BITS
            rtcfg := mask.byte[1] & core.RT_CFG_MASK
            mask := ((cm.byte[0] & core.INT_EN_MASK) | reg2)
            writereg(core.CTRL_REG2, mask)
            mask := ((cm.byte[1] & core.ELE_EFE_MASK) | rtcfg)
            writereg(core.RT_CFG, mask)
        other:
            return cm.byte[0] & core.INT_EN_BITS


PUB gyro_int_outp_type(type=-2): ct
' Set gyroscope interrupt pin output driver type
'   Valid values:
'       INT_PP (0): push-pull
'       INT_OD (1): open-drain/open-source
'           (when gyro_int_polarity() == 0, 1, respectively)
'   Any other value polls the chip and returns the current setting
    ct := readreg(core.CTRL_REG2)
    case type
        INT_PP, INT_OD:
            type := ((ct & core.PP_OD_MASK) | type)
            writereg(core.CTRL_REG2, type)
        other:
            return (ct & 1)


PUB gyro_int_thresh(): t | gscl, lsb
' Get gyroscope interrupt threshold
'   Returns: micro-dps (unsigned)
    gscl := (gyro_scale() * 1_000000)
    lsb := gscl / 128                           ' calc LSB for the thresh reg

    return ( (readreg(core.RT_THS) & core.THS_BITS) * lsb)     ' scale to micro-dps


PUB gyro_int_set_thresh(thresh) | gscl, lsb
' Set gyroscope interrupt threshold, in micro-dps (unsigned)
'   Valid values: 0..(full-scale * 1_000_000); clamped to range
    gscl := gyro_scale() * 1_000000
    lsb := gscl / 128                           ' calc LSB for the thresh reg

    { clamp to range, and preserve DBCNTM bit }
    thresh := (0 #> thresh <# gscl) / lsb
    thresh := ((readreg(core.RT_THS) & core.THS_MASK) | thresh)

    cache_opmode()
    writereg(core.RT_THS, thresh)
    restore_opmode()


PUB gyro_lpf_freq(freq=-2): cf
' Set gyroscope output data low-pass filter cutoff frequency, in Hz
'   Valid values:
'       4..256 (available values depend on gyro_data_rate() setting)
'   Any other value polls the chip and returns the current setting
    cf := readreg(core.CTRL_REG0)
    case gyro_data_rate()                       ' check current data rate to
        800:                                    ' determine avail. LPF freqs
            case freq
                256, 128, 64:
                    freq := lookdownz(freq: 256, 128, 64) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 256, 128, 64)
        400:
            case freq
                128, 64, 32:
                    freq := lookdownz(freq: 128, 64, 32) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 128, 64, 32)
        200:
            case freq
                64, 32, 16:
                    freq := lookdownz(freq: 64, 32, 16) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 64, 32, 16)
        100:
            case freq
                32, 16, 8:
                    freq := lookdownz(freq: 32, 16, 8) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 32, 16, 8)
        50:
            case freq
                16, 8, 4:
                    freq := lookdownz(freq: 16, 8, 4) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 16, 8, 4)
        25:
            case freq
                8, 4:
                    freq := lookdownz(freq: 8, 4) << core.BW
                other:
                    cf := ((cf >> core.BW) & core.BW_BITS)
                    return lookupz(freq: 8, 4)
        12:
            case freq
                4:
                    freq := 0
                other:
                    return 4
    freq := ((cf & core.BW_MASK) | freq)
    cache_opmode()
    writereg(core.CTRL_REG0, freq)
    restore_opmode()


PUB gyro_opmode(mode=-2): cm
' Set gyroscope operating mode
'   Valid values:
'       SLEEP (0): lowest-power/sleep mode (no data acquisition)
'       STANDBY (1): medium-power mode (no data acquisition)
'       ACTIVE (2): normal-power mode (full functionality, acquire data)
'   Any other value polls the chip and returns the current setting
    cm := readreg(core.CTRL_REG1)
    case mode
        SLEEP, STANDBY, ACTIVE:
            mode := ((cm & core.STATE_MASK) | mode)
            writereg(core.CTRL_REG1, mode)
        other:
            return (cm & core.STATE_BITS)


PUB gyro_scale(scale=-2): cs
' Set gyroscope full-scale range, in degrees per second
'   Valid values: 250, 500, 1000, 2000
'   Any other value polls the chip and returns the current setting
    cs := readreg(core.CTRL_REG0)
    case scale
        250, 500, 1000, 2000:
            scale := lookdownz(scale: 2000, 1000, 500, 250)
            ' find LSB per DPS
            _gres := lookupz(scale: 62_500, 31_250, 15_625, 7_812{5})
            cache_opmode()

            scale := ((cs & core.FS_MASK) | scale)
            writereg(core.CTRL_REG0, scale)

            restore_opmode()
        other:
            cs &= core.FS_BITS
            return lookupz(cs: 2000, 1000, 500, 250)


PUB reset()
' Reset the device
    if ( lookdown(_RST: 0..31) )
        outa[_RST] := 1
        dira[_RST] := 1
        outa[_RST] := 0
        time.usleep(core.T_POR)
        outa[_RST] := 1
    else
        writereg(core.CTRL_REG1, core.RESET)


PUB temp_data(): t
' Temperature ADC data
    t := readreg(core.TEMP)
    return ~t                                   ' extend sign bit


PUB temp_word2deg(temp_word): t
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


PRI readreg(reg_nr, len=1): v | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $00..$15:
            cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.wr_byte(SLAVE_RD | _addr_bits)

            ' write MSByte to LSByte
            i2c.rdblock_msbf(@v, len, i2c.NAK)
            i2c.stop()
        other:                                  ' invalid reg_nr
            return


PRI restore_opmode()
' Restore previously cached opmode, if it wasn't STANDBY
    if ( _opmd_orig <> STANDBY )                ' if original opmode wasn't
        gyro_opmode(_opmd_orig)                 '   STANDBY, switch back to it


PRI cache_opmode()
' Set chip to STANDBY, if it isn't already, and cache the previous opmode
'   so it can be restored later
    _opmd_orig := gyro_opmode()
    if ( _opmd_orig == ACTIVE )
        gyro_opmode(STANDBY)


PRI writereg(reg_nr, val) | byte cmd_pkt[3]
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $09, $0D, $0E, $10, $11, $13..$15:
            cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
            cmd_pkt.byte[1] := reg_nr
            cmd_pkt.byte[2] := val
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 3)
            i2c.stop()
        other:
            return


DAT
{
Copyright 2026 Jesse Burt

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

