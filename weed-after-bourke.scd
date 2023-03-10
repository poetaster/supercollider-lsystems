// if you have never done so, run the following code first
(
Quarks.install("https://github.com/shimpe/panola");
Quarks.install("https://github.com/shimpe/sc-lsystem");
)


/*
// Weed, P. Bourke
axiom: F
rules:
  F -> FF-[XY]+[XY]
  X -> +cFY
  Y -> -dFX
*/

(
s.waitForBoot({
    var player;
    var lsys = LSystem(
        iterations:3,
        axiom:"F",
        constants:Set[],
        rules:(
			\F : "FF-[XY]+[XY]",
			\X : "+FY",
			\Y : "-FX",

	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			//\acceptablenotes : Set["g3", "g3_16", "a3", "c4", "d4_8", "f#4_16", "g4", "g4_16", "a4"],
			\acceptablenotes : Set["g3", "g3_16", "ais3_16", "c4", "c4_16", "g4_16"],
            \patternnotes : ["g3"],
            \transpose : 0,
            \tempo : 16,
        ),
        actions:(
            // whenever you encounter an F, extend the list of played notes
            'F' : [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
                glob[\patternnotes] = glob[\patternnotes].add(glob[\acceptablenotes].choose.debug("add new note"));

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a +, transpose up
            '+': [{ | glob, loc |
                glob[\transpose] = (glob[\transpose] + [1,2,3,4].choose.debug("transpose up")).clip(-12,12);
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a -, transpose down
            '-': [{ | glob, loc |
                "transpose down".postln;
                glob[\transpose] = (glob[\transpose] - [1,2,3,4].choose.debug("transpose down")).clip(-12, 12);
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'Y' : [{ | glob, loc |
                "remove first note".postln;
                if (glob[\patternnotes].size > 1) {
                    // keep at least one note
                    glob[\patternnotes] = glob[\patternnotes].reverse;
                    glob[\patternnotes].pop;
                    glob[\patternnotes] = glob[\patternnotes].reverse;
                };
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a Y, change tempo (randomly) )
            'X' : [{ | glob, loc |
                glob[\tempo] = (glob[\tempo] * [1.6, 0.4, 2.4, 0.8, 3.2, 0.2 ].choose.debug("tempo factor")).clip(8,32);
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();

    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 0.1, mix = 0.1|
        var snd, click;
        // Basic tone is a SinOsc
        snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.03, Rand(3.0, 4.0), 1, -7), doneAction: 2);
        snd = HPF.ar( LPF.ar(snd, 380), 120);
        // The "clicking" sounds are modeled with a bank of resonators excited by enveloped white noise
        click = DynKlank.ar(`[
            // the resonant frequencies are randomized a little to add variation
            // there are two high resonant freqs and one quiet "bass" freq to give it some depth
            [240*ExpRand(0.97, 1.02), 2020*ExpRand(0.97, 1.02), 3151*ExpRand(0.97, 1.02)],
            [-9, 0, -5].dbamp,
            [0.8, 0.07, 0.08]
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 0.1;
        snd = (snd*mix) + (click*(1-mix));
        snd = Mix( snd );
        Out.ar(out, Pan2.ar(snd, 0, amp));
    }).add;

    SynthDef(\flute, {
		| out = 0, freq = 440, amp = 1.0, a = 0.1, r = 0.1|
		//var fmod = 1; // clean
		//var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.1)); // tone deaf flute
		var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.02)); // flute-like sound
		var env = EnvGen.ar(Env.perc(a, r), levelScale:0.5, doneAction:2);
		var snd = SinOsc.ar(freq * fmod)!2;
		Out.ar(bus:out, channelsArray:(env*(amp*snd).tanh));
	}).add;

	SynthDef(\blips, {arg out = 0, freq = 440, numharm = 11, att = 0.01, rel = 1, amp = 0.2, pan = 0.3;
		var snd, env;
		env = Env.perc(att, rel, amp).kr(doneAction: 2);
		snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], numharm, env))), 440, 0.4);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	SynthDef(\risset, {|out = 0, pan = 0, freq = 400, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0,vibAdd=0.5|
		var amps = #[1, 0.67, 1, 1.8, 2.67, 1.67, 1.46, 1.33, 1.33, 1, 1.33];
		var durs = #[1, 0.9, 0.65, 0.55, 0.325, 0.35, 0.25, 0.2, 0.15, 0.1, 0.075];
		var frqs = #[0.56, 0.56, 0.92, 0.92, 1.19, 1.7, 2, 2.74, 3, 3.76, 4.07];
		var dets = #[0, 1, 0, 1.7, 0, 0, 0, 0, 0, 0, 0];
		var doneActionEnv = EnvGen.ar(Env.linen(0, att+rel, 0), gate, doneAction: 2);
		var src = Mix.fill(11, {|i|
			var env = EnvGen.ar(Env.perc(att, rel * durs[i], amps[i], att.explin(0.005, 4, -4.5, 0)), gate);
			SinOsc.ar(freq*frqs[i] + dets[i], 0, amp*env);
		});
        src = src * SinOsc.kr(vibFreq*15, mul:vibAmp, add:vibAdd);
		src = src * doneActionEnv * 0.5; // make sure it releases node after the end.
	    Out.ar(out, Pan2.ar(src, pan));
	}).add;

    s.sync;

    fork {
        var skipfirstidx = 4; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
        lsys.getCalculatedString.do({
            | chr, idx |
            var pattern;
            var transposedpattern;
            var transposition;
            var transposition2;
            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = inf;
                if (idx == (sz-1)) { repeats = 3; }; // don't repeat last pattern indefinitely
                transposition = interp.globalState()[\transpose].debug("transpose");
                transposition2 = interp2.globalState()[\transpose].debug("transpose2");
                pattern = Pn(
                    Ppar([
                        Padd(\midinote, Pfunc({transposition}),
                            Panola.new(
                                notation:interp.globalState()[\patternnotes].join(" ").debug("notes1"),
                                dur_default:interp.globalState()[\tempo],
								vol_default:0.9
                            ).asPbind(\kalimba)
                        ),
                        Padd(\midinote, Pfunc({transposition2}),
                            Panola.new(
                                notation:interp2.globalState()[\patternnotes].join(" ").debug("notes2"),
                                dur_default:interp2.globalState()[\tempo]*0.8,
                                playdur_default:1,
                                vol_default:0.2
                            ).asPbind(\blips),
                        )
                    ]),
                    repeats);
                if (player.notNil) { player.stop; };
				player = pattern.play();
                1.wait;
                if (idx == (sz-1)) {
                    "*** ABOUT TO FINISH ***".postln;
                };
            }
        });
    }
});
)



