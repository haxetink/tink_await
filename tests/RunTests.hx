package;

import await.Await;
import haxe.Timer;

using buddy.Should;
using tink.CoreApi;

class RunTests extends buddy.SingleSuite implements Await {

	public function new() {
		describe('TestAwait', {
			it('should process @await', function (done) {
				processAwait().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should process an async if', function (done) {
				asyncIf().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should process an async switch', function (done) {
				asyncSwitch().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should return the result of an async expression', function (done) {
				asyncExpressionReturn().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should reach the rest of a method after if and switch statements', function (done) {
				reachNext().handle(function(outcome) {
					outcome.should.equal(Success(4));
					done();
				});
			});
			
			it('should handle a for loop', function (done) {
				testLoop().handle(function(outcome) {
					outcome.should.equal(Success(2));
					done();
				});
			});
			
			it('should handle an async while loop', function (done) {
				testWhileLoop().handle(function(outcome) {
					outcome.should.equal(Success(10));
					done();
				});
			});
			
			it('should transform exceptions', function (done) {
				throwError().handle(function(outcome) {
					outcome.should.equal(Failure('error'));
					done();
				});
			});
			
			it('should pass unexpected exceptions', function (done) {
				unexpectedException().handle(function(outcome) {
					var error = switch outcome {
						case Failure(_): true;
						default: false;
					}
					error.should.be(true);
					done();
				});
			});
			
			it('should pass exceptions', function (done) {
				passError().handle(function(outcome) {
					outcome.should.equal(Failure('error'));
					done();
				});
			});
		});
	}
	
	@async function processAwait() {
		var wait = @await waitForIt();
		return wait;
	}
	
	@async function asyncIf()
		return if (@await waitForIt()) true else false;
	
	@async function asyncSwitch()
		return switch @await waitForIt() {
			case true:
				@await waitForIt();
			default:
				false;
		}
		
	@async function asyncExpressionReturn() {
		var a = {
			var b = @await waitForIt();
			b;
		};
		return a;
	}
		
	@async function reachNext() {
		var outcome = 0;
		if (@await waitForIt()) {
			@await waitForIt();
			outcome++;
		} else {
			outcome--;
		}
		switch @await waitForIt() {
			case true: 
				@await waitForIt();
				outcome++;
				@await waitForIt();
				outcome++;
			default:
		}
		outcome++;
		return outcome;
	}
	
	@async function testLoop() {
		var response = 0;
		for (i in 0 ... 2) {
			if (@await waitForIt())
				response++;
		}
		return response;
	}
	
	@async function testWhileLoop() {
		var i = 0;
		while (true) {
			@await waitForIt();
			if (++i == 10) break;
			continue;
		}
		return i;
	}
	
	@async function throwError()
		throw 'error';
		
	@async function unexpectedException() {
		@await waitForIt();
		#if cpp
		throw 'Segmentation fault on cpp';
		#end
		return untyped {var a = null; a.error;}
	}
		
	@async function passError() {
		@await throwError();
		return true;
	}
	
	function waitForIt() {
		#if (java || js)
		return Future.async(function(cb) {
			Timer.delay(function() {
				cb(true);
			}, 1);
		});
		#else
		return Future.sync(true);
		#end
	}
	
}