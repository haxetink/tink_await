package tink.await;

#if (haxe_ver >= 4.1)
import Std.isOfType as is;
#else
import Std.is;
#end

using tink.CoreApi;

class OutcomeTools {
	
	public static function getOutcome<A, F>(?outcome: tink.core.Outcome<A, F>, ?value: A): Outcome<A, Error> {
		return switch outcome {
			case null: Success(value);
			case Success(v): cast outcome;
			case Failure(e) if(is(e, Error)): cast outcome;
			case Failure(e): Failure(tink.await.Error.fromAny(e));
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