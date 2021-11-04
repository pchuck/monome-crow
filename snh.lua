--- snh - sample and hold + random
-- in1: clock
-- in2: input voltage
-- out1: input (sampled/held)
-- out2: input (sampled/held/quantized
-- out3: random (held)
-- out4: random (held/quantized)

-- initialization
function init()
    -- read first input, 'change' mode
    -- threshold voltage: 1.0v
    -- hysterisis voltage: 0.1v
    -- trigger when rising
    input[1].mode('change', 1.0, 0.1, 'rising')
    print('initialized')
end

-- chromatically quantize an input voltage
function quantize(v)
    q = math.floor(v * 12) / 12
    return(q)
end

-- trigger call-back
input[1].change = function(state)
    -- sample the input voltage
    v = input[2].volts
    vq = quantize(v)

    -- generate a random voltage (0-5v)
    r = math.random() * 5
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

