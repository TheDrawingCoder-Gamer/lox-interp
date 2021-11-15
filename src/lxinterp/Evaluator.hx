package lxinterp;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import haxe.Exception;
import lxinterp.Expr;
import lxinterp.StdFunction;

using StringTools;

class Evaluator {
	final exprs:Array<Expr>;
	final locals:Map<Expr, Int> = [];
	final globals:Enviroment;
	final fileName:String;

	public final exports:Map<String, Dynamic> = [];
	public final computedImports:Map<String, Evaluator> = [];
	public var enviroment:Enviroment;

	public function new(exprs:Array<Expr>, ?fileName:String) {
		this.exprs = exprs;
		this.fileName = fileName;
		this.globals = new Enviroment();
		this.globals.define("print", StdFunction.loxPrint);
		for (file in FileSystem.readDirectory(Lox.stdpath)) {
			if (file.endsWith(".lx") && file != Path.withoutDirectory(fileName)) {
				this.exprs.unshift(new Expr(EImport("<all>", 'std:' + file), new Position(new Point(0, 0, 0), new Point(0, 0, 0), "<autogenerated import>")));
			}
		}

		this.enviroment = this.globals;
	}

	public function execute():Void {
		executeBlock(exprs, enviroment);
	}

	public function executeBlock(exprs:Array<Expr>, env:Enviroment) {
		var previous = this.enviroment;
		try {
			this.enviroment = env;
			for (expr in exprs) {
				evalExpr(expr, false);
			}
		} catch (e:RuntimeException) {
			Lox.error(e.pos, e.message);
		}
		this.enviroment = previous;
	}

