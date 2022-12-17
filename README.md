# tink_await

[![Build Status](https://travis-ci.org/haxetink/tink_await.svg?branch=master)](https://travis-ci.org/haxetink/tink_await)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

Async/await for [tink_core](https://github.com/haxetink/tink_core) futures.

```haxe
@async function getConfig()
  return Json.parse(@await loadFile('config.json'));
```

## Usage

Install with `haxelib install tink_await` and use it in your hxml with `-lib tink_await`. Mark a class or interface as `@await` and all methods with `@async` metadata in your class will be transformed.

Any expression which returns a [`Future`](https://haxetink.github.io/tink_core/#/types/future) can be handled with `@await`. The example above will be transformed to something like this (there's a bit more boilerplate code which I'm omitting here):

```haxe
function getConfig() {
  return Future.async(function(__return) {
    loadFile('config.json').handle(function(tmp) {
      __return(Success(Json.parse(tmp)));
    });
  });
}
```

`@await` can be used anywhere in your code:

```haxe
@async function loadStuff() {
  return switch @await getFile() {
    case 'hello world': @await loadWorld();
    default: @await loadDefault();
  }
}
```

**Transform a function that doesn't return a (async) value**

You can use `@await` on a function to indicate that you want tink_await to transform the function body.

```haxe
@await class Main {
	@await static function main() {
		if(@await foo() == 1) return;
		trace(2);
	}
	
	@async static function foo() return 1;
	
	static function check() {
		$type(main); // Void -> Void
		$type(foo); // Void -> tink.core.Promise<Int>
	}
}
```

In summary, there is a difference for @async and @await when used to annotate a function.

- `@async` expects a return value and the function will be transformed into returning a `Promise<T>`
- `@await` doesn't expect a return value and its return type will be `Void`

**More**

You can also use `@:async`and `@:await`.

To see more examples have a look at [the tests](https://github.com/benmerckx/await/blob/master/tests/RunTests.hx#L96).


## Loops

If an @await is used in a (for or while) loop, the loop will continue after the future is resolved.

```haxe
@async function loop() {
  for (i in 0 ... 10) {
    // will continue after someAsyncCall is done
    @await someAsyncCall();
  }
  return 'done';
}
```


## Working with Promises

An @async function always returns a [`Promise<Data>`](https://haxetink.github.io/tink_core/#/types/promise). Any exception thrown inside the function, be it synchronous or asynchronous, will result in a [`Failure`](https://haxetink.github.io/tink_core/#/types/outcome?id=outcome). Any `Failure` you might receive in an @await call will also result in a `Failure`. A correct return will result in a [`Success`](https://haxetink.github.io/tink_core/#/types/outcome?id=outcome). This makes passing errors much easier. To demonstrate this I use some methods of [`asys`](https://github.com/benmerckx/asys) which have the same classes and methods as the synchronous haxe `sys` module. But instead of a synchronous result, they return a `Future` or a `Promise`.

```haxe
@async function getBuildFile() {
  var path = 'build.hxml';
  if (@await FileSystem.exists(path)) {
    var content = @await File.getContent(path);
    return content;
  } else {
    throw 'File does not exist';
  }
}
```

This would result in the function returning a `Promise<String>`. If you use this test function in another @async function the failure can 'bubble up'. 

```haxe
@async function getBuildLines() {
  var buildFile = @await getBuildFile();
  return buildFile.split('\n');
}
```

The result of the getBuildFile call will automatically be unpacked. Which means if the file exists `buildFile` will hold its contents. If the file did not exist the method will also return a `Failure('File does not exist')`. If you need to catch the failure you can do so with a try/catch:

```haxe
@async function getBuildLines() {
  try {
    var buildFile = @await getBuildFile();
    return buildFile.split('\n');
  } catch (e: Error) {
    return [];
  }
}
```

To recap:
- Any exception results in a `Failure`, which will pass through all methods until caught
- Returns result in a `Success` which is unpacked afterwards if used in @await

You can also @await a `Future` which does not contain an `Outcome`, the result will simply be the value of the `Future`.

Because all @async methods return a `Promise` the usage when calling any of these outside of an @async function will look like this:

```haxe
function() {
  anAsyncMethod().handle(function (outcome) switch outcome {
    case Success(data): trace(data);
    case Failure(error): trace('Something went wrong: '+error);
  });
}
```

## Typing @async functions

An @async function's return type will also be transformed. The following function will result in a return type of `Promise<String>`

```haxe
@async function(): String {
  return @await getBuildFile();
}
```

## JS Promises

When `@await` is used on an expression that is a JS Promise, `tink_await` will extract the `T` from `js.lib.Promise<T>` (if it is a `js.lib.Promise`) and wrap the expression in a check-type statement:
`($expr : tink.core.Promise<T>)`.

This will leverage the magic of `tink_core` to silently convert the JS promise into a tink promise.

```haxe
var secret = @:await new SecretManagerServiceClient({
				credentials: {
					client_email: 'test',
					private_key: 'test'
				}
			}).accessSecretVersion({
				name: 'test'
			});
```
Becomes:
```haxe
var secret = @:await (new SecretManagerServiceClient({
				credentials: {
					client_email: 'test',
					private_key: 'test'
				}
			}) : tink.core.Promise<ts.Tuple3<google_cloud.secret_manager.build.protos.protos.google.cloud.secretmanager.v1.IAccessSecretVersionResponse, Null<google_cloud.secret_manager.build.protos.protos.google.cloud.secretmanager.v1.IAccessSecretVersionRequest>, Null<{}>>>
).accessSecretVersion({
				name: 'test'
			});
```

Try typing that 10 times quickly.


## Flags

- `-D await_catch_none`: Unexpected exceptions are never caught.

## Credits

I used [haxe-continuation](https://github.com/Atry/haxe-continuation) as a guideline for getting this done. It is a solid alternative if you're working with callbacks, such as the nodejs api.
