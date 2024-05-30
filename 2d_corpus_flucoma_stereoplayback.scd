(

~path = PathName(thisProcess.nowExecutingPath).parentPath;
~loader = Buffer.read(s,~path ++ "130BPM_ALIGNED_SILHOUETTES.wav");

~src = Buffer(s);

FluidBufCompose.processBlocking(s,~loader,startChan:0,numChans:1,destination:~src,destStartChan:0,gain:-8.dbamp);

FluidBufCompose.processBlocking(s,~loader,startChan:1,numChans:1,destination:~src,destStartChan:0,gain:-8.dbamp,destGain:1);
// FluidWaveform(~src);




//manually create slice points array load into buffer, for slicing quarter beats etc

~list = Array.series(918,0,0.231*44100);
~indices = Buffer.loadCollection(s, ~list);

)


// ~loader.play;

/* non-realtime transient detection, load slice points into separate buffer
(
~indices = Buffer(s);
FluidBufOnsetSlice.processBlocking(s,~src,metric:9,threshold:0.3,indices:~indices,action:{"done".postln});
)
*/



)


// a function to play back any individual slice point
(
~play_slice = {
	arg index;
	{
		var startsamp = Index.kr(~indices,index);
		var stopsamp = Index.kr(~indices,index+1);
		var phs = Phasor.ar(0,BufRateScale.ir(~loader),startsamp,stopsamp);
		var sig = BufRd.ar(2,~loader,phs);
		var dursecs = (stopsamp - startsamp) / BufSampleRate.ir(~loader);
		var env = EnvGen.kr(Env([0,1,1,0],[0.03,dursecs-0.06,0.03]),doneAction:2);
		sig * env;
	}.play;
};
)
~play_slice.(200)

// analysis
(
~analyses = FluidDataSet(s);
~indices.loadToFloatArray(action:{
	arg fa;
	var spec = Buffer(s);
	var stats = Buffer(s);
	var stats2 = Buffer(s);
	var loudness = Buffer(s);
	var point = Buffer(s);

	fa.doAdjacentPairs{
		arg start, end, i;
		var num = end - start;

		FluidBufSpectralShape.processBlocking(s,~src,start,num,features:spec,select:[\centroid]);
		FluidBufStats.processBlocking(s,spec,stats:stats,select:[\mean]);

		FluidBufLoudness.processBlocking(s,~src,start,num,features:loudness,select:[\loudness]);
		FluidBufStats.processBlocking(s,loudness,stats:stats2,select:[\mean]);

		FluidBufCompose.processBlocking(s,stats,destination:point,destStartFrame:0);
		FluidBufCompose.processBlocking(s,stats2,destination:point,destStartFrame:1);

		~analyses.addPoint(i,point);
		s.sync;
		i.postln;
	};

	s.sync;

	~analyses.print;

	// normalize
~normed = FluidDataSet(s);
FluidNormalize(s).fitTransform(~analyses,~normed);
// fit a kdtree
~tree = FluidKDTree(s).fit(~normed);
});


)

(
// normalize
~normed = FluidDataSet(s);
FluidNormalize(s).fitTransform(~analyses,~normed);
// fit a kdtree
~tree = FluidKDTree(s).fit(~normed);
)


// plot
(
~normed.dump({
	arg dict;
	var point = Buffer.alloc(s,2);
	var previous = nil;
	dict.postln;
	defer{
		FluidPlotter(dict:dict,mouseMoveAction:{
			arg view, x, y;
			[x,y].postln;
			point.setn(0,[x,y]);
			~tree.kNearest(point,1,{
				arg nearest;
				if(nearest != previous){
					nearest.postln;
					view.highlight_(nearest);
					~play_slice.(nearest.asInteger);
					previous = nearest;
				}
			});
		});
	}
});
)
