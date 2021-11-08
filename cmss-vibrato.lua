--- cmss-vibrato - vibrato prototype/collaboration
--    vibrato as in amplitude modulation, or 'tremolo' as in guitar tremolo
--    pb. the colorado modular society, sine mountain and patchogram
--    https://github.com/pchuck/monome-crow
--
-- A configurable parametric vibrato effect/envelopes generator
--
--  in1: gate
--  in2: v/o pitch
-- out1: vibrato oscillation/decay/envelope 1
-- out2: vibrato oscillation/decay/envelope 2
-- out3: vibrato oscillation/decay/envelope 3
-- out4: vibrato oscillation/decay/envelope 4
--

-- constants
M_PERIOD = 0.001 -- time() interval in seconds
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
GATE = 1 ; PITCH = 2 -- inputs - logical ids of the inputs
OUTS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs
-- vibrato envelope default parameters
V_MIN = 1.0 -- min output voltage
V_MAX = 8.0 -- max output voltage
DIV = 50 -- oscillation rate (number of vibrato divisions per tap/clock period)
TIME_ACCEL = 1.1 -- time compression per vibrato interval
LEVEL_DECAY = -0.8 -- voltage decay per vibrato interval

-- public/configurable parameters
public.add('shape', 'sine', -- envelope shape
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}) 
public.add('gain', 8.0, { 0, 10.0}) -- gain/envelope max voltage level


-- initialization - setup the callbacks for reacting to triggers/gates
function init()
   input[GATE].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
   input[GATE].change = function() change(1) end -- the call-back function
end

-- lfo with support for positive/negative offsets, shapes and dynamic values
function lfo2(sid, pitch, period, offset, level)
   local shape = public.shape -- envelope shape
   local sub = period / DIV -- time per oscillation, compressed by accel
   local accel = TIME_ACCEL -- time-based modulation acceleration/deceleration 
   local ld = LEVEL_DECAY -- amplitude decay per oscillation
   local up = to( offset,                     dyn{time=sub}:mul(accel), shape )
   local dn = to( dyn{height=level}:step(ld), dyn{time=sub}:mul(accel), shape )
   -- invert odd/even output waveforms for a leslie speaker-like stereo effect
   print('lfo')
   if sid % 2 == 0 then return loop { up, dn } 
   else                 return loop { dn, up } end
   
   -- pitch currently not used; could affect vibrato rate/depth
   -- attack/release from vibrato() not used; could layer on an encaps env
   --   ar(attack, release, public.gain, public.shape)})
end

-- capture pitch, create and trigger the vibrato envelope for specified out
function vibrato(sid, period, attack, release)
   local pitch = input[PITCH].volts
   for _, v in pairs(OUTS) do
      output[v].action = { lfo2(v, pitch, period, V_MIN, V_MAX) }
      output[v]() -- (re)trigger the envelope
   end
end

-- update the vibrato/attack/release parameters and trigger the envelope
time_last = { 0, 0 } -- last time each output's envelope was triggered
function change(sid)
   local time_now = time()
   local time_delta = (time_now - time_last[sid]) * M_PERIOD -- seconds
   local frequency = 1 / time_delta -- tap/clock frequency, in hz
   local attack = frequency / 5
   local release = frequency / 3
   time_last[sid] = time_now -- record the current time
   vibrato(sid, time_delta, attack, release)
end
