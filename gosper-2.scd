

/*
// Hexagonal Gosper
axiom: X
rules:
 X => X+YF++YF-FX--FXFX-YF+
 Y => -FX+YFYF++YF+FX--FX-Y
*/

(
s.waitForBoot({
    var player;
	var sc = Scale.pelog;
    var lsys = LSystem(
        iterations:2,
        axiom:"X",
        constants:Set[],
        rules:(
			\X : "X+YF++YF-FX--FXFX-YF+",
			\Y : "-FX+YFYF++YF+FX--FX-Y",

	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			//\acceptablenotes : 60.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8],
			\acceptablenotes : 60.midicps * [1, 9/8, 5/4, 3/2, 27/16, 2, 15/18, 27/16, 3/2, 4/3, 5/4, 9/8, 1],
			// this is the method using Scale as defined above.
			//\acceptablenotes : 60.midicps * sc.ratios,
			\patternnotes : 60.midicps * [1, 5/4, 3/2],
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
				glob[\transpose] = [1, 1/2, 1, 2, 1].choose;
                // always return state at the end
                [glob, loc];
            }, nil],

            '+': [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
				glob[\patternnotes] = glob[\patternnotes].addFirst(glob[\acceptablenotes].choose);
				// limit pattern to 8 notes.
				if (glob[\patternnotes].size > 16) {
                    glob[\patternnotes].pop;
                };
                // always return state at the end
                [glob, loc];
            }, nil],

            '-': [{ | glob, loc |
                //"remove first note".postln;
                if (glob[\patternnotes].size > 2) {
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
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 0.9;
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

	SynthDef (\sc303 , {  arg  out=0, freq=440, wave=0, ctf=100, res=0.3,
		sus=0.5, dec=0.8, env=1000, gate=1, vol=0.1;
		var  filEnv, volEnv, waves;
		volEnv =  EnvGen .ar( Env .new([10e-10, 1, 1, 10e-10], [0.01, sus, dec],  'exp' ), gate, doneAction:2);
		filEnv =  EnvGen .ar( Env .new([10e-10, 1, 10e-10], [0.01, dec],  'exp' ), gate);
		waves = [ Saw .ar(freq, volEnv),  Pulse .ar(freq, 0.5, volEnv)];
		Out .ar(out,  RLPF .ar(  Select .ar(wave, waves), ctf + (filEnv * env), res).dup * vol);
	}).add;

	SynthDef(\blips, {arg out = 0, freq = 440, numharm = 11, att = 0.01, rel = 0.7, amp = 0.2, pan = 0.3;
		var snd, env;
		env = Env.perc(att, rel, amp).kr(doneAction: 2);
		snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], numharm, env))), 440, 0.4);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

SynthDef(\fatsaw,
	{
		arg freq=440, amp=0.3, fat=0.0033, ffreq=2000, atk=0.001, dec=0.2, sus=0.3, rls=0.1,gate=1;

		var f1,f2,f3,f4,synth;

		f1=freq-(freq*fat);
		f2=freq-(freq*fat/2);
		f3=freq+(freq*fat/2);
		f4=freq+(freq*fat);

		synth = LFSaw.ar([f1,f2,f3,f4],[0,0.001,0.002,0.004,0.008]);
		synth = synth * EnvGen.kr(Env([0,1,sus,0],[atk,dec,rls],'lin',2),gate,doneAction:0);
		synth=Splay.ar(synth,0.7);
		synth=RLPF.ar(synth,ffreq*Linen.kr(gate,0.1,0.4,0.2,0),0.4);
		Out.ar([0,1],synth*amp);
},[0.1,0.3,4,2]).add;



		SynthDef(\risset, {|out = 0, pan = 0, freq = 400, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0.1,vibAdd=0.5|
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

	SynthDef("plucking", {arg amp = 0.1, freq = 440, decay = 2, coef = 0.1;

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
	SynthDef("bird", { arg out, freq, sustain=0.7, amp=0.5, pan;
		var env, u=1;
		env = EnvGen.kr(Env.perc(0.01, sustain), 1, doneAction: Done.freeSelf);
		5.do { var d; d = exprand(0.01, 1); u = SinOsc.ar(d * 300, u, rrand(0.1,1.2) * d, 1) };
		Out.ar(out, Pan2.ar(SinOsc.ar(u + 1 * freq, 0, amp * env), pan));
	}).add;

	s.sync;
	// up the rate a bit
	TempoClock.default = TempoClock.new(1);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;

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
                var repeats = 2;
                if (idx == (sz-1)) { repeats = 3; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq(trans * interp.globalState()[\patternnotes],repeats);
				n2 = Pseq(trans2 * interp2.globalState()[\patternnotes],repeats);
				n3 = Pseq(interp2.globalState()[\patternnotes].debug("notes2"),repeats);
				l = interp.globalState()[\lag];
				l2 = interp2.globalState()[\lag];
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");
				tadd = t + t2;
				ampl = 0.03;
				if (trans >1 ) { ampl = 0.03 };
				if (trans >1.5 ) { ampl = 0.02 };
				if (trans >2 ) { ampl = 0.01 };
				pattern = Ppar([
					//if (trans2 > 0.5) {
					//	Pbind(\instrument, \plucking, \dur, t2, \freq, n2, \amp, ampl+0.02, \rel, t2)},
					if (trans < 2.0) {
						Pbind(\instrument, \bell, \t60, tadd, \fs, n1, \pitchy, 1, \dur, t, \amp, ampl)},

						Pbind(\instrument, \bird, \freq, n2, \amp, ampl+0.02, \rel, t2, \dur, t2),
						//Pbind(\instrument, \kalimba, \freq, n2, \amp, ampl * 15, \rel, t2, \dur, t2),

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
    }
});
)



