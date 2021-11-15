package lxinterp;

import lxinterp.Evaluator.Return;
import lxinterp.Enviroment;

class LoxFunction implements LoxCallable {
	final decl:FunDecl;
	final closure:Enviroment;

	public function new(decl:FunDecl, closure:Enviroment) {
		this.decl = decl;
		this.closure = closure;
	}

	public function call(eval:Evaluator, args:Array<Dynamic>):Dynamic {
		var env = new Enviroment(closure);
		for (i in 0...decl.args.length) {
			var arg = decl.args[i];
			env.define(arg, args[i]);
		}
		try {
			switch (decl.body.type) {
				case EBlock(exprs):
					eval.executeBlock(exprs, env);
				default:
					eval.executeBlock([decl.body], env);
			}
		} catch (e:Return) {
			return e.value;
		}

		return UTNone;
	}

	public function arity() {
		return decl.args.length;
	}

	public function bind(instance:LoxInstance) {
		var env = new Enviroment(closure);
		env.define("this", instance);
		return new LoxFunction(decl, env);
	}
}
