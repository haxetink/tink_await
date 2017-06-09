package tink.await;

import haxe.macro.Expr;
using tink.CoreApi;
using tink.MacroApi;

class MacroExprTools {
	public static function at(e: Expr, pos: Position) {
		e.pos = pos;
		return e;
	}
}

class MacroTools {
	static var count = 0;
	
	public static function unpack(e: Expr): Expr
		return switch e.expr {
			case EBlock(el):
				switch el.length {
					case 1: unpack(el[0]);
					default: e;
				}
			default: e;
		}
		
	public static function unfold(e: Expr): Array<Expr>
		return switch e.expr {
			case EBlock(el): el;
			default: [e];
		}
		
	public static function bundle(el: Array<Expr>): Expr {
		var response = [];
		for (e in el) 
			response = response.concat(unfold(unpack(e)));
		return switch response.length {
			case 0: throw 'No expression found';
			case 1: response[0];
			default: response.toBlock();
		}
	}
	
	public static function tmpVar()
		return "__t"+(count++);
		
	public static function emptyExpr()
		return [].toBlock();
}