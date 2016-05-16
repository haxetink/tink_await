package await;

import haxe.macro.Context;

class FutureTools {
	public static function getValue<A, F>(?outcome: tink.core.Outcome<A, F>, ?value: A): A {
		if (outcome == null) return value;
		return switch outcome {
			case tink.core.Outcome.Success(v): 
				v;
			case tink.core.Outcome.Failure(e):
				throw e;
		}
	}
}