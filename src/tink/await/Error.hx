package tink.await;

import tink.core.Error in TinkError;
import tink.core.Any;

@:forward
abstract Error(TinkError) from TinkError to TinkError {
	
	@:from static public function fromAny(any: Any)
		return Std.is(any, TinkError)
			? (any: Error)
			: (TinkError.withData(0, 'Unexpected Error', any): Error); // I suppose no one will use zero as error code, right?
	
	public inline static function unwrap(e:Error):Any
		return e.code == 0 ? e.data : e;
}