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
			
			it('should not cause stack overflow', function (done) {
				// If this compiles, we're good :)
				done();
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
	
	// https://github.com/haxetink/tink_await/issues/11
	@await function issue11() {
		/*var data = {
			b0: @await waitForIt(),
			b1: @await waitForIt(),
			b2: @await waitForIt(),
			b3: @await waitForIt(),
			b4: @await waitForIt(),
			b5: @await waitForIt(),
			b6: @await waitForIt(),
			b7: @await waitForIt(),
			b8: @await waitForIt(),
			b9: @await waitForIt(),

			b10: @await waitForIt(),
			b11: @await waitForIt(),
			b12: @await waitForIt(),
			b13: @await waitForIt(),
			b14: @await waitForIt(),
			b15: @await waitForIt(),
			b16: @await waitForIt(),
			b17: @await waitForIt(),
			b18: @await waitForIt(),
			b19: @await waitForIt(),

			b20: @await waitForIt(),
			b21: @await waitForIt(),
			b22: @await waitForIt(),
			b23: @await waitForIt(),
			b24: @await waitForIt(),
			b25: @await waitForIt(),
			b26: @await waitForIt(),
			b27: @await waitForIt(),
			b28: @await waitForIt(),
			b29: @await waitForIt(),

			b30: @await waitForIt(),
			b31: @await waitForIt(),
			b32: @await waitForIt(),
			b33: @await waitForIt(),
			b34: @await waitForIt(),
			b35: @await waitForIt(),
			b36: @await waitForIt(),
			b37: @await waitForIt(),
			b38: @await waitForIt(),
			b39: @await waitForIt(),

			b40: @await waitForIt(),
			b41: @await waitForIt(),
			b42: @await waitForIt(),
			b43: @await waitForIt(),
			b44: @await waitForIt(),
			b45: @await waitForIt(),
			b46: @await waitForIt(),
			b47: @await waitForIt(),
			b48: @await waitForIt(),
			b49: @await waitForIt(),

			b50: @await waitForIt(),
			b51: @await waitForIt(),
			b52: @await waitForIt(),
			b53: @await waitForIt(),
			b54: @await waitForIt(),
			b55: @await waitForIt(),
			b56: @await waitForIt(),
			b57: @await waitForIt(),
			b58: @await waitForIt(),
			b59: @await waitForIt(),

			b60: @await waitForIt(),
			b61: @await waitForIt(),
			b62: @await waitForIt(),
			b63: @await waitForIt(),
			b64: @await waitForIt(),
			b65: @await waitForIt(),
			b66: @await waitForIt(),
			b67: @await waitForIt(),
			b68: @await waitForIt(),
			b69: @await waitForIt(),

			b70: @await waitForIt(),
			b71: @await waitForIt(),
			b72: @await waitForIt(),
			b73: @await waitForIt(),
			b74: @await waitForIt(),
			b75: @await waitForIt(),
			b76: @await waitForIt(),
			b77: @await waitForIt(),
			b78: @await waitForIt(),
			b79: @await waitForIt(),

			b80: @await waitForIt(),
			b81: @await waitForIt(),
			b82: @await waitForIt(),
			b83: @await waitForIt(),
			b84: @await waitForIt(),
			b85: @await waitForIt(),
			b86: @await waitForIt(),
			b87: @await waitForIt(),
			b88: @await waitForIt(),
			b89: @await waitForIt()
		}*/
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