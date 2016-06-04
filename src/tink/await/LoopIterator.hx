package tink.await;

@:forward
abstract LoopIterator<T>(Iterator<T>) from Iterator<T> to Iterator<T> {
	
	@:from public static inline function fromIterable<T>(i: Iterable<T>)
		return (i.iterator(): LoopIterator<T>);
	
}