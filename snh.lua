--- snh - sample and hold + random
-- in1: clock
-- in2: input voltage
-- out1: input (sampled/held)
-- out2: input (sampled/held/quantized
-- out3: random (held)
-- out4: random (held/quantized)

-- constants
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysterisis voltage
TRIG = 'rising' -- trigger condition
CHROMATIC = 12
V_MAX = 5.0

-- initialization
function init()
    -- read first input, 'change' mode
    -- trigger when rising, in 'change' mode. trigger when TRIG
    input[1].mode('change', V_THRESH, V_HYST, TRIG)
    print('initialized')
end

-- chromatically quantize an input voltage
function quantize(v)
    q = math.floor(v * CHROMATIC) / CHROMATIC
    return(q)
end

-- trigger call-back
input[1].change = function(state)
    -- sample the input voltage
    v = input[2].volts
    vq = quantize(v)

    -- generate a random voltage (0-V_MAX)
    r = math.random() * V_MAX
    rq = quantize(r)

    -- outputs
    output[1].volts = v
    output[2].volts = vq
    output[3].volts = r
    output[4].volts = rq

    -- debug
    -- print('v/vq = ', v, "/", vq)
    -- print('r/rq = ', r, "/", rq)
end

