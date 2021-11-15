package lxinterp;

import lxinterp.LoxInstance.LoxMetaclass;

using Lambda;

class LoxClass implements LoxCallable implements LoxHasMembers {
	public final singleton:LoxMetaclass;
	public final name:String;
	public final superclass:LoxClass;
	public final fields:Map<String, RealClassField> = [];
	public final eval:Evaluator;
	public final pos:Position;

	public function new(name:String, fields:Map<String, ClassField>, eval:Evaluator, superclass:LoxClass, pos:Position) {
		this.name = name;
		this.superclass = superclass;
		this.pos = pos;
		this.eval = eval;
		for (field in fields) {
			switch (field.value) {
				case FVVar(init):
					this.fields.set(field.name, {access: field.access, name: field.name, value: RFVVar(eval.evalExpr(init))});
				case FVFun(fun):
					this.fields.set(field.name, {access: field.access, name: field.name, value: RFVFun(new LoxFunction(fun, eval.enviroment))});
			}
		}
		this.singleton = new LoxMetaclass(this);
	}

	public function toString() {
		return "class " + this.name;
	}

	public function call(eval:Evaluator, args:Array<Dynamic>) {
		var instance = new LoxInstance(this);
		var initializer:RealClassField = this.findField("init");
		if (initializer != null) {
			switch (initializer.value) {
				case RFVFun(fun):
					fun.bind(instance).call(eval, args);
				case RFVVar(init):
					Lox.error(this.pos, "initializer must be a function");
			}
		}
		return instance;
	}

	public function arity() {
		var initializer:RealClassField = this.findField("init");
		if (initializer == null)
			return 0;
		switch (initializer.value) {
			case RFVFun(fun):
				return fun.arity();
			default:
				Lox.error(pos, "initializer must be a function");
				return 0;
		}
	}

	public function findField(name:String) {
		if (this.fields.exists(name)) {
			return this.fields.get(name);
		}
		if (this.superclass != null) {
			var superclassType = this.superclass.findField(name);

			// Don't inherit static properties
			if (superclassType != null && !superclassType.access.contains(AStatic)) {
				return superclassType;
			}
		}
		return null;
	}

	public function get(name:String) {
		return singleton.get(name);
	}

	public function set(name:String, value:Dynamic) {
		singleton.set(name, value);
	}
}
