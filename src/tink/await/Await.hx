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
							for (member in c)
								processMember(member);
							return true;
						}
					return false;
				}
				else {
					for (member in c)
						processMember(member);
					return true;
				}
			}
		);
	}
	
	static function processMember(member: Member) {
		var field: Field = member;
		switch member.getFunction() {
			case Success(func):
				if (field.meta != null)
					for (meta in field.meta) {
						if (isAsync(meta.name) || isAwait(meta.name)) {
							var async = new AsyncField(func, isAsync(meta.name));
							var processed = async.transform();
							#if tink_await_debug
							Sys.println('==================================');
							Sys.println(field.name);
							Sys.println('==================================');
							Sys.println(processed.expr.toString());
							#end
							field.kind = FieldType.FFun(processed);
						}
					}
			default:
		}
	}
	
}