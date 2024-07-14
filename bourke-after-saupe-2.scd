/*
// P. Bourke after Saupe
axiom: VZFFF
rules:
  V -> [+++W][---W]YV
  W -> +X[-W]Z
  X -> -W[+X]Z
  Y -> YZ
  Z -> [-FcFF][+FdFF]F
\ bayati: Bayati
\ bhairav: Bhairav
\ farahfaza
\ ajam
\ ahirbhairav
\ nikriz;
\ nawaAthar
		var frqs = #[0.56, 0.56, 0.92, 0.92, 1.19, 1.7, 2, 2.74, 3, 3.76, 4.07];
*/
Scale.directory
a = Scale.nikriz;
Pbind(\scale, a, \degree, Pseq((0..7) ++ (6..0) ++ [\rest], 1), \dur, 0.25).play;

(
s.waitForBoot({
    var player;
	var sc = Scale.harmonicMinor;
    var lsys = LSystem(
        iterations:3,
        axiom:"VZFFF",
        constants:Set[],
        rules:(
			\V : "[+++W][---W]YV",
			\W : "+X[-W]Z",
			\X : "-W[+X]Z",
			\Y : "YZ",
			\Z : "[-FFF][+FFF]F"
	));

    var interp = LSystemInterpreter(
        lsystem:lsys,
        globalstate:(
			//\up : 60.midicps * sc.ratios,
			//\down: 60.midicps * sc.ratios.reverse,
			\up : 60.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8],
			\down : 60.midicps * [2, 2*16/15, 2*5/4, 2*4/3, 2*3/2],
			//\pup : 60.midicps * [1, 9/8, 5/4, 3/2, 27/16, 2],
			//\pdn : 60.midicps * [2, 27/16, 3/2, 4/3, 5/4, 9/8, 1],
			\pnotes : 60.midicps * sc.ratios, //60.midicps * [1, 5/4],
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
			    //glob[\tempo] = [0.8, 0.2, 0.4].choose;
				glob[\transpose] = [1/2,1,2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a +, transpose up
            '+': [{ | glob, loc |
                // extend list notes being played (using some randomness :) )
				glob[\pnotes] = glob[\pnotes].add(glob[\up].choose);
				// limit pattern to 8 notes.
				if (glob[\pnotes].size > 8) {
                    glob[\pnotes].pop;
                };

                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter a -, transpose down
            '-': [{ | glob, loc |
                //"remove first note".postln;
				// limit pattern to 8 notes.
				glob[\pnotes] = glob[\pnotes].addFirst(glob[\down].choose);
				if (glob[\pnotes].size > 1) {
                    glob[\pnotes].pop;
                };
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"transpose down".postln;
				glob[\lag] = (glob[\lag] + 0.5).clip(0,2);
				glob[\tempo] = [3/8, 1/8, 1/4, 1/2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.3).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				//glob[\tempo] = [0.4, 0.2, 0.8,10.0].choose;
				//glob[\tempo] = (glob[\tempo] / 2).clip(1/8, 1/4, 1/2);
				glob[\tempo] = [1/2,3/4,1].choose;
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
        ], BPF.ar(PinkNoise.ar, 6500, 0.1) * EnvGen.ar(Env.perc(0.001, 0.01))) * 0.6;
        snd = (snd*mix) + (click*(1-mix));
        snd = Mix( snd );
        Out.ar(out, Pan2.ar(snd, 0, amp));
    }).add;

    SynthDef(\flute, {
		| out = 0, freq = 440, amp = 1.0, a = 0.05, r = 0.1|
		//var fmod = 1; // clean
		//var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.1)); // tone deaf flute
		var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.02)); // flute-like sound
		var env = EnvGen.ar(Env.perc(a, r), levelScale:0.5, doneAction:2);
		var snd = SinOsc.ar(freq * fmod)!2;
		Out.ar(bus:out, channelsArray:(env*(amp*snd).tanh));
	}).add;

	SynthDef(\blips, {arg out = 0, freq = 440, numharm = 10, att = 0.01, rel = 1, amp = 0.2, pan = 0.0;
		var snd, env;
		env = Env.perc(att, rel, amp).kr(doneAction: 2);
		snd = BPF.ar(LeakDC.ar(Mix(Blip.ar([freq, freq*1.01], numharm, env))), 440, 0.5);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	SynthDef(\mallet,{arg in=0,out=0,freq=440,amp=1,rel=1,p=0;

		var sig=Array.fill(3,{|n| SinOsc.ar(freq+(n*0.01),mul:amp*0.3)}).sum;
		var env=EnvGen.kr(Env.perc(0.001,rel),gate:1,doneAction:2);
		sig=sig*0.8+CombC.ar(sig,0.5,0.3,0.5,0.2);
		Out.ar(out,Pan2.ar(sig*env,pos:p));
	};
	).add;

	SynthDef(\risset, {|out = 0, pan = 0, freq = 450, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0.1,vibAdd=0.5|
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

	TempoClock.default = TempoClock.new(1);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;

		Pbindef(\r, \instrument, \flute, \amp, 0.1, \rel, 0.8);
		Pbindef(\p, \instrument, \kalimba, \amp, 0.9);
		Pbindef(\q, \instrument, \mallet, \amp, 0.2, \rel, 1);

        lsys.getCalculatedString.do({
            | chr, idx |

            var transposedpattern;
            var trans;
            var trans2;
			var n1, n2, n3, l, l2, t, t2, tadd, wave, ampl;

            ("*** PART" + (idx+1) + "OF" + sz + "***").postln;
            interp.step(idx);
            interp2.step(idx);
            // start playing from step skipfirstidx
            if (idx > skipfirstidx) {
                var repeats = 1;
                if (idx == (sz-1)) { repeats = 2; }; // don't repeat last pattern indefinitely
                trans = interp.globalState()[\transpose].debug("trans");
                trans2 = interp2.globalState()[\transpose].debug("trans2");

				n1 = Pseq(trans * interp.globalState()[\pnotes].debug("n1"));
				n2 = Pseq(trans2 * interp2.globalState()[\pnotes].debug("n2"));
				n3 = Pseq( [n1.first] );
				l = interp.globalState()[\lag].debug("lag");
				l2 = interp2.globalState()[\lag].debug("lag2");
				t = interp.globalState()[\tempo].debug("tempo");
                t2 = interp2.globalState()[\tempo].debug("tempo2");
				tadd = (t + t2).debug("tadd");
                ampl = 0.1;
				if (t < 0.4 ){ampl = 0.07;};
				pattern = Ppar([
					if (tadd > 0.3) { Pbindef(\r,  \dur, t, \freq, n1, \legato, l , \rel, tadd + t2)};,
					    Pbindef(\p, \dur, t, \freq, n2, \legato, l, \rel, tadd  ),
					if (tadd < 1.5) {Pbindef(\q, \dur, t2, \freq, n1, \legato, l, \rel, tadd , \amp , ampl )};
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
