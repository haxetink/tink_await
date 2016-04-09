package await;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;

enum Block {
	Expr(expr: Expr);
	Handle(expr: Expr);
}

class Node {
	
	var expr: Expr;
	var parent: Node;
	var blocks: Array<Block> = [];
	var async = false;
	
	public function new(expr: Expr, branch = false) {
		this.expr = expr;
		if (!branch)
			parseBlocks(expr, false);
		else
			expr.iter(parseBlocks.bind(_, false));
	}
	
	function root() return parent == null;
	
	/*function processExpr(handle: Expr) {
		var future: Expr = {expr: handle.expr, pos: handle.pos};
		handle.expr = (macro 'transformed').expr;
		switch parent.expr.expr {
			case EBlock(el):
				trace(parent.expr.toString());
			default:
		}
	}*/
	
	function parseBlocks(e: Expr, nested: Bool) {
		switch e.expr {
			case EMeta(m, em) if (m.name == ':await'):
				async = true;
				e.expr = em.expr;
				e.iter(parseBlocks.bind(_, true));
				blocks.push(Block.Handle(e));
			case ETernary(_, _, _)
			| EIf(_, _, _)
			| EFunction(_, _)
			| EFor(_)
			| EWhile(_, _, _)
			| ESwitch(_, _, _):
				blocks.push(Block.Expr(e));
			default:
				e.iter(parseBlocks.bind(_, true));
				if (!nested)
					blocks.push(Block.Expr(e));
		}
	}
	
	public function getExpr(?next: Expr): Expr {
		return transform(blocks, next);
	}
	
	public function getFirstHandle(): Expr {
		for (block in blocks) 
			switch block {
				case Handle(e): return e;
				default:
			}
		return null;
	}
	
	function transform(blocks, ?next: Expr): Expr {
		var list: Array<Expr> = [];
		while (blocks.length > 0) {
			switch blocks.shift() {
				case Block.Expr(e):
					switch e.expr {
						case EBlock(_):
							trace('block: '+e.toString());
							list.push(new Node(e, true).getExpr());
						case EIf(condition, e1, e2):
							trace('if: '+condition.toString());
							var node = new Node(condition);
							var n1 = new Node(e1), n2 = new Node(e2);
							if (node.async) {
								var handle = node.getFirstHandle();
								var branch = macro if ($handle) ${n1.getExpr()} else ${n2.getExpr()};
								list.push(node.getExpr(branch));
							} else
								list.push(macro if ($condition) ${n1.getExpr()} else ${n2.getExpr()});
						default:
							trace('expr: '+e.toString());
							list.push(e);
					}
				case Block.Handle(e):
					if (next == null) next = transform(blocks);
					var future = {expr: e.expr, pos: e.pos};
					e.expr = (macro __v).expr;
					list.push(macro
						$future.handle(function(__v) {
							$next;
						})
					);
					break;
			}
		}
		return switch list.length {
			case 0: null;
			case 1: list[0];
			default: {expr: EBlock(list), pos: list[0].pos};
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
							var node = new Node(f.expr);
							trace(node.getExpr().toString());
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