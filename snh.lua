--- snh - sample and hold + random
--    https://github.com/pchuck/monome-crow
--
-- in1: clock
-- in2: input voltage
-- out1: input (sampled/held)
-- out2: input (sampled/held/quantized
-- out3: random (held)
-- out4: random (held/quantized)

-- constants
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
CHROMATIC = 12
V_MAX = 5.0

-- initialization
function init()
    -- trigger on first input
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
    v = input[2].volts -- sample the input voltage
    vq = quantize(v)
    r = math.random() * V_MAX -- generate a random voltage (0-V_MAX)
    rq = quantize(r)
    -- outputs
    output[1].volts = v ; output[2].volts = vq
    output[3].volts = r ; output[4].volts = rq

    -- debug
    -- print('v/vq = ', v, "/", vq)
    -- print('r/rq = ', r, "/", rq)
end

