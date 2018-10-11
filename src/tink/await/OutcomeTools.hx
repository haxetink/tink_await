package tink.await;

import haxe.macro.Context;

using tink.CoreApi;

class OutcomeTools {
	
	public static function getOutcome<A, F>(?outcome: tink.core.Outcome<A, F>, ?value: A): Outcome<A, Error> {
		return switch outcome {
			case null: Success(value);
			case Success(v): cast outcome;
			case Failure(e) if(Std.is(e, Error)): cast outcome;
			case Failure(e): Failure(Error.withData('Unexpected error', e));
		}
	}
	
}

/* TODO: see if this could work someway
abstract OutcomeData<T>(T) to T {
	
	public inline function new(data)
		this = data;
		
	@:from static public function fromOutcome<A, F>(outcome: tink.core.Outcome<A, F>)
		return switch outcome {
			case tink.core.Outcome.Success(v): 
				return new OutcomeData(v);
			case tink.core.Outcome.Failure(e):
				throw e;
		}
	
	@:from inline static public function fromAny(any: Dynamic)
		return new OutcomeData(any);
		
}
*/