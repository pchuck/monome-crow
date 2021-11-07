--- snh - sample and hold + random
--    https://github.com/pchuck/monome-crow
--
-- in1: clock
-- in2: input voltage
-- out1: in2 sampled (on in1 clock) and held
-- out2: in2 sampled (on in1 clock) held and quantized
-- out3: random value sampled (on in1 clock) and held
-- out4: random value sampled (on in1 clock) held and quantized

-- constants
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local CHROMATIC = 12

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.min_v = -2.0
public.add('min_v', 0.0, {-5, 0}) -- minimum (random) output (v)
public.add('max_v', 2.0, { 0, 5}) -- maximum (random) output (v)


-- initialization
function init()
   -- trigger on first input
   input[1].mode('change', V_THRESH, V_HYST, TRIG)
   print('initialized')
end

-- chromatically quantize an input voltage
function quantize(v)
   return(math.floor(v * CHROMATIC) / CHROMATIC)
end

-- generate a random float between 'min' and 'max'
function rand_float(min, max)
    return math.random() * (max - min) + min
end

-- trigger call-back
input[1].change = function(state)
   local v = input[2].volts -- sample the input voltage
   local r = rand_float(public.min_v, public.max_v) -- random voltage
   -- outputs
   output[1].volts = v ; output[2].volts = quantize(v)
   output[3].volts = r ; output[4].volts = quantize(r)

   -- debug
   -- print('v/vq = ', v, "/", vq)
   -- print('r/rq = ', r, "/", rq)
end

