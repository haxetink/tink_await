package;

import haxe.Timer;

using buddy.Should;
using tink.CoreApi;

@await
@colors
class RunTests extends buddy.SingleSuite {

	public function new() {
		describe('TestAwait', {
			it('should process @async and @await', function (done) {
				processAwait().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should process @:async and @:await', function (done) {
				processColonAwait().handle(function(outcome) {
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
			
			it('should return the result of an async try/catch', function (done) {
				asyncTryCatchReturn().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should return the result in a typed var', function (done) {
				varResult().handle(function(outcome) {
					outcome.should.equal(Success(1));
					done();
				});
			});
			
			it('should return the result of a failed async try/catch', function (done) {
				asyncTryCatchReturnNegative().handle(function(outcome) {
					outcome.should.equal(Success(false));
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
					switch outcome {
						case Success(_): fail('Expected Failure');
						case Failure(e):
							Std.is(e, Error).should.be(true);
							e.data.should.be('error');
					}
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
					switch outcome {
						case Success(_): fail('Expected Failure');
						case Failure(e):
							Std.is(e, Error).should.be(true);
							e.data.should.be('error');
					}
					done();
				});
			});
			
			it('should catch failures and recover', function (done) {
				tryCatch().handle(function(outcome) {
					outcome.should.equal(Success('error'));
					done();
				});
			});
			
			it('should transform the type', function (done) {
				expectString().handle(function(outcome) {
					outcome.should.equal(Success('string'));
					done();
				});
			});
			
			it('should transform functions', function (done) {
				functions().handle(function(outcome) {
					outcome.should.equal(Success(true));
					done();
				});
			});
			
			it('should should not return in an @await field', function (done) {
				awaitField(function(result) {
					result.should.be(true);
					done();
				});
			});
			
			it('should process further async functions in an @await field', function (done) {
				wrapper().handle(function(outcome) {
					outcome.should.equal(Success(123));
					done();
				});
			});
			
			it('should return Promise', function (done) {
				waitForIt().next(function(value) {
					// if `waitForIt()` returns Surprise, `value` will be an Outcome
					value.should.be(true);
					return Noise;
				}).handle(function(outcome) {
					outcome.should.equal(Success(Noise));
					done();
				});
			});
		});
	}
	
	@async function processAwait() {
		var wait = @await waitForIt();
		return wait;
	}
	
	@:async function processColonAwait() {
		var wait = @:await waitForIt();
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
	
	@async function varResult() {
		var a: Int = switch @await waitForIt() {
			case true: 1;
			default: 2;
		}
		return a;
	}
	
	@async function asyncTryCatchReturn()
		return try @await waitForIt() catch (e: Dynamic) false;
	
	@async function asyncTryCatchReturnNegative()
		return try @await passError() catch (e: Dynamic) false;
		
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
	
	@async function tryCatch() {
		var response = 'fail';
		try {
			@await waitForIt();
			@await passError();
		} catch (e: String) {
			response = e;
		}
		return response;
	}
	
	@async function expectString(): String {
		@await waitForIt();
		return 'string';
	}
	
	@async function functions() {
		@async function test()
			return !(@await waitForIt());
		return !(@await test());
	}
	
	@await function awaitField(done) {
		var response = @await waitForIt();
		done(response);
	}
	
	@await function wrapper() {
		@async function local() {
			@await waitForIt();
			return 123;
		}
		return local();
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