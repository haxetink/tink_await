package await;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.CoreApi;
using tink.MacroApi;

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
		var list = [], processed = process([expr], null);
		list.push(macro var $triggerName = tink.core.Future.trigger());
		list = list.concat(catches);
		switch processed.expr {
			case EBlock(el): list = list.concat(el);
			default: list.push(processed);
		}
		list.push(macro return $triggerVar);
		return list.toBlock(expr.pos);
	}
	
	function tmp(): String return "$t"+(count++);
	
	function copy(e: Expr): Expr
		return {expr: e.expr, pos: e.pos};
		
	function catchCall(catcher: Null<String>): Expr {
		if (catcher == null)
			return macro $triggerVar.trigger(tink.core.Outcome.Failure(e));
		return catcher.resolve().call(['e'.resolve()]);
	}
		
	function process(el: Array<Expr>, catcher: Null<String>): Expr {
		var output: Array<Expr> = [];
		
		while (el.length > 0) {
			var e = el.shift();
			switch e.expr {
				case EBlock(el):
					output.push(process(el, catcher));
				case EIf(condition, e1, e2):
					var await = getAwait(condition);
					if (await != null) {
						var value = tmp();
						output.push(process([
							macro {
								var $value = $condition;
								if ($i{value}) $e1 else $e2;
							}
						], catcher));
					} else {
						output.push(macro if ($condition) ${process([e1], catcher)} else ${process([e2], catcher)});
					}
				case ESwitch(condition, cl, edef):
					var await = getAwait(condition);
					if (await != null) {
						var value = tmp();
						var handle = copy(condition);
						condition.expr = (macro $i{value}).expr;
						output.push(process([
							macro {
								var $value = $handle;
								$e;
							}
						], catcher));
					} else {
						for (c in cl) {
							c.expr.expr = process([c.expr], catcher).expr;
						}
						if (edef != null) edef.expr = process([edef], catcher).expr;
						output.push(e);
					}
				case EReturn(e1):
					e.expr = (macro $triggerVar.trigger(tink.core.Outcome.Success($e1))).expr;
					output.push(process([e], catcher));
				case EThrow(e1):
					e.expr = (macro $triggerVar.trigger(tink.core.Outcome.Failure($e1))).expr;
					output.push(process([e], catcher));
				case ETry(e1, cl):
					var i = 0, names = [for (c in cl) tmp()];
					for (c in cl) {
						var name = names[i];
						var next = cl.length > i+1 ? names[i+1] : null;
						var catchMethod = process([c.expr], next).func([c.name.toArg()], null, null, false);
						catches.push({expr: EFunction(name, catchMethod), pos: c.expr.pos});
						c.expr.expr = name.resolve().call([c.name.resolve()]).expr;
						i++;
					}
					e1.expr = process([e1], names[0]).expr;
					output.push(e);
				/*case EVars(vars):
					var waits = [];
					for (v in vars) {
						if (hasAwait(v.expr)) {
							waits.push(v);
						}
					}
					if (waits.length > 0) {
						var handles = [], args = [];
						for (wait in waits) {
							handles.push({expr: em.expr, pos: em.pos});
							var value = tmp();
							em.expr = (macro $i{value}).expr;
						}
						em.expr = (macro __v).expr;
						output = [macro $handle.handle(function(__v) $b{output})];
						break;
					} else {
						output.push(e);
					}*/
				default:
					var await = getAwait(e);
					if (await != null) {
						var handle = copy(await.b);
						var surprise = tmp(), value = tmp();
						await.a.expr = (macro $i{value}).expr;
						el.unshift(e);
						var body = process(el, catcher);
						body = macro
							switch $i{surprise} {
								case tink.core.Outcome.Success($i{value}): 
									try $body catch (e: Dynamic) ${catchCall(catcher)};
								case tink.core.Outcome.Failure(e):
									${catchCall(catcher)};
							}
						;
						var func = body.func([surprise.toArg()], null, null, false).asExpr();
						output.push(process([macro $handle.handle($func)], catcher));
						break;
					}
					output.push(e);
			}
		}
		return switch output.length {
			case 1: output[0];
			default: macro $b{output}; 
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
							trace(flow.transform().toString());
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