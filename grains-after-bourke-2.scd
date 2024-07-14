/*
 // Grains, after P. Bourke
axiom: Y
rules:
  X => dX[-F+FF]cg[+F-FF]dFX
  Y => eYFX[+Y][-Y]

carnatic [1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 27/16, 9/5, 15/8, 2]

Naadana-amakriya
U 2*15/8, 1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8
D 15/8, 8/5, 3/2,, 4/3, 5/4, 16/15, 1 2*15/8

	// below is archytas enharmonic
    // 28/7, 36/35, 5/4, 4/3, 6/5,10/9
    // 28/7, 36/35, 5/4, 4/3, 6/5,10/9

*/


(
s.waitForBoot({
    var player;
    var lsys = LSystem(
        iterations:3,
        axiom:"Y",
        constants:Set[],
        rules:(
			\X : "X[-F+FF][+F-FF]FX",
			\Y : "YFX[+Y][-Y]",
	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			\up : 54.midicps *  [2*15/8, 1, 16/15, 5/4, 4/3, 3/2, 8/5],
			\down : 54.midicps * [15/8, 8/5, 3/2, 4/3, 5/4, 16/15, 1],
            \patternnotes : 54.midicps * [2*15/8, 1, 16/15],
			\customnotes: ["c3_16@numharm[12]","g-3_8@numharm[10]"], // not used.
            \transpose : 1,
			\counter : 0,
			\lag: 0.0,
            \tempo : 0.2,
			\dur : 0.2
        ),
        actions:(
            // whenever you encounter an F, transpose tempo
            'F' : [{ | glob, loc |
				glob[\tempo] = [0.3, 0.6, 0.9, 0.3, 0.1].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a +, extend the list of played notes
            '+': [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
                glob[\patternnotes] = glob[\patternnotes].add(glob[\up].choose);
				// limit pattern to 8 notes.
				if (glob[\patternnotes].size > 9) {

                    glob[\patternnotes].pop;
					//glob[\patternnotes] = glob[\patternnotes].add(\rest);

                };
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a -, add an itial note
            '-': [{ | glob, loc |
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
				glob[\transpose] = [3/4,1,2].choose;
				glob[\lag] = (glob[\lag] + 0.3).clip(0,2);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.1).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				//glob[\tempo] = [0.6, 0.3, 0.1, 0.3].choose;
				glob[\transpose] = [1,2,1/2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );


    var interp2 = interp.deepCopy();

    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 0.1, mix = 0.1, rel = 2.0|
        var snd, click;
        // Basic tone is a SinOsc
        snd = SinOsc.ar(freq) * EnvGen.ar(Env.perc(0.03 , rel, 1, -7), doneAction: 2);
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

	SynthDef(\risset, {|out = 0, pan = 0, freq = 440, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0,vibAdd=0.5|
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
	SynthDef("bird", { arg out, freq, sustain=0.7, amp=0.5, pan;
		var env, u=1;
		env = EnvGen.kr(Env.perc(0.01, sustain), 1, doneAction: Done.freeSelf);
		5.do { var d; d = exprand(0.01, 1); u = SinOsc.ar(d * 300, u, rrand(0.1,1.2) * d, 1) };
		Out.ar(out, Pan2.ar(SinOsc.ar(u + 1 * freq, 0, amp * env), pan));
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

	TempoClock.default = TempoClock.new( (1+ sqrt(5))/2);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;


		//Pbindef(\r, \instrument, \blips, \amp, 0.2, \rel, 0.3, \harms, 22);
		Pbindef(\q, \instrument, \risset, \amp, 0.01, \rel, 0.1);
		Pbindef(\p, \instrument, \kalimba, \amp, 0.5, \rel, 0.4);
		Pbindef(\r, \instrument, \bird, \amp, 0.04, \rel, 0.2);

        lsys.getCalculatedString.do({
            | chr, idx |

            var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, l, l2, t, t2, tadd, harms, ampl;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq(trans * interp.globalState()[\patternnotes].debug("n1"));
				n2 = Pseq(trans * interp2.globalState()[\patternnotes].debug("n2"));
				l = interp.globalState()[\lag].debug("lag");
				l2 = interp2.globalState()[\lag].debug("lag2");
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");
				tadd = t + t2; // for longer releases
				// this should be a curve.
				ampl = 0.04;
				if (trans >1 ) { ampl = 0.03 };
				if (trans >1.5 ) { ampl = 0.03 };
				if (trans >2 ) { ampl = 0.02 };

				// we're mixing bind and bindef case, well, bell
				pattern = Ppar([
					if (tadd > 0.6) {
						Pbind(\instrument, \bell, \t60, tadd, \fs, n1, \pitchy, 1, \dur, t, \amp, ampl)},
					if (tadd > 0.2 ) {
						Pbindef(\r, \dur, tadd, \freq, n2, \rel, tadd, \amp, ampl*2)};,
					    Pbindef(\p, \dur, t2, \freq, n1, \rel, t2, \amp, (ampl*9)+t2),

				]);

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

