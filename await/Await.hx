package await;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.CoreApi;
using tink.MacroApi;

class AsyncField {
	
	var expr: Expr;
	var count = 0;
	
	public function new(expr: Expr) {
		this.expr = expr;
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
		return process([expr]);
	}
	
	function tmp(): String return '__t'+(count++);
	
	function copy(e: Expr): Expr
		return {expr: e.expr, pos: e.pos};
		
	function process(el: Array<Expr>): Expr {
		var output: Array<Expr> = [];
		
		while (el.length > 0) {
			var e = el.shift();
			switch e.expr {
				case EBlock(el):
					output.push(process(el));
				case EIf(condition, e1, e2):
					var await = getAwait(condition);
					if (await != null) {
						var value = tmp();
						output.push(process([
							macro {
								var $value = $condition;
								if ($i{value}) $e1 else $e2;
							}
						]));
					} else {
						output.push(macro if ($condition) ${process([e1])} else ${process([e2])});
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
						]));
					} else {
						for (c in cl) {
							c.expr.expr = process([c.expr]).expr;
						}
						if (edef != null) edef.expr = process([edef]).expr;
						output.push(e);
					}
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
						var handle = {expr: await.b.expr, pos: await.b.pos};
						var value = tmp();
						await.a.expr = (macro $i{value}).expr;
						el.unshift(e);
						var func = process(el).func([value.toArg()], null, null, false).asExpr();
						output.push(process([macro $handle.handle($func)]));
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