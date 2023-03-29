/*
// another aquatic
axiom: F
rules:
  F => FXYOXBPYXO
  X => [-F++F++]
  Y => [+F--F--]
  O => ++F--F
  P => --F++F

using notes of the Mohanam raga
Up 1, 9/8, 5/4, 3/2, 27/16
Down 2, 27/16, 3/2, 5/4, 9/8

*/

(
s.waitForBoot({
    var player;
    var lsys = LSystem(
        iterations:3,
        axiom:"F",
        constants:Set[],
        rules:(
			\F : "FXYOXBPYXO",
			\X : "[-F++F++]",
			\Y : "[+F--F--]",
			\O : "++F--F",
			\P : "--F++F"

	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			\up : 57.midicps * [1, 9/8, 5/4, 3/2, 27/16],
			\down : 57.midicps * [2, 27/16, 3/2, 5/4, 9/8],
			\patternnotes : 57.midicps * [1,5/4,27/16],
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
				if (glob[\patternnotes].size > 9) {
                    glob[\patternnotes].pop;
                };

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"transpose down".postln;
                glob[\transpose] = [3/4,1/2].choose;
				glob[\lag] = (glob[\lag] + 0.3).clip(0,2);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.1).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				glob[\transpose] = [1,2,3].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();

    SynthDef(\kalimba, {
        |out = 0, freq = 440, amp = 2, mix = 0.2, rel = 0.7|
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
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 0.9;
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

	SynthDef (\sc303 , {  arg  out=0, freq=440, wave=10, ctf=100, res=0.1,
		sus=0.4, dec=0.4, env=500, gate=1, vol=0.08;
		var  filEnv, volEnv, waves;
		volEnv =  EnvGen .ar( Env .new([10e-10, 1, 1, 10e-10], [0.01, sus, dec],  'exp' ), gate, doneAction:2);
		filEnv =  EnvGen .ar( Env .new([10e-10, 1, 10e-10], [0.01, dec],  'exp' ), gate);
		waves = [ Saw .ar(freq, volEnv),  Pulse .ar(freq, 0.5, volEnv)];
		Out .ar(out,  RLPF .ar(  Select .ar(wave, waves), ctf + (filEnv * env), res).dup * vol);
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

	SynthDef("bird", { arg out, freq, sustain=0.7, amp=0.5, pan;
		var env, u=1;
		env = EnvGen.kr(Env.perc(0.01, sustain), 1, doneAction: Done.freeSelf);
		5.do { var d; d = exprand(0.01, 1); u = SinOsc.ar(d * 300, u, rrand(0.1,1.2) * d, 1) };
		Out.ar(out, Pan2.ar(SinOsc.ar(u + 1 * freq, 0, amp * env), pan));
	}).add;

	SynthDef(\bell, {
		|fs=1, t60=0.5, pitchy=1, amp=0.05, gate=1,dur=0.5|
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
		sig=sig*0.8+CombC.ar(sig,0.5,0.3,0.5,0.2)*amp;
		DetectSilence.ar(sig, 0.001, dur, doneAction:2);
		Out.ar(0, [sig,sig]);
	}).add;



	// up the rate a bit
	s.sync;
	TempoClock.default = TempoClock.new(1.2);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;


		Pbindef(\r, \instrument, \blips, \amp, 0.1, \sus, 0.9, \pan, 0.0);
		Pbindef(\p, \instrument, \kalimba, \amp, 0.38);
		Pbindef(\q, \instrument, \plucking, \amp, 0.05, \decay, 2);
		//Pbindef(\p, \instrument, \plucking, \amp, 0.1);
		//q = Pbindef(\q, \instrument, \blips);

        lsys.getCalculatedString.do({
            | chr, idx |
            var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, l, l2, t, t2, trel, harms,ampl;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq( trans.abs * interp.globalState()[\patternnotes].debug("n1"));
				n2 = Pseq( trans2.abs * interp2.globalState()[\patternnotes].debug("n2"));

				l = interp.globalState()[\lag].debug("lag");
				l2 = interp2.globalState()[\lag].debug("lag2");
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");
				trel = t + t2; // for longer releases
				harms = (9 + [trans,trans2].choose + t2).clip(4,20).debug("harms");
				ampl = 0.04;
				if (trans >1 ) { ampl = 0.04 };
				if (trans >1.5 ) { ampl = 0.03 };
				if (trans >2 ) { ampl = 0.02 };

				pattern = Ppar([
						Pbind(\instrument, \bird, \dur, t2, \freq, n2, \rel, t2, \amp, ampl + 0.08 ),
					    Pbindef(\p, \dur, trel, \freq, n1, \rel, trel, \amp, 0.38 + t),
					    Pbind(\instrument, \bell, \t60, trel, \fs, n1, \pitchy, 1, \dur, t2, \amp, ampl),
					if (trel > 0.8) {
						Pbindef(\q, \dur, t2, \freq, n2, \decay, trel+t)}

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

