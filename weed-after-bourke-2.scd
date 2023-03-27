/*
// Weed, P. Bourke
axiom: F
rules:
  F -> FF-[XY]+[XY]
  X -> +FY
  Y -> -FX
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
    // sitar
	// 48.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8, 2, 2*16/15, 2*5/4, 2*4/3, 2*3/2];
    // 28/7, 36/35, 5/4, 4/3, 6/5,10/9


    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			\acceptablenotes : 58.midicps * [1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 27/16, 9/5, 15/8, 2],
			\up : 58.midicps * [1, 9/8, 5/4, 3/2, 27/16],
			\down : 58.midicps * [2, 15/18, 27/16, 3/2, 4/3, 5/4, 9/8, 1],
			\patternnotes : 58.midicps * [1, 5/4, 27/16],
			\customnotes: ["c3_16@numharm[12]","g-3_8@numharm[10]"], // not used.
            \transpose : 1,
			\counter : 0,
			\lag: 0.0,
            \tempo : 0.2,
			\dur : 0.2
        ),
        actions:(
            // whenever you encounter an F, extend the list of played notes
            'F' : [{ | glob, loc |
				glob[\tempo] = [0.8, 0.2, 0.4, 0.2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a +, transpose up
            '+': [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
                glob[\patternnotes] = glob[\patternnotes].add(glob[\up].choose);
				// limit pattern to 8 notes.
				if (glob[\patternnotes].size > 9) {
                    glob[\patternnotes].pop;
                };
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a -, transpose down
            '-': [{ | glob, loc |
                //"remove first note".postln;
				// limit pattern to 8 notes.
				glob[\patternnotes] = glob[\patternnotes].addFirst(glob[\down].choose);
				if (glob[\patternnotes].size > 1) {
                    glob[\patternnotes].pop;
                };

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"transpose down".postln;
                glob[\transpose] = [1,2,3].choose;
				glob[\lag] = (glob[\lag] + 0.2).clip(0,2);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.2).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				glob[\tempo] = [0.8, 0.2, 0.4, 0.2].choose;
				glob[\transpose] = [1/2,3/4].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();

    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 2, mix = 0.2, rel = 1.4|
        var snd, click;
        // Basic tone is a SinOsc
        snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.03, rel, 1, -7), doneAction: 2);
        snd = HPF.ar( LPF.ar(snd, 380), 120);
        // The "clicking" sounds are modeled with a bank of resonators excited by enveloped white noise
        click = DynKlank.ar(`[
            // the resonant frequencies are randomized a little to add variation
            // there are two high resonant freqs and one quiet "bass" freq to give it some depth
            [240*ExpRand(0.97, 1.02), 2020*ExpRand(0.97, 1.02), 3151*ExpRand(0.97, 1.02)],
            [-9, 0, -5].dbamp,
            [0.8, 0.07, 0.08]
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 1;
        snd = (snd*mix) + (click*(1-mix));
        snd = Mix( snd );
        Out.ar(out, Pan2.ar(snd, 0, amp));
    }).add;

	SynthDef(\blips, {arg out = 0, freq = 440, harms = 11, att = 0.01, rel = 0.7, amp = 1, pan = 0.0;
		var snd, env;
		env = Env.perc(att, rel, amp).kr(doneAction: 2);
		snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], harms, env))), 440, 0.4);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	SynthDef("bird", { arg out, freq, sustain=0.7, amp=0.5, pan;
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
	TempoClock.default = TempoClock.new(1.25);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;


		Pbindef(\p, \instrument, \kalimba, \amp, 0.3);
		Pbindef(\q, \instrument, \plucking, \amp, 0.08, \decay, 2);
		Pbindef(\r, \instrument, \blips, \amp, 0.3, \rel, 0.9);

		//Pbindef(\p, \instrument, \plucking, \amp, 0.1);
		//q = Pbindef(\q, \instrument, \blips);

        lsys.getCalculatedString.do({
            | chr, idx |

			// var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, l, l2, t, t2, trel,harms,transf;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");
				//transf = (trans/trans2).debug("transf");

				n1 = Pseq( trans * interp.globalState()[\patternnotes].debug("n1"));
				n2 = Pseq(  trans2 * interp2.globalState()[\patternnotes].debug("n2"));

				l = interp.globalState()[\lag].debug("lag");
				l2 = interp2.globalState()[\lag].debug("lag2");
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");

				trel = t + t2; // for longer releases
				harms = (7 + trans + trans2 + trel ).clip(6,20).debug("harms");

				pattern =Ppar([
					Pbindef(\p, \dur, t, \freq, n2, \legato, l, \rel, trel + t),
					Pbindef(\q, \dur, t2, \freq, n2, \legato, l, \decay, trel),
					Pbindef(\r, \dur, t2*2, \freq, n1, \legato, l, \rel, trel, \harms, harms)

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



