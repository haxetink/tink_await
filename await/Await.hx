package await;

import haxe.macro.Context;
import haxe.macro.Expr;
import await.MacroTools.*;

using tink.CoreApi;
using tink.MacroApi;
using Lambda;

typedef AsyncContext = {
	?catcher: String,
	loop: Bool,
	needsResult: Bool
}

class AsyncField {
	
	var expr: Expr;
	
	public function new(expr: Expr)
		this.expr = expr;
	
	public function transform(): Expr
		return macro @:pos(expr.pos)
			return tink.core.Future.async(function(__return) 
				try ${process(expr, {loop: false, needsResult: false}, function(e) return e)}
				catch(e: Dynamic) ${catchCall(null)}
			)
		;
		
	function catchCall(catcher: Null<String>)
		return 
			if (catcher == null) macro __return(tink.core.Outcome.Failure(e))
			else catcher.resolve().call(['e'.resolve()]);
		
	function handler(tmp: String, ctx: AsyncContext, next: Expr -> Expr): Expr {
		var body = unpack(next(macro await.FutureTools.getValue(${tmp.resolve()})));
		body = macro try $body catch(e: Dynamic) ${catchCall(ctx.catcher)};
		return body.func([tmp.toArg()], false).asExpr();
	}
	
	function transformObj<T: {expr: Expr}>(ol: Array<T>, ctx: AsyncContext, final: Array<T> -> Expr): Expr {
		var el = ol.map(function(v) return v.expr);
		return transformList(el, ctx, function(transformedEl: Array<Expr>){
			return final({
				var i = 0;
				ol.map(function(v) {
					var obj = Reflect.copy(v);
					obj.expr = transformedEl[i++];
					return obj;
				});
			});
		});
	}
	
	function transformList(el: Array<Expr>, ctx: AsyncContext, final: Array<Expr> -> Expr): Expr {
		function transformNext(i: Int, transformedEl: Array<Expr>): Expr {
			if (i == el.length)
				return final(transformedEl);
			return process(el[i], ctx, function(transformed: Expr): Expr {
				transformedEl.push(transformed);
				return transformNext(i + 1, transformedEl);
			});
		}
		
		return transformNext(0, []);
	}
		
