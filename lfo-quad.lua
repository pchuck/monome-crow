--- lfo-quad - quad lfo for monome crow.
--    https://github.com/pchuck/monome-crow
--
-- quad lfo generator. supports optional quantization and different wave shapes
--
--  in1: n/a
--  in2: n/a
-- out1: lfo 1
-- out2: lfo 2
-- out3: lfo 3
-- out4: lfo 4
--

-- constants
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
SEQS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs

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
-- waveform period (in seconds)
public.add('period', 1.0, {0.00001, 1000}, function() change_param() end)
-- output voltage range (v)
public.add('level', 1.0, { 0, 10}, function() change_param() end)
 -- output voltage offset (v)
public.add('offset', 0.0, { -5, 5}, function() change_param() end)
-- envelope shape
public.add('shape', 'sine', 
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}, function() change_param() end)
-- quantization
public.add('scale', 'none', scale_names, -- scale
           function() set_scale(public.scale) end)


-- initialization
function init()
   set_scale(public.scale) -- set quantization
   for _, v in pairs(SEQS) do
      change_param() -- initialize the output parameters
      output[v]() -- start the lfos
   end
end

-- set/change lfo param(s)
function change_param(s)
   for _, v in pairs(SEQS) do
      local p = public.period + public.period * v * 0.1 -- freq/phase shifted
      output[v].action = lfo2(p, public.offset, public.level,  public.shape)
   end
end

-- set/reset scale
function set_scale(s)
   local notes = scale_notes[s]
   for _, v in pairs(SEQS) do
      output[v].scale(notes, TET12, VPO) -- pitch output quantization
   end
end

-- lfo with support for positive/negative offsets and different shapes
function lfo2(time, offset, level, shape)
   return loop{
      to(offset,         time / 2, shape), 
      to(offset + level, time / 2, shape)
   }
end
