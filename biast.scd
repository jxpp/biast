(
~env_AD = {
	var attack=0.01, decay=0.3;
	Env.adsr(attackTime: attack, decayTime: decay, sustainLevel: 0.0, releaseTime: 0.0);
};
~wavefold_shape = Buffer.alloc(s, 512, 1, { |buf| buf.chebyMsg([1,0,1,1,0,1])});

/*
!!! WORK IN PROGRESS !!!
Heavily inspired by Noise Engineering's eurorack modules: here's the Biast. A
funky parametrized weird noise machine based on an additive oscillator with
some noise. Does some percussive fun stuff. Enjoy, it's a Biast™ to play!

Quick-start guide:

The Biast™ (patent pending) is based on sine waves in related tunings, along
with a noise oscillator. This gets all summed up, goes through a wavefolding
stage and then gets outputted through a decay stage.

Spread: controls how far apart the different oscillators are. 0.0 is unison:
all oscillators are tuned to the same frequency. Try whole numbers to get
harmonics of the root note or try in-between numbers for funky dissonant stuff.

Harmonic: controls the relative volume of the oscillators.

TODO:
- Kinda wonky and experimental still.
- FM isn't implemented yet. In the future I'm planning on implementing FMing
  between the different oscillators.
- For the fold stage -> have to learn to fix DC offset and normalize amplitude before fold stage.
- Parametrize number of oscillators
- Morph between waves: Sine -> Triangle -> Saw -> Square
*/


SynthDef(\biast,
	{
		arg
		    freq=440,
		    gate=1,
		    penv=0, // amount of pitch envelope
		    n=1, // number of oscillators
		    attack=0.5,
		    decay=0.5,
		    spread=0.0, // harmonic distribution
		    harmonic=0.0, // index of emphasized harmonic
		    fm=0.0,
		    fold=0.0;
		var
		    n_oscs,
		    noise, noise_attack,
		    indices, harmonic_muls,
		    waves_gen, waves,
		    pitch_env,
		    additive_stage,
		    attack_env, attack_stage,
		    fold_stage,
		    decay_env, decay_stage;

        // TODO: parametrize number of oscs
		n_oscs = floor(n).asInteger;

		pitch_env = EnvGen.kr(
			Env.perc(releaseTime: decay * 0.15),
			levelScale: penv * 3.0,
			gate: gate,
			doneAction: 0
		);

		// Noise oscillator
		// attacks between 0.0 and 0.5 determine its strength
		noise_attack = if (
			attack >= 0.5,
			0.0,
			1.0 - (attack * 2)
		);
		noise = WhiteNoise.ar(1.0 * noise_attack);

		// waves for the additive oscillator
		indices = Array.series(10.0, 1.0, spread);
		harmonic_muls = Array.fill(10, {
			arg i;
			1 - (abs((harmonic*10) - i) - 10);
		});

		waves_gen = Array.fill(10, {
			arg i;
			SinOsc.ar(
				freq: (freq + (freq * pitch_env)) * indices[i],
				mul: harmonic_muls[i];
			);
		});
		waves = Mix.ar(waves_gen)/10;

		// Additive stage
		additive_stage = Mix.ar([waves, noise*0.2]);

		// Attack stage
		attack_env = EnvGen.kr(Env.perc(if(attack < 0.5, 0.01, attack*0.6)), doneAction: 2);
		attack_stage = additive_stage * attack_env;

		// Wavefolding distortion
		// TODO: how do i fix DC
		// TODO: how do i normalize amplitude
		// TODO: Add compression / distortion
		fold_stage = LeakDC.ar(Shaper.ar(
			~wavefold_shape,
			attack_stage * (1.0 + fold),
			0.5
		));

		// Decay stage: we apply a final decay envelope
		decay_env = EnvGen.kr(~env_AD.value(attack: 0.01, decay: decay), gate: gate, doneAction: 2);
		decay_stage = fold_stage * decay_env;

		Out.ar([0, 1], decay_stage);
}).add;
)
