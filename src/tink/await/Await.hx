package tink.await;

import haxe.macro.Expr;
import tink.macro.ClassBuilder;
import tink.macro.Member;
import haxe.macro.Type.MetaAccess;

using tink.MacroApi;

class Await {
	
	public static function isAwait(keyword: String)
		return keyword == 'await' || keyword == ':await';
		
	public static function isAsync(keyword: String)
		return keyword == 'async' || keyword == ':async';
	
	public static function use() {
		function appliesTo(m: MetaAccess)
			return m.has('await') || m.has(':await');
		
		SyntaxHub.classLevel.after(
			function (_) return true,
			function (c: ClassBuilder) {
				if (c.target.isInterface && !appliesTo(c.target.meta))
					return false;
				
				if (!appliesTo(c.target.meta)) {
					for (i in c.target.interfaces)
						if (appliesTo(i.t.get().meta)) {
							applyTo(c);
							return true;
						}
					return false;
				}
				else {
					applyTo(c);
					return true;
				}
			}
		);
	}
	
	@:access(tink.macro.Constructor)
	static function applyTo(builder: ClassBuilder) {
		for (member in builder)
			processMember(member);
		if(builder.hasConstructor()) {
			var constructor = builder.getConstructor();
			for (meta in constructor.meta)
				if (isAwait(meta.name))
					constructor.onGenerate(function(func) {
						var processed = transform(func, false);
						func.expr = processed.expr;
					});
				else if (isAsync(meta.name))
					haxe.macro.Context.error('@async not allowed on constructor', constructor.pos);
		}
	}
	
	static function transform(func: Function, async: Bool): Function {
		var async = new AsyncField(func, async);
		var processed = async.transform();
		return processed;
	}
	
	static function processMember(member: Member) {
		var field: Field = member;
		switch member.getFunction() {
			case Success(func):
				if (field.meta != null)
					for (meta in field.meta) {
						if (isAsync(meta.name) || isAwait(meta.name)) {
							field.kind = FieldType.FFun(transform(func, isAsync(meta.name)));
						}
					}
			default:
		}
	}
	
}