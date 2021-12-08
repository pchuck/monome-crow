--- melodicer - vermona melodicer inspired dual random output for monome crow.
--    https://github.com/pchuck/monome-crow
--
-- Stochastic randomness with two separate streams of notes and triggers.
-- See below for controlling v/oct ranges, gate probabilities,
-- sequence lengths and repeats.
--
--  in1: voice 1 clock input
--  in2: voice 2 clock input
-- out1: voice 1 gate output
-- out2: voice 1 note output (v/oct)
-- out3: voice 2 gate output
-- out4: voice 2 note output (v/oct)
--
--
-- Example use case (and associated configuration)...
--
--   (1) is a lead voice that has 70% probability of triggering notes
--   with a tonal range of 3 octaves. Output 1 has a sequence length of 8
--   and repeats the pattern 4 times before randomizing.
--   (1) is clocked by in1 and outputs its gate on out1 and notes on out2.
--
--   (2) is an auxiliary voice (bass line) that has a 100% chance of
--   triggering notes with a tonal range of 1 octave. The sequence length is
--   2 and patterns are repeated 8 times before randomizing.
--   (2) is clocked by in2 and outputs its gate on out3 and notes on out4.
--
--   After starting the script, execute the following commands to configure:
--
--     public.probability_1=0.7
--     public.level_1=3.0
--
--     public.probability_2=1.0
--     public.level_2=1.0
--     public.length_2=2
--     public.repeat_2=8


-- constants
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
INS =   { 1, 2 } -- logical ids of the inputs
GATES = { 1, 3 } -- logical ids of the gate outputs
VOCTS = { 2, 4 } -- logical ids of the note outputs
MAX_REPEAT = 8 -- maximum value for sequence repeat
MAX_LEN = 32 -- maximum value for sequence length
MAX_V = 10

-- global parameters for output voices 1/2
gate_sequence = { [1] = {}, [2] = {} } -- gate sequence
note_sequence = { [1] = {}, [2] = {} } -- note sequence
probabilities = { [1] =  0, [2] =  0 } -- gate probability
levels        = { [1] =  0, [2] =  0 } -- max output voltage
offsets       = { [1] =  0, [2] =  0 } -- voltage offset
lengths       = { [1] =  0, [2] =  0 } -- max sequence length
repeats       = { [1] =  0, [2] =  0 } -- max sequence repeat
seq_position  = { [1] =  0, [2] =  0 } -- current sequence position
rep_position  = { [1] =  0, [2] =  0 } -- current repeat position
               
-- scales (via bowery/quantizer)
scale_names = { 'none', 'octave', 'major', 'harMin', 'dorian', 'majTri',
                'dom7th', 'wholet', 'chroma' }
scale_notes = { ['none']   = 'none',
                ['octave'] = { 0 },
                ['major' ] = { 0, 2, 4, 5, 7, 9, 11 },
                ['harMin'] = { 0, 2, 3, 5, 7, 8, 10 },
                ['dorian'] = { 0, 2, 3, 5, 7, 9, 10 },
                ['majTri'] = { 0, 4, 7 },
                ['dom7th'] = { 0, 4, 7, 10 },
                ['wholet'] = { 0, 2, 4, 6, 8, 10 },
                ['chroma'] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } }

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.scale = 'chroma'
--
-- probability of triggering an output gate
public.add('probability_1', 0.7, { 0.0, 1.0 })
public.add('probability_2', 1.0, { 0.0, 1.0 })
-- output voltage ranges (v)
public.add('level_1', 3.0, { 0, MAX_V })
public.add('level_2', 1.0, { 0, MAX_V })
 -- output voltage offsets (v)
public.add('offset_1', 0.0, { -MAX_V / 2, MAX_V / 2 })
public.add('offset_2', 0.0, { -MAX_V / 2, MAX_V / 2 })
-- sequence lengths
public.add('length_1', 8, { 1, MAX_LEN })
public.add('length_2', 2, { 1, MAX_LEN })
-- number of times to repeat sequence before randomizing
public.add('repeat_1', 4, { 1, MAX_REPEAT })
public.add('repeat_2', 8, { 1, MAX_REPEAT })
-- quantization
public.add('scale', 'chroma', scale_names, -- scale
           function() set_scale(public.scale) end)


-- map input values to voice table
-- since 'public' doesn't handle tables(?) directly
function update_values()
   probabilities[1] = public.probability_1
   probabilities[2] = public.probability_2
    levels[1] = public.level_1
    levels[2] = public.level_2
   offsets[1] = public.offset_1
   offsets[2] = public.offset_2
   repeats[1] = public.repeat_1
   repeats[2] = public.repeat_2
   lengths[1] = public.length_1
   lengths[2] = public.length_2
end
   

-- generate new random gates and notes (eg. melodicer 'dice' function)
function randomize(sid)
   for i = 1, MAX_LEN + 1 do
      note_sequence[sid][i] = math.random() * levels[sid] + offsets[sid]
      gate_sequence[sid][i] = probabilities[sid] >= math.random()
   end
end

-- initialization
function init()
   set_scale(public.scale) -- set quantization
   for _,i in pairs(INS) do
      update_values()
      randomize(i)
      input[i].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
      input[i].change = function() change(i) end -- trig call-back function
   end
end

-- event-handler for clock events
function change(sid)
   -- print("sid, r, s", sid, rep_position[sid], seq_position[sid])      
   update_values()
   seq_position[sid] = seq_position[sid] + 1 --- increment the sequence position
   if seq_position[sid] > lengths[sid] then -- if the sequence exceeds length
      seq_position[sid] = 1 -- wrap 
      rep_position[sid] = rep_position[sid] + 1 -- increment the repeat counter
      if rep_position[sid] > repeats[sid] then -- if repeat max is exceeded
         rep_position[sid] = 1 -- wrap
         randomize(sid) -- randomize the sequence and gates
      end
   end
   if gate_sequence[sid][seq_position[sid]] then

      output[VOCTS[sid]].volts = note_sequence[sid][seq_position[sid]]
      output[GATES[sid]](pulse())
   end
end

-- set/reset scale
function set_scale(s)
   print('set_scale', s)
   local notes = scale_notes[s]
   for _, v in pairs(VOCTS) do
      output[v].scale(notes, TET12, VPO) -- pitch output quantization
   end
end

