/*
// P. Bourke after Saupe
axiom: VZFFF
rules:
  V -> [+++W][---W]YV
  W -> +X[-W]Z
  X -> -W[+X]Z
  Y -> YZ
  Z -> [-FcFF][+FdFF]F


*/


(
s.waitForBoot({
    var player;
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
			\acceptablenotes : 60.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8, 2, 2*16/15, 2*5/4, 2*4/3, 2*3/2];,
			\up : 60.midicps * [1, 16/15, 5/4, 4/3, 3/2, 8/5, 15/8],
			\down : 60.midicps * [2, 2*16/15, 2*5/4, 2*4/3, 2*3/2],
			//\pup : 60.midicps * [1, 9/8, 5/4, 3/2, 27/16, 2],
			//\pdn : 60.midicps * [2, 27/16, 3/2, 4/3, 5/4, 9/8, 1],
			\pnotes : 60.midicps * [1, 5/4],
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
				glob[\transpose] = [1,2].choose;
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
				glob[\tempo] = (glob[\tempo] / 2).clip(0.2, 0.4);
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
				glob[\tempo] = (glob[\tempo] * 2).clip(0.2, 0.4);
                // always return state at the end
                [glob, loc];
            }, nil],
            // whenever you encounter an X, remove first note from the played notes
            'X' : [{ | glob, loc |
                //"transpose down".postln;
				glob[\lag] = (glob[\lag] + 0.5).clip(0,2);
                // always return state at the end
                [glob, loc];
            }, nil],
			//[0.1, 0.2, 0.3, 0.4, 0.5].choose;
            // whenever you encounter a Y, change tempo (randomly) )
            'Y' : [{ | glob, loc |
				glob[\lag] = (glob[\lag] - 0.3).clip(0,2);
				//glob[\patternnotes] = glob[\patternnotes].add(glob[\customnotes].choose.debug("add new custom"));
				//glob[\tempo] = [0.4, 0.2, 0.8].choose;
				glob[\transpose] = [1,3/4,2].choose;
                // always return state at the end
                [glob, loc];
            }, nil],
        )
    );

    var interp2 = interp.deepCopy();


	SynthDef("waveguideFlute", { arg scl = 0.2, freq = 440, ipress = 0.9, ibreath = 0.06, ifeedbk1 = 0.4, ifeedbk2 = 0.4, dur = 0.5, gate = 0.5, amp = 1;

		var kenv1, kenv2, kenvibr, kvibr, sr, cr, block;
		var poly, signalOut, ifqc;
		var aflow1, asum1, asum2, afqc, atemp1, ax, apoly, asum3, avalue, atemp2, aflute1;
		var fdbckArray;

		sr = SampleRate.ir;
		cr = ControlRate.ir;
		block = cr.reciprocal;

		ifqc = freq;

		// noise envelope
		kenv1 = EnvGen.kr(Env.new(
			[ 0.0, 1.1 * ipress, ipress, ipress, 0.0 ], [ 0.06, 0.2, dur - 0.46, 0.2 ], 'linear' )
		);
		// overall envelope
		kenv2 = EnvGen.kr(Env.new(
			[ 0.0, amp, amp, 0.0 ], [ 0.01, dur - 0.02, 0.1 ], 'linear' ), doneAction: 2
		);
		// vibrato envelope
		kenvibr = EnvGen.kr(Env.new( [ 0.0, 0.0, 1, 1, 0.0 ], [ 0.5, 0.5, dur - 1.5, 0.5 ], 'linear') );

		// create air flow and vibrato
		aflow1 = LFClipNoise.ar( sr, kenv1 );
		kvibr = SinOsc.ar( 5, 0, 0.1 * kenvibr );

		asum1 = ( ibreath * aflow1 ) + kenv1 + kvibr;
		afqc = ifqc.reciprocal - ( asum1/20000 ) - ( 9/sr ) + ( ifqc/12000000 ) - block;

		fdbckArray = LocalIn.ar( 1 );

		aflute1 = fdbckArray;
		asum2 = asum1 + ( aflute1 * ifeedbk1 );

		//ax = DelayL.ar( asum2, ifqc.reciprocal * 0.5, afqc * 0.5 );
		ax = DelayC.ar( asum2, ifqc.reciprocal - block * 0.5, afqc * 0.5 - ( asum1/ifqc/cr ) + 0.001 );

		apoly = ax - ( ax.cubed );
		asum3 = apoly + ( aflute1 * ifeedbk2 );
		avalue = LPF.ar( asum3, 2000 );

		aflute1 = DelayC.ar( avalue, ifqc.reciprocal - block, afqc );

		fdbckArray = [ aflute1 ];

		LocalOut.ar( fdbckArray );

		signalOut = avalue;

		OffsetOut.ar( 0, [ signalOut * kenv2, signalOut * kenv2 ] );

	}).add;

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

	SynthDef(\risset, {|out = 0, pan = 0, freq = 440, amp = 0.05, att = 0.005, rel = 1, gate = 1,vibFreq=7, vibAmp=0.1,vibAdd=0.5|
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

	TempoClock.default = TempoClock.new(1.25);

	fork {
        var skipfirstidx = 0; // increase to skip more steps at the beginning
        var sz = lsys.getCalculatedString.size();
		var p, q, pattern;

		Pbindef(\r, \instrument, \risset, \amp, 0.06, \rel, 0.8);
		Pbindef(\p, \instrument, \kalimba, \amp, 0.9);
		Pbindef(\q, \instrument, \mallet, \amp, 0.1, \rel, 1);

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
				tadd = t + t2;
                ampl = 0.06;
				if (t < 0.4 ){ampl = 0.05;};
				pattern = Ppar([
					if (t > 0.2) { Pbindef(\r,  \dur, t, \freq, n2, \legato, l , \rel, t + 0.4)};,
					    Pbindef(\p, \dur, t, \freq, n1, \legato, l, \rel, t  ),
					if (t < 0.4) {Pbindef(\q, \dur, t*2, \freq, n2, \legato, l, \rel, t*2  )};
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
