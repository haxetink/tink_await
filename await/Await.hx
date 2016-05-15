package await;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.CoreApi;
using tink.MacroApi;

typedef AsyncContext = {
	catcher: Null<String>,
	transformed: Bool
}

class AsyncField {
	
	var expr: Expr;
	var count = 0;
	var triggerName: String;
	var triggerVar: Expr;
	var catches: Array<Expr> = [];
	
	public function new(expr: Expr) {
		this.expr = expr;
		triggerName = tmp();
		triggerVar = (macro $i{triggerName});
	}
		
	function getAwait(e: Expr): Null<Pair<Expr, Expr>>
		switch e.expr {
			case EMeta(m, em) if (m.name == ':await'):
				return new Pair(e, em);
			default:
				var await = null;
				e.iter(function(e) {
					var a = getAwait(e);
					if (a != null) await = a;
				});
				return await;
		}
	
	public function transform(): Expr {
		var list = [], processed = process([expr], {catcher: null, transformed: false});
		
		return macro @:pos(expr.pos) {
			return tink.core.Future.async(function($triggerName)
				$b{catches.concat([processed])}
			);
		};
		
		/*list.push(macro var $triggerName = tink.core.Future.trigger());
		list = list.concat(catches);
		switch processed.expr {
			case EBlock(el): list = list.concat(el);
			default: list.push(processed);
		}
		list.push(macro return $triggerVar.asFuture());*/
		
		
		return list.toBlock(expr.pos);
	}
	
	function tmp(): String return "__t"+(count++);
	
	function copy(e: Expr): Expr
		return {expr: e.expr, pos: e.pos};
		
	function catchCall(catcher: Null<String>): Expr {
		if (catcher == null)
			return macro $triggerVar(tink.core.Outcome.Failure(e));
		return catcher.resolve().call(['e'.resolve()]);
	}
	
	function extract(condition: Expr, expr: Expr): Expr {
		var value = tmp();
		var handle = copy(condition);
		condition.expr = (macro $i{value}).expr;
		return @:pos(condition.pos) macro {
			var $value = $handle;
			$expr;
		};
	}
	
	function context(ctx: AsyncContext) {
		return {catcher: ctx.catcher, transformed: false};
	}
	
	function addContinue(e: Expr) {
		if (e == null) return;
		e.expr = (macro {
			${copy(e)}; __continue();
		}).expr;
	}
	
	function makeContinue(body: Expr, el: Array<Expr>, ctx: AsyncContext) {
		var c = context(ctx);
		var cb = body.func(['__continue'.toArg()], null, null, false).asExpr();
		var next = process(el, c);
		var nextAsCb = next.func([], null, null, false).asExpr();
		return macro ($cb)($nextAsCb);
	}
	
	function process(el: Array<Expr>, ctx: AsyncContext) {
		var output: Array<Expr> = [];
		
		while (el.length > 0) {
			var e = el.shift();
			if (e == null) continue;
			switch e.expr {
				case EBlock(l):
					el = l.concat(el);
				case EIf(condition, e1, e2):
					var await = getAwait(condition);
					if (await != null) {
						el.unshift(extract(condition, e));
						output.push(process(el, ctx));
						break;
					} else {
						var body: Expr = {expr: EIf(condition, process([e1], ctx), e2 == null ? null : process([e2], ctx)), pos: e.pos};
						if (ctx.transformed) {
							// change to yield
							[e1, e2].map(addContinue);
							//ctx.transformed = false;
							output.push(makeContinue(body, el, ctx));
							break;
						} else {
							output.push(body);
						}
					}
				case ESwitch(condition, cl, edef):
					var await = getAwait(condition);
					if (await != null) {
						el.unshift(extract(condition, e));
						output.push(process(el, ctx));
						break;
					} else {
						for (c in cl) {
							c.expr.expr = process([c.expr], ctx).expr;
						}
						if (edef != null) 
							edef = process([edef], ctx);
						if (ctx.transformed) {
							// change to yield
							cl.map(function(c) return c.expr).concat([edef]).map(addContinue);
							//ctx.transformed = false;
							output.push(makeContinue(e, el, ctx));
							break;
						} else {
							output.push(e);
						}
					}
				case EReturn(e1):
					e.expr = (macro $triggerVar(tink.core.Outcome.Success($e1))).expr;
					output.push(macro @:pos(e.pos) {
						${process([e], ctx)}; return;
					});
				case EThrow(e1):
					if (ctx.catcher != null)
						e.expr = ctx.catcher.resolve().call([e1]).expr;
					else
					e.expr = (macro $triggerVar(tink.core.Outcome.Failure($e1))).expr;
					output.push(macro @:pos(e.pos) {
						${process([e], ctx)}; return;
					});
				case ETry(e1, cl):
					var name = tmp();
					for (c in cl)
						c.expr.expr = process([c.expr], {catcher: null, transformed: false}).expr;
					var body = {pos: e.pos, expr: ETry(macro throw e, cl)};
					var catchMethod = body.func(['e'.toArg()], null, null, false);
					catches.push({expr: EFunction(name, catchMethod), pos: e.pos});
					ctx.catcher = name;
					e1.expr = process([e1], ctx).expr;
					output.push(e);
				default:
					var await = getAwait(e);
					if (await != null) {
						var handle = copy(await.b);
						var surprise = tmp(), value = tmp(), success = tmp();
						await.a.expr = (macro cast $i{value}).expr;
						el.unshift(e);
						var body = process(el, ctx);
						body = macro @:pos(e.pos)
							try {
								var $value = await.FutureTools.getValue($i{surprise});
								$body;
							} catch (e: Dynamic) ${catchCall(ctx.catcher)}
						;
						var func = body.func([surprise.toArg()], null, null, false).asExpr();
						ctx.transformed = true;
						output.push(process([macro @:pos(handle.pos) $handle.handle($func)], ctx));
						break;
					}
					output.push(e);
			}
		}
		return switch output.length {
			case 1: output[0];
			default: output.toBlock(); 
		}
	}
	
}


class Await {
	
	public function new() {
		
	}
	
	function processField(field: Field): Field {
		switch field.kind {
			case FieldType.FFun(f):
				if (field.meta != null) {
					for (meta in field.meta) {
						if (meta.name == ':async') {
							var flow = new AsyncField(f.expr);
							var processed = flow.transform();
							#if debug
							//if (field.name == 'connect') {
							Sys.println('==================================');
							Sys.println(field.name);
							Sys.println('==================================');
							Sys.println(processed.toString());
							//}
							#end
							f.expr = processed;
						}
					}
				}
			default:
		}
		return field;
	}
	
	public static function build() {
		var await = new Await();
		return Context.getBuildFields().map(await.processField);
	}
}