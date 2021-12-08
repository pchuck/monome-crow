--- rand-quad - quad random output for monome crow.
--    https://github.com/pchuck/monome-crow
--
-- quad random generator. supports optional quantization.
-- output is similar to 'mimetic digitalis' w/ all four tracks on 'shred.
-- random values change on the rising edge of clock.
--
--  in1: clock
--  in2: n/a
-- out1: random 1
-- out2: random 2
-- out3: random 3
-- out4: random 4
--

-- constants
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
SEQS = { 1, 2, 3, 4 } -- outputs - logical ids of the random outputs

-- scales (via bowery/quantizer)
scale_names = { 'none', 'octave', 'major', 'harMin', 'dorian', 'majTri',
                'dom7th', 'wholet', 'chroma' }
scale_notes = { ['none']   = 'none',
                ['octave'] = {0},
                ['major' ] = {0, 2, 4, 5, 7, 9, 11},
                ['harMin'] = {0, 2, 3, 5, 7, 8, 10},
                ['dorian'] = {0, 2, 3, 5, 7, 9, 10},
                ['majTri'] = {0, 4, 7},
                ['dom7th'] = {0, 4, 7, 10},
                ['wholet'] = {0, 2, 4, 6, 8, 10},
                ['chroma'] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },}

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.scale = 'chroma'
--
-- output voltage range (v)
public.add('level', 5.0, { 0, 10})
 -- output voltage offset (v)
public.add('offset', 0.0, { -5, 5})
-- quantization
public.add('scale', 'none', scale_names, -- scale
           function() set_scale(public.scale) end)


-- initialization
function init()
   set_scale(public.scale) -- set quantization
   input[1].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
   input[1].change = function() change() end -- trig call-back function
end

-- event-handler for clock events
function change()
   for _,i in pairs(SEQS) do
      v = math.random() * public.level + public.offset
      -- print('v = ', v)
      output[i].volts = v
   end
end

-- set/reset scale
function set_scale(s)
   print('set_scale', s)
   local notes = scale_notes[s]
   for _, v in pairs(SEQS) do
      output[v].scale(notes, TET12, VPO) -- pitch output quantization
   end
end

