// if you have never done so, run the following code first
(
Quarks.install("https://github.com/shimpe/panola");
Quarks.install("https://github.com/shimpe/sc-lsystem");
)


/*
// poetasters succulent 1
axiom: A
rules:
 A =>[FY]A[FXA]
 F => XF
 X => FY
 Y => [F+F+F][F-F-F]
*/

(
s.waitForBoot({
    var player;

    var lsys = LSystem(
        iterations:3,
        axiom:"A",
        constants:Set[],
        rules:(
			\A : "[FY]A[FXA]",
			\F : "XF",
			\X : "FY",
			\Y : "[F+F+F][F-F-F]"
	));
    // sitar
	// 48.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8, 2, 2*16/15, 2*5/4, 2*4/3, 2*3/2];
    //
    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			\acceptablenotes : 48.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8, 2, 2*16/15, 2*5/4, 2*4/3, 2*3/2],

            \patternnotes : [261,245],
			\customnotes: ["c3_16@numharm[12]","g-3_8@numharm[10]"], // not used.
            \transpose : -3,
			\lag: 0.0,
            \tempo : 0.2,
			\dur : 0.2
        ),
        actions:(
            // whenever you encounter an F, extend the list of played notes
            'F' : [{ | glob, loc |

                // extend list notes being played (using some randomness :) )
                glob[\patternnotes] = glob[\patternnotes].add(glob[\acceptablenotes].choose);
				// limit pattern to 8 notes.
				if (glob[\patternnotes].size > 5) {
                    glob[\patternnotes].pop;
                };
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a +, transpose up
            '+': [{ | glob, loc |
				glob[\transpose] = (glob[\transpose] + [1,2,3].choose).clip(-9,9);

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a -, transpose down
            '-': [{ | glob, loc |
                //"transpose down".postln;
                glob[\transpose] = (glob[\transpose] - [1,2,3].choose).clip(-9, 9);

				glob[\tempo] = [0.8, 0.2, 0.4, 0.2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"remove first note".postln;
                if (glob[\patternnotes].size > 1) {
                    // keep at least one note
                    glob[\patternnotes] = glob[\patternnotes].reverse;
                    glob[\patternnotes].pop;
                    glob[\patternnotes] = glob[\patternnotes].reverse;
                };
				glob[\lag] = (glob[\lag] + 0.1).clip(0,2);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.1).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				glob[\tempo] = [0.8, 0.2, 0.4, 0.2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();

    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 2, mix = 0.2|
        var snd, click;
        // Basic tone is a SinOsc
        snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.03, Rand(0.7, 1.4), 1, -7), doneAction: 2);
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

	SynthDef(\blips, {arg out = 0, freq = 440, numharm = 11, att = 0.01, rel = 0.7, amp = 1, pan = 0.3;
		var snd, env;
		env = Env.perc(att, rel, amp).kr(doneAction: 2);
		snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], numharm, env))), 440, 0.4);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	SynthDef("Pdefhelp", { arg out, freq, sustain=0.7, amp=0.5, pan;
		var env, u=1;
		env = EnvGen.kr(Env.perc(0.01, sustain), 1, doneAction: Done.freeSelf);
		5.do { var d; d = exprand(0.01, 1); u = SinOsc.ar(d * 300, u, rrand(0.1,1.2) * d, 1) };
		Out.ar(out, Pan2.ar(SinOsc.ar(u + 1 * freq, 0, amp * env), pan));
	}).add;

	SynthDef("plucking", { arg amp = 0.1, freq = 440, decay = 2, coef = 0.2;
		var env, snd;
		env = EnvGen.kr(Env.linen(0, decay, 0), doneAction: 2);
		snd = Pluck.ar(
			in: WhiteNoise.ar(amp),
			trig: Impulse.kr(0),
			maxdelaytime: 0.1,
			delaytime: freq.reciprocal,
			decaytime: decay,
			coef: coef);
		Out.ar(0, [snd, snd]);
	}).add;

    s.sync;
    // up the rate a bit
	TempoClock.default = TempoClock.new(1.5);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;

		Pbindef(\p, \instrument, \plucking, \amp, 0.1);
		//Pbindef(\p, \instrument, \Pdefhelp, \amp, 0.1);
		Pbindef(\q, \instrument, \kalimba, \amp, 1);
		//q = Pbindef(\q, \instrument, \blips);

        lsys.getCalculatedString.do({
            | chr, idx |

            var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, l, l2, t, t2;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq(interp.globalState()[\patternnotes].debug("notes1"));
				n2 = Pseq(interp2.globalState()[\patternnotes].debug("notes2"));
				l = interp.globalState()[\lag].debug("lag");
				l2 = interp2.globalState()[\lag].debug("lag2");
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");

				pattern =
					Ppar([
						Pbindef(\p, \dur, t, \freq, n1, \legato, l, \transpose, trans),
						Pbindef(\q, \dur, t2, \freq, n2, \legato, l*0.5, \transpose, trans2),

				]);

                if (player.notNil) { player.stop; };

				player = pattern.play();

				1.wait;
                if (idx == (sz-1)) {
                    "*** ABOUT TO FINISH ***".postln;
                };
            }

        });
	//pattern.play;
    }

});
)