	function process(e: Expr, ctx: AsyncContext, next: Expr -> Expr): Expr {
		ctx = Reflect.copy(ctx);
		switch e.expr {
			case EBlock (el):
				if (el.length == 0) return emptyExpr();
				function line(i:Int): Expr {
					if (i == el.length - 1)
						return process(el[i], ctx, next);
					
					return process(el[i], ctx, function(transformed: Expr) {
						var response = [transformed];
						response.push(line(i+1));
						return bundle(response);
				  });
				}
				return line(0);
			case EMeta (m, em) if (m.name == ':await'):
				var tmp = tmpVar();
				return process(em, ctx, function(transformed)
					return macro @:pos(em.pos)
						$transformed.handle(${handler(tmp, ctx, next)})
				);
			
			
			
			case EFor (it, expr):
			case EWhile (econd, e1, normalWhile):
			case EBreak:
			case EContinue:
			
			case ETry (e1, catches):
				var wrapper = new AsyncWrapper(ctx, next);
				var wrapperDeclaration = wrapper.declaration();
				var name = tmpVar();
				var transformedCatches = [
					for (c in catches)
						{type: c.type, name: c.name, expr: c.expr == null ? null : process(c.expr, ctx, wrapper.invocation)}
				];
				var body = ETry(macro throw e, transformedCatches).at(e.pos);
				var func = body.func(['e'.toArg()]);
				var declaration = EFunction(name, func).at(e.pos);
				ctx.catcher = name;
				var call = name.resolve().call(['e'.resolve()]);
				//trace(e1.toString());
				var entry = process(e1, ctx, wrapper.invocation);
				entry = macro @:pos(e.pos)
					try $entry catch(e: Dynamic) $call;
				return bundle([wrapperDeclaration, declaration, entry]);
			case EReturn (e1):
				return process(e1, ctx, function(transformed)
					return macro @:pos(e.pos)
						{__return(tink.core.Outcome.Success($transformed)); return;}
				);
			case EThrow (e1):
				if (ctx.catcher != null)
					return process(e1, ctx, function(transformed)
						return macro @:pos(e.pos)
							{${ctx.catcher.resolve()}($transformed); return;}
					);
				return process(e1, ctx, function(transformed)
					return macro @:pos(e.pos)
						{__return(tink.core.Outcome.Failure($transformed)); return;}
				);
			case ETernary (econd, eif, eelse) |
				 EIf (econd, eif, eelse):
				var wrapper = new AsyncWrapper(ctx, next);
				return process(econd, ctx, function(transformed) {
					var declaration = wrapper.declaration();
					var entry = EIf(
						transformed,
						process(eif, ctx, wrapper.invocation),
						eelse == null ? wrapper.invocation(emptyExpr()) : process(eelse, ctx, wrapper.invocation)
					).at(e.pos);
					return bundle([declaration, entry]);
				});
			case ESwitch(e1, cases, edef):
				var wrapper = new AsyncWrapper(ctx, next);
				return process(e1, ctx, function(transformed) {
					var transformedCases = [
						for (c in cases)
							if (c.expr == null) {expr: wrapper.invocation(emptyExpr()), guard: c.guard, values: c.values}
							else {expr: process(c.expr, ctx, wrapper.invocation), guard: c.guard, values: c.values}
					];
					var transformedDefault = switch edef {
						case null: emptyExpr();
						case def if (def.expr == null): wrapper.invocation(emptyExpr());
						default: process(edef, ctx, wrapper.invocation);
					}
					var declaration = wrapper.declaration();
					var entry = ESwitch(transformed, transformedCases, transformedDefault).at(e.pos);
					return bundle([declaration, entry]);
				});
			case EObjectDecl(obj):
				ctx.needsResult = true;
				return transformObj(obj, ctx, function(transformedObjs)
					return next(EObjectDecl(transformedObjs).at(e.pos))
				);
			case EVars(obj):
				return transformObj(obj, ctx, function(transformedObjs)
					return next(EVars(transformedObjs).at(e.pos))
				);
			case EUntyped(e1):
				return process(e1, ctx, function(transformed)
					return next(EUntyped(transformed).at(e.pos))
				);
			case ECast(e1, t):
				ctx.needsResult = true;
				return process(e1, ctx, function(transformed)
					return next(ECast(transformed, t).at(e.pos))
				);
			case EBinop(op, e1, e2):
				ctx.needsResult = true;
				return process(e1, ctx, function(t1)
					return process(e2, ctx, function(t2)
						return next(EBinop(op, t1, t2).at(e.pos))
					)
				);
			case EArray(e1, e2):
				ctx.needsResult = true;
				return process(e1, ctx, function(t1)
					return process(e2, ctx, function(t2)
						return next(EArray(t1, t2).at(e.pos))
					)
				);
			case EUnop(op, postFix, e1):
				ctx.needsResult = true;
				return process(e1, ctx, function(transformed)
					return next(EUnop(op, postFix, transformed).at(e.pos))
				);
			case EField(e1, field):
				ctx.needsResult = true;
				return process(e1, ctx, function(transformed)
					return next(EField(transformed, field).at(e.pos))
				);
			case ECheckType(e1, t):
				ctx.needsResult = true;
				return process(e1, ctx, function(transformed)
					return next(ECheckType(transformed, t).at(e.pos))
				);
			case EArrayDecl(params):
				ctx.needsResult = true;
				return transformList(params, ctx, function(transformedParameters: Array<Expr>)
					return next(EArrayDecl(transformedParameters).at(e.pos))
				);
			case ECall(e1, params):
				ctx.needsResult = true;
				return transformList(params, ctx, function(transformedParameters: Array<Expr>)
					return process(e1, ctx, function(transformed) 
						return next(ECall(transformed, transformedParameters).at(e.pos))
					)
				);
			case ENew(t, params):
				ctx.needsResult = true;
				return transformList(params, ctx, function(transformedParameters: Array<Expr>)
					return next(ENew(t, transformedParameters).at(e.pos))
				);
			default:
		}
		return unpack(next(e));
	}
	
}

class AsyncWrapper {
	
	var ctx: AsyncContext;
	var next: Expr -> Expr;
	var functionName: String;
	var argName: String;
	var empty: Bool = false;
	
	public function new(ctx: AsyncContext, next: Expr -> Expr) {
		this.next = next;
		this.ctx = ctx;
		functionName = tmpVar();
		argName = tmpVar();
	}
	
	public function declaration(): Expr {
		var func;
		if (ctx.needsResult) {
			func = next(argName.resolve()).func([argName.toArg()], false);
		} else {
			var body = next(emptyExpr());
			switch body.expr {
				case EBlock([]): 
					empty = true;
					return emptyExpr();
				default:
			}
			func = body.func(false);
		}
		
		return EFunction(functionName, func).at();
	}
	
	public function invocation(transformed: Expr): Expr {
		if (empty)
			return transformed;
		if (ctx.needsResult)
			return functionName.resolve().call([transformed]);
		return bundle([transformed, functionName.resolve().call()]);
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