/*
// Gary Teachout Pean-c
axiom: FX
rules:
 F =>
 X =>  FX-FY-FX+FY+FX+FY+FX+FY+FX-FY-FX-FY-FX-FY-FX+FY+FX
 Y => FY

Sitar: 1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8, 2, 2*16/15, 2*5/4, 2*4/3, 2*3/2

*/

(
s.waitForBoot({
    var player;
    var lsys = LSystem(
        iterations:2,
        axiom:"FX",
        constants:Set[],
        rules:(
			\X : "FX-FY-FX+FY+FX+FY+FX+FY+FX-FY-FX-FY-FX-FY-FX+FY+FX",
			\Y : "FY",

	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			\acceptablenotes : 60.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8],
			\patternnotes : 60.midicps * [1, 16/15, 5/4],
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
				glob[\transpose] = [1/2, 1, 2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],

            '+': [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
				glob[\patternnotes] = glob[\patternnotes].addFirst(glob[\acceptablenotes].choose);
				// limit pattern to 8 notes.
				if (glob[\patternnotes].size > 5) {
                    glob[\patternnotes].pop;
                };
                // always return state at the end
                [glob, loc];
            }, nil],

            '-': [{ | glob, loc |
                //"remove first note".postln;
                if (glob[\patternnotes].size > 1) {
                    // keep at least one note
                    glob[\patternnotes].pop;
                };

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"transpose down".postln;
                glob[\tempo] = [0.8, 0.2, 0.4].choose;
				glob[\lag] = (glob[\lag] + 0.1).clip(0,1);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.1).clip(0,1);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				glob[\tempo] = [0.4, 0.2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();


    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 0.1, mix = 0.1, rel=1.4|
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
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 0.8;
        snd = (snd*mix) + (click*(1-mix));
        snd = Mix( snd );
        Out.ar(out, Pan2.ar(snd, 0, amp));
    }).add;


	SynthDef("plucking", { arg amp = 0.1, freq = 440, rel = 2, coef = 0.2;
		var env, snd;
		env = EnvGen.kr(Env.linen(0, rel, 0), doneAction: 2);
		snd = Pluck.ar(
			in: WhiteNoise.ar(amp),
			trig: Impulse.kr(0),
			maxdelaytime: 0.1,
			delaytime: freq.reciprocal,
			decaytime: rel,
			coef: coef);
		Out.ar(0, [snd, snd]);
	}).add;


	SynthDef(\bell, {
		|fs=1, t60=1, pitchy=1, amp=0.05, gate=1, cmb=0.5|
		var sig, exciter;
		//exciter = Impulse.ar(0);
		exciter = WhiteNoise.ar() * EnvGen.ar(Env.perc(0.001, 0.05), gate) * 0.25;
		sig = Klank.ar(
			`[
				[1, 2, 2.803, 3.871, 5.074, 7.81, 10.948, 14.421],   // freqs
				[1, 0.044, 0.891, 0.0891, 0.794, 0.1, 0.281, 0.079], // amplitudes
				[1, 0.205, 1, 0.196, 0.339, 0.047, 0.058, 0.047]*t60     // ring times
			],
			exciter,
			freqscale:fs*pitchy);
		//sig = FreeVerb.ar(sig) * amp;
		sig = sig*0.8+CombC.ar(sig,cmb,0.3,cmb,0.2) * amp;
		DetectSilence.ar(sig, 0.001, 0.5, doneAction:2);
		Out.ar(0, sig!2);
	}).add;

    s.sync;

	// up the rate a bit
	TempoClock.default = TempoClock.new(1);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;


		Pbindef(\r, \instrument, \blips, \amp, 0.4, \rel, 0.3, \numharms, 10);
		Pbindef(\p, \instrument, \kalimba, \amp, 0.5, \rel, 0.3);
		Pbindef(\q,  \instrument, \bell, \amp, 0.05, \t60, 2, \pitchy, 1);
		//Pbindef(\p, \instrument, \plucking, \amp, 0.1);
		//q = Pbindef(\q, \instrument, \blips);

        lsys.getCalculatedString.do({
            | chr, idx |

            var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, n3, l, l2, t, t2, tadd, ampl;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq(trans * interp.globalState()[\patternnotes]);
				n2 = Pseq(trans2 * interp2.globalState()[\patternnotes]);
				n3 = Pseq(interp2.globalState()[\patternnotes].debug("notes2"));
				l = interp.globalState()[\lag];
				l2 = interp2.globalState()[\lag];
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");
				tadd = t + t2;
				ampl = 0.04;
				if (trans >1 ) { ampl = 0.04 };
				if (trans >1.5 ) { ampl = 0.03 };
				if (trans >2 ) { ampl = 0.02 };
				pattern = Ppar([
					    Pbind(\instrument, \plucking, \dur, t, \freq, n2, \amp, ampl+0.05, \decay, tadd),
					    Pbind(\instrument, \bell, \t60, tadd, \fs, n1, \pitchy, 1, \dur, t2, \amp, ampl),
						//Pbind(\instrument, \blips, \freq, n2, \amp, ampl * 8, \rel, t2, \dur, t2),

					//
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



