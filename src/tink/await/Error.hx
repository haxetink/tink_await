package tink.await;

import tink.core.Error in TinkError;
import tink.core.Any;

@:forward
abstract Error(TinkError) from TinkError to TinkError {
	
	@:from static public function fromAny(any: Any)
		return Std.is(any, TinkError)
			? (any: Error)
			: (TinkError.withData('Unexpected Error', any): Error);
		
}