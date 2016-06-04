package await;

import haxe.macro.Context;

using tink.CoreApi;

class OutcomeTools {
	
	public static function getValue<A, F>(?outcome: tink.core.Outcome<A, F>, ?value: A): A {
		if (outcome == null) return value;
		return outcome.sure();
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