--- melodicer - vermona melodicer inspired dual output for monome crow.
--    https://github.com/pchuck/monome-crow
--
-- Stochastic randomness with two separate streams of notes and triggers.
-- See below for controlling v/oct ranges, gate probabilities,
-- sequence lengths and repetition.
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
--   (1) is a primary voice that has 40% probability of triggering notes
--   with a tonal range of 2 octaves. Output 1 has a sequence length of 8
--   and repeats the pattern 4 times before randomizing.
--   (1) is clocked by in1 and outputs its gate on out1 and notes on out2.
--
--   (2) is an auxiliary voice that has a 60% chance of
--   triggering notes with a tonal range of 1 octave. The sequence length is
--   2 and patterns are repeated 8 times before randomizing.
--   (2) is clocked by in2 and outputs its gate on out3 and notes on out4.
--
--   After starting the script, optionally customize (on the druid console)..
--
--     public.probabilities[1]=0.4
--     public.levels[1]=2.0
--     public.lengths[1]=8
--     public.repeats[1]=4
--
--     public.probabilities[2]=0.6
--     public.levels[2]=1.0
--     public.lengths[2]=2
--     public.repeats[2]=8


-- constants
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
INS =   { 1, 2 } -- logical ids of the inputs
GATES = { 1, 3 } -- logical ids of the gate outputs
VOCTS = { 2, 4 } -- logical ids of the note outputs
MAX_REPEAT = 8 -- maximum value for sequence repetition
MAX_LEN = 32 -- maximum value for sequence length
MAX_V = 5 -- maximum output voltage
MAX_V_OFFSET = 5 -- maximum voltage offset
MAX_PROB = 1.0 -- maximum probability
REPEAT_RANGE = { 1, MAX_REPEAT } -- range of valid repetitions
LEN_RANGE = { 1, MAX_LEN } -- range of valid sequence lengths
V_RANGE = { -MAX_V, MAX_V } -- range of output voltages
V_OFFSET_RANGE = { -MAX_V_OFFSET, MAX_V_OFFSET } -- range of voltage offsets
PROB_RANGE = { 0, MAX_PROB } -- range of probabilities

-- global parameters for output voices 1/2
gate_sequence = { [1] = {}, [2] = {} } -- gate sequence
note_sequence = { [1] = {}, [2] = {} } -- note sequence
probabilities = { } -- gate probability
levels        = { } -- max output voltage
offsets       = { } -- voltage offset
lengths       = { } -- max sequence length
repeats       = { } -- max sequence repeat
seq_position  = { 0, 0 } -- current sequence position
rep_position  = { 0, 0 } -- current repeat position
               
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
public.add('probabilities', { 0.4, 0.6 }) -- , PROB_RANGE)
-- output voltage ranges (v)
public.add('levels', { 2.0, 1.0 }) -- , V_RANGE)
-- output voltage offsets (v)
public.add('offsets', { 0.0, 0.0 }) -- , V_OFFSET_RANGE)
-- sequence lengths
public.add('lengths', { 8, 2 }) -- , LEN_RANGE)
-- number of times to repeat sequence before randomizing
public.add('repeats', { 4, 8 }) -- , REPEAT_RANGE)
-- quantization
public.add('scale', 'chroma', scale_names, -- scale
           function() set_scale(public.scale) end)
--
-- note: ranges not working w tables? otherwise would clamp w/ something like:
--   public.add('probabilities', { 0.4, 0.6 }, { PROB_RANGE, PROB_RANGE } )
--
public.add('test', 0.5, { 0.0, 1.0 } )
public.add('test_t', { 0.5, 0.6 }, { 0.0, 1.0 } )

-- generate new random gates and notes (eg. melodicer 'dice' function)
function randomize(sid)
   for i = 1, MAX_LEN + 1 do
      note_sequence[sid][i] = math.random() *
         public.levels[sid] + public.offsets[sid]
      gate_sequence[sid][i] = public.probabilities[sid] >= math.random()
   end
end

-- initialization
function init()
   set_scale(public.scale) -- set quantization
   for _,i in pairs(INS) do
      randomize(i)
      input[i].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
      input[i].change = function() change(i) end -- trig call-back function
   end
end

-- event-handler for clock events
function change(sid)
--   print("sid, r, s", sid, rep_position[sid], seq_position[sid])      
   seq_position[sid] = seq_position[sid] + 1 --- increment the sequence position
   if seq_position[sid] > public.lengths[sid] then -- sequence exceeds length
      seq_position[sid] = 1 -- wrap 
      rep_position[sid] = rep_position[sid] + 1 -- increment the repeat counter
      if rep_position[sid] > public.repeats[sid] then -- repeats exceeds max
         rep_position[sid] = 1 -- wrap
         randomize(sid) -- randomize the sequence and gates
      end
   end
   -- if gate, update tone output and trigger
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

