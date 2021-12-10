--- ar - ar envelope generator, with cv control
--    https://github.com/pchuck/monome-crow
--
-- in1: trigger
-- in2: cv control
-- out1: ar envelope (variable controlled)
-- out2: ar envelope (cv controls attack
-- out3: ar envelope (cv controls release)
-- out4: ar envelope (cv controls both)

-- constants
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local IN_GATE = 1 -- gate input
local IN_CV = 2 -- cv input (not used in this version)
local OUTS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs
local MAX_CV = 5 -- maximum meaningful CV value
local MAX_V = 10 -- maximum envelope output (v)
local MAX_T = 10 -- maximum phase length (s)

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.a = 0.1
--
--                 __ max_level
--    / \    
--   /   \               __ min_level
--   
--   a | r 
--
public.add('a',         0.5, { 0, MAX_T }) -- attack time (s)
public.add('r',         0.5, { 0, MAX_T }) -- release time (s)
public.add('max_level',   7, { 0, MAX_V }) -- max level (v)
public.add('min_level',   0, { 0, MAX_V }) -- min level (v)
public.add('shape', 'log', -- envelope shape
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}) 

-- initialization
function init()
   -- trigger on first input
   input[IN_GATE].mode('change', V_THRESH, V_HYST, TRIG)
   input[IN_GATE].change = function() change() end -- the call-back function
   print('ar env w/ cv control initialized')
end

-- improvement over the asllib ar() envelope function
--   allows specification of min level
function ar2(a, r, max_level, min_level, shape)
   -- print(a, r, max_level, min_level, shape)
   return{ to(max_level, a, shape), to(min_level, r, shape) }
end

-- cv adjust value
function cv_adjust(cv, value)
   v = value * cv / MAX_CV
   return(v)
end

-- trigger call-back
function change()
   local cv = input[IN_CV].volts
   output[1].action = { ar2(public.a, 
                            public.r,
                            public.max_level,
                            public.min_level,
                            public.shape) }
   output[2].action = { ar2(cv_adjust(cv, public.a),
                            public.r,
                            public.max_level,
                            public.min_level,
                            public.shape) }
   output[3].action = { ar2(public.a,
                            cv_adjust(cv, public.r),
                            public.max_level,
                            public.min_level,
                            public.shape) }
   output[4].action = { ar2(cv_adjust(cv, public.a),
                            cv_adjust(cv, public.r),
                            public.max_level,
                            public.min_level,
                            public.shape) }

   for _, v in pairs(OUTS) do -- (re)trigger the envelopes
      output[v]()
   end
end