	public function evalExpr(expr:Expr, isInline:Bool = true):Dynamic {
		switch (expr.type) {
			case EImport(id, from):
				if (isInline)
					Lox.error(expr.pos, "Import statement is not allowed in inline expression");
				if (from.startsWith("std:")) {
					from = FileSystem.absolutePath(Lox.stdpath + '/' + from.substring(4));
				} else {
					// Get file's directory and append the "from" field (because it's relative to the file, like javascript )

					from = Path.join([Path.directory(fileName), Path.withoutDirectory(from)]);
					// Then normalize it to remove any ".."
					from = Path.normalize(from);
				}
				// Don't recompute if we've already imported this file
				if (!computedImports.exists(id))
					computedImports.set(id, Lox.run(File.getContent(from), from));
				if (Lox.hadError)
					throw new RuntimeException(expr.pos, "Invalid import");
				var exports = computedImports.get(id).exports;
				for (key => value in exports) {
					if (key != id && id != "<all>")
						continue;
					enviroment.define(key, value);
				}
				return UTNone;
			case EExport(id):
				exports.set(id, evalExpr(new Expr(EIdent(id), expr.pos), true));
				return UTNone;
			case EBool(b):
				return b;
			case ENumber(n):
				return n;
			case EString(s):
				return s;
			case ENil:
				return null;
			// TODO: EThis
			case EIdent(name):
				return lookup(name, expr);
			case EGroup(e):
				return evalExpr(e);
			case EBinop(left, op, right):
				switch (op) {
					case BAdd: return evalExpr(left) + evalExpr(right);
					case BSub: return evalExpr(left) - evalExpr(right);
					case BMul: return evalExpr(left) * evalExpr(right);
					case BDiv: return evalExpr(left) / evalExpr(right);
					case BEqual: return evalExpr(left) == evalExpr(right);
					case BNotEqual: return evalExpr(left) != evalExpr(right);
					case BLess: return evalExpr(left) < evalExpr(right);
					case BGreater: return evalExpr(left) > evalExpr(right);
					case BLessEqual: return evalExpr(left) <= evalExpr(right);
					case BGreaterEqual: return evalExpr(left) >= evalExpr(right);
					case BAnd: return evalExpr(left) && evalExpr(right);
					case BOr: return evalExpr(left) || evalExpr(right);
				}
			case EUnop(op, e):
				switch (op) {
					case UNot: return !evalExpr(e);
					case UNegate: return -evalExpr(e);
				}
			case EField(e, field):
				var obj = evalExpr(e);
				if (!(obj is LoxHasMembers)) {
					throw new RuntimeException(expr.pos, "Can't access field of '" + field + "'");
				}
				return (cast(obj : LoxHasMembers)).get(field);
			case EFieldSet(e, field, value):
				var obj = evalExpr(e);
				if (!(obj is LoxHasMembers)) {
					throw new RuntimeException(expr.pos, "Can't access field of '" + field + "'");
				}
				return (cast(obj : LoxHasMembers)).set(field, evalExpr(value));
			case ECall(e, args):
				var f = evalExpr(e);
				if (!(f is LoxCallable)) {
					throw new RuntimeException(e.pos, "Can't call non-callable object");
				}
				var fun:LoxCallable = cast f;
				if (args.length != fun.arity()) {
					throw new RuntimeException(expr.pos, "Expected " + fun.arity() + " arguments but got " + args.length);
				}

				var goodargs:Array<Dynamic> = args.map(function(e) {
					return evalExpr(e);
				});

				return fun.call(this, goodargs);
			case EAssign(id, e):
				var v = evalExpr(e);

				var depth = locals[expr];
				if (depth != null) {
					enviroment.assignAt(depth, id, v);
				} else
					globals.assign(id, v, expr);
				return v;
			case EArrayDecl(items):
				return items.map(function(e) {
					return evalExpr(e);
				});
			case EObjDecl(fields):
				var obj:Map<String, Dynamic> = new Map<String, Dynamic>();
				for (field in fields) {
					var name = field.name;
					var value = evalExpr(field.value);
					obj.set(name, value);
				}
				return new LoxObject(obj);
			case EIf(econd, ethen, eelse):
				if (evalExpr(econd)) {
					return evalExpr(ethen);
				} else {
					return evalExpr(eelse);
				}
			case EVar(evar):
				var value = evalExpr(evar.value);
				enviroment.define(evar.name, value);
				return value;
			case EArrayAccess(e, index):
				var lhs = evalExpr(e);
				switch (Type.typeof(lhs)) {
					case TClass(Array):
						var arr:Array<Dynamic> = cast lhs;
						var idx = evalExpr(index);
						return arr[idx];
					default:
						throw new RuntimeException(e.pos, "Can't index non-array");
				}
			case EBlock(exprs):
				executeBlock(exprs, new Enviroment(enviroment));
				return UTNone;
			case EWhile(econd, ebody):
				while (evalExpr(econd)) {
					evalExpr(ebody);
				}
				return UTNone;
			case EFun(name, fun):
				var f = new LoxFunction(fun, enviroment);
				// Don't define if inline, because inlining usually means anoyomous functions
				if (!isInline)
					enviroment.define(name, f);
				return f;
			case EReturn(value):
				// Haxe gods smile as I throw whatever I want
				throw new Return(evalExpr(value));
			case EClass(name, fields, superclass):
                if (isInline) {
                    throw new RuntimeException(expr.pos, "Can't define class in inline context");
                }
				enviroment.define(name, null);
				var goodFields:Map<String, ClassField> = [];
				for (field in fields) {
					goodFields.set(field.name, field);
				}
				var souperclass = null;

				if (superclass != null) {
					souperclass = evalExpr(new Expr(EIdent(superclass), expr.pos));
					if (!(souperclass is LoxClass)) {
						throw new RuntimeException(expr.pos, "Can't inherit from non-class");
					}
				}

				var cls = new LoxClass(name, goodFields, this, souperclass, expr.pos);
				enviroment.assign(name, cls);
				return cls;
			// TODO: Super
			case ENone:
				return UTNone;
			default:
				throw new RuntimeException(expr.pos, "Unimplemented.");
		}
	}

	public function resolve(e:Expr, depth:Int) {
		locals.set(e, depth);
	}

	function lookup(name:String, expr:Expr) {
		var depth = locals.get(expr);
		if (depth != null) {
			return enviroment.lookupAt(depth, name, expr);
		} else {
			return enviroment.lookup(name, expr);
		}
	}

	public static function stringify(e:Dynamic):String {
		if (e == null) {
			return "null";
		}
		if (e is String) {
			return e;
		}
		if (e == UTNone) {
			return "None";
		}
		return Std.string(e);
	}
}

class RuntimeException extends haxe.Exception {
	public final pos:Position;

	public function new(pos:Position, message:String) {
		super(message);
		this.pos = pos;
	}
}

class Return {
	public var value:Dynamic;

	public function new(value:Dynamic) {
		this.value = value;
	}
}
