--- cmss-tremolo - tremolo prototype/collaboration
--    pb. the colorado modular society, sine mountain and patchogram
--    https://github.com/pchuck/monome-crow
--
-- A configurable parametric tremolo effect/envelopes generator
--
--  in1: gate
--  in2: v/o pitch
-- out1: tremolo oscillation/decay/envelope 1
-- out2: tremolo oscillation/decay/envelope 2
-- out3: tremolo oscillation/decay/envelope 3
-- out4: tremolo oscillation/decay/envelope 4
--

-- constants
M_PERIOD = 0.001 -- time() interval in seconds
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
MIN = 1; MAX = 2 -- table indices for ranges
OUTS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs
-- tremolo parameters
V_MIN = 1.0 -- min output voltage
V_MAX = 8.0 -- max output voltage
DIV = 50 -- oscillation rate (number of tremolo divisions per clock period)
TIME_ACCEL = 1.1 -- time compression per tremolo interval
LEVEL_DECAY = -0.8 -- voltage decay per tremolo interval

-- public/configurable parameters
public.add('shape', 'sine', -- envelope shape
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}) 
public.add('gain', 8.0, { 0, 10.0}) -- gain/envelope max voltage level


-- initialization - setup the callbacks for reacting to triggers/gates
function init()
   input[1].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
   input[1].change = function() change(1) end -- the call-back function
end

-- lfo with support for positive/negative offsets, shapes and dynamic values
function lfo2(sid, pitch, period, offset, level)
   local shape = public.shape
   local sub = period / DIV
   local accel = TIME_ACCEL * (sid * math.random(0.1)) -- stereo shift
   local ld = LEVEL_DECAY
   return loop {
      to( offset,                     dyn{time=sub}:mul(accel), shape ), 
      to( dyn{height=level}:step(ld), dyn{time=sub}:mul(accel), shape ) }
   -- pitch currently not used, but could affect tremolo rate/depth
   -- also, could layer on an encapsulating envelope:
   --   ar(attack, release, public.gain, public.shape)})
end

-- capture pitch, create and trigger the tremolo envelope for specified out
function tremolo(sid, period, attack, release)
   local pitch = input[2].volts
   for _, v in pairs(OUTS) do
      output[v].action = { lfo2(v, pitch, period, V_MIN, V_MAX) }
      output[v]() -- (re)trigger the envelope
   end
end

-- update the tremolo/attack/release parameters and trigger the envelope
time_last = { 0, 0 } -- last time each output's envelope was triggered
function change(sid)
   local time_now = time()
   local time_delta = (time_now - time_last[sid]) * M_PERIOD -- seconds
   local frequency = 1 / time_delta -- tap/clock frequency, in hz
   local attack = frequency / 5
   local release = frequency / 3
   time_last[sid] = time_now -- record the current time
   tremolo(sid, time_delta, attack, release)
end
